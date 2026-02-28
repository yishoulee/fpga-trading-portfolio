`timescale 1ns / 1ps

module rgmii_rx (
    input  wire       rst_n,
    
    // RGMII Physical Interface
    input  wire       rgmii_rxc,    // 125 MHz clock from PHY
    input  wire       rgmii_rx_ctl, // Control signal (RX_DV)
    input  wire [3:0] rgmii_rxd,    // 4-bit Data
    
    // GMII Internal Interface
    output wire       gmii_rx_clk,  // Buffered Clock
    output reg        gmii_rx_dv,
    output reg  [7:0] gmii_rxd_out, // 8-bit Data
    output reg        gmii_rx_er
);

    // Buffers and Internal Signals
    wire rx_ctl_r;
    wire rx_ctl_f;
    wire [3:0] rxd_r;
    wire [3:0] rxd_f;
    
    // Global Clock Buffer for the RX Clock
    // -------------------------------------------------------------
    // Add Fixed Delay (IDELAY) to align clock with data window center
    // -------------------------------------------------------------
    wire rgmii_rxc_delayed;
    
    (* IODELAY_GROUP = "rgmii_rx_group" *)
    IDELAYE2 #(
        .CINVCTRL_SEL("FALSE"),
        .DELAY_SRC("IDATAIN"),
        .HIGH_PERFORMANCE_MODE("FALSE"),
        .IDELAY_TYPE("FIXED"),
        .IDELAY_VALUE(28),            // ~1.2ns Delay to center eye (if PHY provides aligned clock)
        .PIPE_SEL("FALSE"),
        .REFCLK_FREQUENCY(200.0),    
        .SIGNAL_PATTERN("CLOCK")
    )
    u_idelay_clk (
        .CNTVALUEOUT(),
        .DATAOUT(rgmii_rxc_delayed),
        .C(1'b0),
        .CE(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'b00000),
        .DATAIN(1'b0),
        .IDATAIN(rgmii_rxc),
        .INC(1'b0),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    BUFG bufg_inst (
        .I(rgmii_rxc_delayed),
        .O(gmii_rx_clk)
    );
    
    // IDDR for Control Signal
    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) iddr_ctl (
        .Q1(rx_ctl_r),
        .Q2(rx_ctl_f),
        .C(gmii_rx_clk), // Use rising edge (IDELAY handles phase shift)
        .CE(1'b1),
        .D(rgmii_rx_ctl),
        .R(1'b0),        // Tie to 0, use sync reset via logic if needed
        .S(1'b0)
    );
    
    // IDDR for Data Signals
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_rxd_iddr
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) iddr_d (
                .Q1(rxd_r[i]),
                .Q2(rxd_f[i]),
                .C(gmii_rx_clk),
                .CE(1'b1),
                .D(rgmii_rxd[i]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

    // RGMII Decoding Logic
    // rx_ctl_r (Rising) = GENERIC_RX_DV
    // rx_ctl_f (Falling) = GENERIC_RX_DV XOR GENERIC_RX_ER
    // Therefore: RX_ER = rx_ctl_r XOR rx_ctl_f
    
    // Data assembly: [7:4] is Falling edge (Q2), [3:0] is Rising edge (Q1).
    
    always_ff @(posedge gmii_rx_clk) begin
        if (!rst_n) begin
            gmii_rx_dv     <= 0;
            gmii_rx_er     <= 0;
            gmii_rxd_out   <= 0;
        end else begin
            gmii_rx_dv     <= rx_ctl_r;
            gmii_rx_er     <= rx_ctl_r ^ rx_ctl_f;
            gmii_rxd_out   <= {rxd_f, rxd_r}; 
        end
    end

endmodule
