`timescale 1ns / 1ps

/**
 * Module: mac_pe
 * 
 * Description:
 *  A Systolic Processing Element (PE) implementing a Multiply-Accumulate (MAC) operation.
 *  Uses the Xilinx DSP48E1 primitive directly for maximum performance.
 * 
 *  Operation:
 *      P_out = P_in + (A * B)
 *  
 *  Dataflow: Weight Stationary
 *      - Weight (A port) is expected to be held constant.
 *      - Feature (B port) streams in every cycle.
 * 
 */

module mac_pe (
    input  wire         clk,
    input  wire         rst_n,      // Active low reset
    input  wire  [7:0]  weight,     // INT8 Weight (Static/loaded once) - A
    input  wire  [7:0]  feature_in, // INT8 Feature stream - B
    input  wire  [31:0] accum_in,   // Accumulator Input (from previous PE) - C
    input  wire         valid_in,   // Input valid qualifier
    
    output reg   [7:0]  feature_out,// Passed to next PE (delay match)
    output wire  [31:0] accum_out   // Accumulator output (P)
);

    // -------------------------------------------------------------------------
    // DSP48E1 Wrapper or Inference
    // -------------------------------------------------------------------------
    
    // We will use standard inference for simplicity and portability,
    // assuming the synthesizer maps to DSP48 properly.
    // If strict DSP primitives are needed, we would instantiate DSP48E1 as in project 12,
    // but here we demonstrate the behavioral logic which is often sufficient and cleaner.
    
    // Pipeline registers
    reg signed [26:0] a_reg; // DSP port A is 30 bit (25 on newer) -> 26:0 good
    reg signed [17:0] b_reg; // DSP port B is 18 bit
    reg signed [47:0] c_reg; // DSP port C is 48 bit
    reg signed [47:0] p_reg; // DSP port P is 48 bit

    // Sign extension
    wire signed [26:0] weight_sext = $signed(weight); 
    wire signed [17:0] feature_sext = $signed(feature_in);
    wire signed [47:0] accum_sext = $signed(accum_in);

    // Feature propagation register
    reg [7:0] feature_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            feature_d1  <= 8'd0;
            feature_out <= 8'd0;
        end else if (valid_in) begin
            feature_d1  <= feature_in;
            feature_out <= feature_d1;
        end
    end

    // MAC Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 0;
            b_reg <= 0;
            c_reg <= 0;
            p_reg <= 0;
        end else begin // REMOVED valid_in condition
            // 1. Input pipeline Stage
            a_reg <= weight_sext;
            b_reg <= feature_sext;
            c_reg <= accum_sext;

            // 2. Multiply-Add Stage
            // P = C + (A * B)
            // Note: This uses the values registered in the PREVIOUS cycle (pipeline stage 1)
            p_reg <= c_reg + (a_reg * b_reg);
        end
    end

    assign accum_out = p_reg[31:0]; 

endmodule
