`timescale 1ns / 1ps

module axi_weight_regs # (
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6 // Expanded to 6 bits to support >32 bytes
) (
    // Global Signals
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,

    // Write Address Channel (AW)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input wire [2 : 0] s_axi_awprot,
    input wire  s_axi_awvalid,
    output wire  s_axi_awready,

    // Write Data Channel (W)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
    input wire  s_axi_wvalid,
    output wire  s_axi_wready,

    // Write Response Channel (B)
    output wire [1 : 0] s_axi_bresp,
    output wire  s_axi_bvalid,
    input wire  s_axi_bready,

    // Read Address Channel (AR)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input wire [2 : 0] s_axi_arprot,
    input wire  s_axi_arvalid,
    output wire  s_axi_arready,

    // Read Data Channel (R)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output wire [1 : 0] s_axi_rresp,
    output wire  s_axi_rvalid,
    input wire  s_axi_rready,

    // Weight Outputs
    output wire [7:0] weight_0,
    output wire [7:0] weight_1,
    output wire [7:0] weight_2,
    output wire [7:0] weight_3,
    output wire [7:0] weight_4,
    output wire [7:0] weight_5,
    output wire [7:0] weight_6,
    output wire [7:0] weight_7,
    
    // Threshold Output
    output wire [31:0] threshold_o
);

    // Register declarations
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg6;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg7;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg8; 

    // AXI4-Lite Internal Signals
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Address decoding
    // ADDR_WIDTH=6 implies [5:0]. 32-bit aligned words -> [5:2] (4 bits)
    wire [3:0] write_addr_index;
    wire [3:0] read_addr_index;

    assign write_addr_index = s_axi_awaddr[5:2];
    assign read_addr_index  = s_axi_araddr[5:2];

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;

    // Weight Assignments
    assign weight_0 = slv_reg0[7:0];
    assign weight_1 = slv_reg1[7:0];
    assign weight_2 = slv_reg2[7:0];
    assign weight_3 = slv_reg3[7:0];
    assign weight_4 = slv_reg4[7:0];
    assign weight_5 = slv_reg5[7:0];
    assign weight_6 = slv_reg6[7:0];
    assign weight_7 = slv_reg7[7:0];
    
    // Threshold Assignment
    assign threshold_o = slv_reg8;
    
    // Write Enable helper
    wire slv_reg_wren;
    assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

    //----------------------------------------------
    // Write State Machine
    //----------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b0;
            slv_reg0 <= 32'd1;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;
            slv_reg4 <= 0;
            slv_reg5 <= 0;
            slv_reg6 <= 0;
            slv_reg7 <= 0;
            slv_reg8 <= 32'd100;
        end else begin
            // Write Address Ready
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
            end else begin
                axi_awready <= 1'b0;
            end

            // Write Data Ready
            if (~axi_wready && s_axi_awvalid && s_axi_wvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end

            // Write Response
            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0;
            end else begin
                if (s_axi_bready && axi_bvalid) begin
                    axi_bvalid <= 1'b0;
                end
            end

            // Write Data to Registers
            if (slv_reg_wren) begin
                case (write_addr_index)
                    4'h0: slv_reg0 <= s_axi_wdata;
                    4'h1: slv_reg1 <= s_axi_wdata;
                    4'h2: slv_reg2 <= s_axi_wdata;
                    4'h3: slv_reg3 <= s_axi_wdata;
                    4'h4: slv_reg4 <= s_axi_wdata;
                    4'h5: slv_reg5 <= s_axi_wdata;
                    4'h6: slv_reg6 <= s_axi_wdata;
                    4'h7: slv_reg7 <= s_axi_wdata;
                    4'h8: slv_reg8 <= s_axi_wdata;
                    default : ; // Keep current values
                endcase
            end
        end
    end

    //----------------------------------------------
    // Read State Machine
    //----------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (s_axi_aresetn == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b0;
        end else begin
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0;
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Read Data Mux
    always @(*) begin
        case (read_addr_index)
            4'h0: axi_rdata = slv_reg0;
            4'h1: axi_rdata = slv_reg1;
            4'h2: axi_rdata = slv_reg2;
            4'h3: axi_rdata = slv_reg3;
            4'h4: axi_rdata = slv_reg4;
            4'h5: axi_rdata = slv_reg5;
            4'h6: axi_rdata = slv_reg6;
            4'h7: axi_rdata = slv_reg7;
            4'h8: axi_rdata = slv_reg8;
            default: axi_rdata = 0;
        endcase
    end

endmodule
