`timescale 1ns / 1ps

module top (
    input wire sys_clk // 50 MHz Board Clock
);

    // -------------------------------------------------------------------------
    // Clock Generation (50 MHz -> 250 MHz)
    // -------------------------------------------------------------------------
    wire clk_250m;
    wire internal_pll_locked;
    
    clk_wiz_0 u_pll (
        .clk_out1(clk_250m),
        .locked(internal_pll_locked),
        .clk_in1(sys_clk)
    );

    // -------------------------------------------------------------------------
    // VIO Signal Instantiation
    // -------------------------------------------------------------------------
    // Probe OUT
    wire        vio_rst_n;      // Software Reset
    wire [7:0]  vio_weight;     // Weight Input
    wire [7:0]  vio_feature;    // Feature Input
    wire        vio_valid;      // Valid Input
    
    // Probe IN
    wire [31:0] pe_accum_out;   // Accumulator Output

    vio_0 u_vio (
        .clk(clk_250m),
        .probe_out0(vio_rst_n),
        .probe_out1(vio_weight),
        .probe_out2(vio_feature),
        .probe_out3(vio_valid),
        .probe_in0(pe_accum_out)
    );

    // -------------------------------------------------------------------------
    // DUT: Systolic Processing Elemet
    // -------------------------------------------------------------------------
    // Reset Logic: Combine PLL lock with VIO reset
    wire sys_rst_n;
    assign sys_rst_n = vio_rst_n & internal_pll_locked;

    // Feature Input Register (to improve timing from VIO which is slow)
    // VIO outputs are considered asynchronous or multi-cycle paths usually, but good practice to register.
    reg [7:0] weight_reg;
    reg [7:0] feature_reg;
    reg       valid_reg;
    
    always_ff @(posedge clk_250m) begin
        weight_reg  <= vio_weight;
        feature_reg <= vio_feature;
        valid_reg   <= vio_valid;
    end

    mac_pe u_pe (
        .clk        (clk_250m),
        .rst_n      (sys_rst_n),
        .weight     (weight_reg),
        .feature_in (feature_reg),
        .valid_in   (valid_reg),
        .feature_out(),           // Unused in single PE test
        .accum_out  (pe_accum_out)
    );

endmodule
