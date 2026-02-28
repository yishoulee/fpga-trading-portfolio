`timescale 1ns / 1ps

module top #(
    parameter int LED_PULSE_TICKS = 125_000_000 // 1 sec at 125MHz
)(
    input  wire         sys_clk,
    input  wire         sys_rst_n,

    // Ethernet GMII
    input  wire [7:0]   gmii_rxd,
    input  wire         gmii_rx_dv,
    input  wire         gmii_rx_clk,
    
    // AXI-Lite Interface
    input  wire         s_axi_aclk,
    input  wire         s_axi_aresetn,
    input  wire [5:0]   s_axi_awaddr,
    input  wire [2:0]   s_axi_awprot,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [5:0]   s_axi_araddr,
    input  wire [2:0]   s_axi_arprot,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,
    
    // LEDs (Active Low)
    output reg          led_buy,
    output reg          led_sell,
    output reg          led_activity,
    output reg          led_idle
);

    // --- Wire Declarations ---
    wire [7:0]  weight_0, weight_1, weight_2, weight_3;
    wire [7:0]  weight_4, weight_5, weight_6, weight_7;
    wire [31:0] threshold;
    
    wire [7:0]  axis_tdata;
    wire        axis_tvalid, axis_tlast, axis_tuser;
    
    wire [7:0]  parsed_price;
    wire        parsed_valid;
    
    wire [31:0] npu_result;
    wire        npu_valid;

    // --- Instantiations ---
    axi_weight_regs u_axi_regs (
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .weight_0(weight_0), .weight_1(weight_1), .weight_2(weight_2), .weight_3(weight_3),
        .weight_4(weight_4), .weight_5(weight_5), .weight_6(weight_6), .weight_7(weight_7),
        .threshold_o(threshold)
    );

    mac_rx u_mac_rx (
        .rx_clk(gmii_rx_clk), .rst_n(sys_rst_n),
        .gmii_rxd(gmii_rxd), .gmii_rx_dv(gmii_rx_dv),
        .m_axis_tdata(axis_tdata), .m_axis_tvalid(axis_tvalid),
        .m_axis_tlast(axis_tlast), .m_axis_tuser(axis_tuser)
    );

    udp_parser u_parser (
        .clk(gmii_rx_clk), .rst_n(sys_rst_n),
        .s_axis_tdata(axis_tdata), .s_axis_tvalid(axis_tvalid), .s_axis_tlast(axis_tlast),
        .target_symbol(32'h30303530), // "0050"
        .price_out(parsed_price), .price_valid(parsed_valid)
    );

    npu_core u_npu (
        .clk(gmii_rx_clk), .rst_n(sys_rst_n),
        .weight_0(weight_0), .weight_1(weight_1), .weight_2(weight_2), .weight_3(weight_3),
        .weight_4(weight_4), .weight_5(weight_5), .weight_6(weight_6), .weight_7(weight_7),
        .feature_in(parsed_price), .valid_in(parsed_valid),
        .result_out(npu_result), .result_valid(npu_valid)
    );

    // --- LED Logic ---
    reg [27:0] cnt_buy, cnt_sell, cnt_act, cnt_idle;
    
    always_ff @(posedge gmii_rx_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt_buy <= '0; cnt_sell <= '0; cnt_act <= '0; cnt_idle <= '0;
            led_buy <= 1'b1; led_sell <= 1'b1; led_activity <= 1'b1; led_idle <= 1'b1;
        end else begin
            // Heartbeat
            cnt_idle <= (cnt_idle >= LED_PULSE_TICKS) ? 0 : cnt_idle + 1;
            led_idle <= (cnt_idle < (LED_PULSE_TICKS/2)) ? 1'b0 : 1'b1;

            // BUY Logic
            if (npu_valid && ($signed(npu_result) < $signed(threshold))) begin
                cnt_buy <= LED_PULSE_TICKS;
            end else if (cnt_buy > 0) cnt_buy <= cnt_buy - 1;
            led_buy <= (cnt_buy > 0) ? 1'b0 : 1'b1;

            // SELL Logic
            if (npu_valid && ($signed(npu_result) > $signed(threshold))) begin
                cnt_sell <= LED_PULSE_TICKS;
            end else if (cnt_sell > 0) cnt_sell <= cnt_sell - 1;
            led_sell <= (cnt_sell > 0) ? 1'b0 : 1'b1;

            // Activity Logic
            if (npu_valid) cnt_act <= LED_PULSE_TICKS / 4;
            else if (cnt_act > 0) cnt_act <= cnt_act - 1;
            led_activity <= (cnt_act > 0) ? 1'b0 : 1'b1;
        end
    end
endmodule