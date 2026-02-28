`timescale 1ns / 1ps

module top_wrapper (
    input  wire       sys_clk,
    input  wire       sys_rst_n,

    // Ethernet RGMII Interface
    input  wire       eth_rxc,
    input  wire       eth_rx_ctl, // RX_DV
    input  wire [3:0] eth_rxd,
    
    // PHY Reset (Active Low)
    output wire       phy_rst_n,

    // LEDs
    output wire       led_buy,
    output wire       led_sell,
    output wire       led_activity,
    output wire       led_idle
);

    // Keep PHY out of reset
    assign phy_rst_n = 1'b1;

    // --- 1. RGMII to GMII Conversion ---
    wire        gmii_rx_clk;
    wire        gmii_rx_dv;
    wire [7:0]  gmii_rxd;
    wire        gmii_rx_er;

    // IDELAYCTRL Group for RGMII input delay
    // IDELAYCTRL is required when using IDELAYE2
    IDELAYCTRL u_idelayctrl (
        .RDY(),
        .REFCLK(clk_200m), // Need 200MHz ref clock
        .RST(~sys_rst_n)
    );

    rgmii_rx u_rgmii_rx (
        .rst_n(sys_rst_n),
        .rgmii_rxc(eth_rxc),
        .rgmii_rx_ctl(eth_rx_ctl),
        .rgmii_rxd(eth_rxd),
        .gmii_rx_clk(gmii_rx_clk), // 125 MHz
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rxd_out(gmii_rxd),
        .gmii_rx_er(gmii_rx_er)
    );

    // --- 2. Clock Generation ---
    wire clk_200m; // Reference for IDELAY
    wire clk_100m; // AXI Clock (if needed)
    wire clk_50m;  // User clock
    wire locked;

    clk_wiz_0 u_clk_wiz (
        .clk_in1(sys_clk),    // 50 MHz input
        .clk_out1(clk_200m),  // 200 MHz
        .clk_out2(clk_100m),  // 100 MHz
        .clk_out3(clk_50m),   // 50 MHz
        .resetn(sys_rst_n),   // Active Low reset ?? Check IP config
        .locked(locked)
    );

    // --- 3. VIO for AXI Control (Simulating PS) ---
    // Since we don't have a PS instantiation block, we'll use VIO to drive AXI Lite
    // to configure the weights/thresholds.
    
    wire [5:0]  vio_awaddr;
    wire        vio_awvalid;
    wire [31:0] vio_wdata;
    wire [3:0]  vio_wstrb;
    wire        vio_wvalid;
    wire        vio_bready;
    wire [5:0]  vio_araddr;
    wire        vio_arvalid;
    wire        vio_rready;

    // VIO Outputs (to Drive AXI Slave inputs)
    // PROBE_OUT0_WIDTH {6} -> awaddr
    // PROBE_OUT1_WIDTH {1} -> awvalid
    // PROBE_OUT2_WIDTH {32}-> wdata
    // PROBE_OUT3_WIDTH {4} -> wstrb
    // PROBE_OUT4_WIDTH {1} -> wvalid
    // PROBE_OUT5_WIDTH {1} -> bready
    // PROBE_OUT6_WIDTH {6} -> araddr
    // PROBE_OUT7_WIDTH {1} -> arvalid
    // PROBE_OUT8_WIDTH {1} -> rready

    vio_0 u_vio (
        .clk(clk_100m),       // Run VIO on AXI clock
        .probe_out0(vio_awaddr),
        .probe_out1(vio_awvalid),
        .probe_out2(vio_wdata),
        .probe_out3(vio_wstrb),
        .probe_out4(vio_wvalid),
        .probe_out5(vio_bready),
        .probe_out6(vio_araddr),
        .probe_out7(vio_arvalid),
        .probe_out8(vio_rready),
        // Inputs (Monitoring)
        .probe_in0(32'h0),    // unused for now
        .probe_in1(5'h0)      // unused
    );

    // --- 4. Instantiate Top Logic ---
    top u_top (
        .sys_clk(clk_50m),      // Should be system clock
        .sys_rst_n(locked && sys_rst_n), // Reset when PLL locks

        // GMII Interface (from RGMII adapter)
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_clk(gmii_rx_clk), // 125 MHz recovered

        // AXI-Lite Interface (Driven by VIO)
        .s_axi_aclk(clk_100m),
        .s_axi_aresetn(locked && sys_rst_n),
        .s_axi_awaddr(vio_awaddr),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(vio_awvalid),
        .s_axi_awready(),     // Monitored via ILA if needed
        .s_axi_wdata(vio_wdata),
        .s_axi_wstrb(vio_wstrb),
        .s_axi_wvalid(vio_wvalid),
        .s_axi_wready(),
        .s_axi_bresp(),
        .s_axi_bvalid(),
        .s_axi_bready(vio_bready),
        .s_axi_araddr(vio_araddr),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(vio_arvalid),
        .s_axi_arready(),
        .s_axi_rdata(),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(vio_rready),

        // LEDs
        .led_buy(led_buy),
        .led_sell(led_sell),
        .led_activity(led_activity),
        .led_idle(led_idle)
    );

endmodule
