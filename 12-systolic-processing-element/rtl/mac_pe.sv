`timescale 1ns / 1ps

/**
 * Module: mac_pe
 * 
 * Description:
 *  A Systolic Processing Element (PE) implementing a Multiply-Accumulate (MAC) operation.
 *  Uses the Xilinx DSP48E1 primitive directly for maximum performance (targeted >250MHz).
 * 
 *  Operation:
 *      P = P + (A * B)
 *  
 *  Dataflow: Weight Stationary
 *      - Weight (A port) is expected to be held constant or updated rarely.
 *      - Feature (B port) streams in every cycle.
 *      - Feature is registered and passed to 'feature_out' for the next PE in the systolic array.
 * 
 *  Pipeline:
 *      Latency = 3 or 4 cycles depending on specific internal registers used.
 *      Here we enable AREG/BREG, MREG, and PREG for maximum Fmax.
 * 
 */

module mac_pe (
    input  wire         clk,
    input  wire         rst_n,      // Active low reset
    input  wire  [7:0]  weight,     // INT8 Weight (Static/loaded once)
    input  wire  [7:0]  feature_in, // INT8 Feature stream
    input  wire         valid_in,   // Input valid qualifier (ce)
    
    output reg   [7:0]  feature_out,// Passed to next PE (delay match)
    output wire [31:0]  accum_out   // Accumulator output (truncated to 32 bits)
);

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    
    // DSP48E1 outputs
    wire [47:0] P_out;
    
    // Control signals for DSP48E1
    // OPMODE: Controls the input to the X/Y/Z multiplexers for the ALU.
    // We want P = P + (A*B).
    // ALU = Z + X + Y + Cin
    // To get P + (A*B):
    //      Z MUX = 010 (P)
    //      X MUX = 011 (M = A*B) (Conceptually M is result of multiplier)
    //      Y MUX = 011 (M = A*B)
    // Note on MUX: Multiplier output 'M' is available on both X and Y muxes.
    // Usually for M accumulation:
    //      OPMODE[1:0] (X Mux) = 2'b01 -> M 
    //      OPMODE[3:2] (Y Mux) = 2'b00 -> 0 (We don't need M twice)
    //      OPMODE[6:4] (Z Mux) = 3'b010 -> P 
    //      Wait, let's verify standard MAC mode.
    //      Standard MAC: P = P + M.
    //      OPMODE = 7'b0110101 is common for P = P + M. 
    //      However, let's look at the primitive details. 
    //      X: 00=0, 01=M, 10=P, 11=AB (concatenated)
    //      Y: 00=0, 01=0, 10=M, 11=FFFF
    //      Z: 000=0, 001=PCIN, 010=P, 011=C
    //
    //      We want: P (from Z) + M (from X or Y). 
    //      Setting X=M (01) is fine. Y=0 (00). Z=P (010).
    //      OPMODE = {0, Z(010), Y(00), X(01)} = 0010001 => 7'h11? No.
    //      Bits:
    //      6:4 (Z): 010 (Select P)
    //      3:2 (Y): 00  (Select 0)
    //      1:0 (X): 01  (Select M)
    //      Val = 010_00_01 = 0x21.
    
    // ALUMODE: Controls the ALU function (Add, Sub, etc.)
    // 4'b0000 = Z + X + Y + Cin
    
    wire [6:0] opmode_val;
    wire [3:0] alumode_val;
    
    // Reset handling 
    // DSP48E1 resets are active HIGH (RST...). Our system is rst_n active LOW.
    wire rst_p;
    assign rst_p = ~rst_n;

    // Feature propagation register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            feature_out <= 8'd0;
        end else if (valid_in) begin
            feature_out <= feature_in;
        end
    end

    // -------------------------------------------------------------------------
    // DSP48E1 Instantiation
    // -------------------------------------------------------------------------
    
    // To support accumulation: P = P + (A*B)
    // If valid_in is low, we should probably hold value or stop accumulating?
    // For a simple systolic array, valid_in acts as a clock enable for the computation pipeline.
    
    // Dynamic control of OPMODE?
    // In a systolic array startup, we usually reset the accumulator, then run.
    // If we rely on valid_in solely as CE, internal state freezes when !valid.
    // For a pure "Accumulator" loop, we need to handle the case where we want to RESET the sum
    // vs KEEP accumulating.
    // For this atomic PE exercise, we will assume standard accumulation.
    // Note: If you need to clear the accumulator without resetting the whole chip,
    // you would typically change OPMODE to ignore 'P' (Z-mux = 0) for the first cycle.
    // But for this simplified "Atomic Unit" task, we will just accumulate forever until reset.

    assign opmode_val  = 7'b0100101; // Z=P, Y=0, X=M => P + M
    assign alumode_val = 4'b0000;    // SUM = Z + X + Y + Cin

    DSP48E1 #(
        // Feature Control Attributes:
        .ALUMODEREG(1),          // Pipeline ALUMODE
        .AREG(1),                // Pipeline A input (1 reg)
        .BREG(1),                // Pipeline B input (1 reg)
        .CREG(1),                // Pipeline C input (1 reg)
        .CARRYINREG(0),
        .CARRYINSELREG(0),
        .DREG(0),                // D pre-adder register (not using pre-adder)
        .INMODEREG(0),
        .MREG(1),                // Multiplier register (enable for high speed)
        .OPMODEREG(1),           // Pipeline OPMODE
        .PREG(1),                // Output P register (enable for accumulator)
        .USE_DPORT("FALSE"),
        .USE_MULT("MULTIPLY"),
        .USE_SIMD("ONE48"),
        
        // Pattern Detection Attributes:
        .AUTORESET_PATDET("NO_RESET"),
        .MASK(48'h3ffffffffxxx),
        .PATTERN(48'h000000000000),
        .SEL_MASK("MASK"),
        .SEL_PATTERN("PATTERN"),
        .USE_PATTERN_DETECT("NO_PATDET"),
        
        // Register Control Attributes:
        .ACASCREG(1),
        .ADREG(0),               // Not using pre-adder, only 1 stage for A needed
        .BCASCREG(1)
    )
    DSP48E1_inst (
        // Cascade: 30-bit (unused)
        .ACOUT(),
        .BCOUT(),
        .CARRYCASCOUT(),
        .MULTSIGNOUT(),
        .PCOUT(),
        
        // Control: 4-bit (ALUMODE)
        .ALUMODE(alumode_val),
        .CEALUMODE(valid_in), // Clock Enable for ALU Mode
        
        // Control: 1-bit (Carry In)
        .CARRYIN(1'b0),
        .CARRYINSEL(3'b000),
        
        // Control: 1-bit (Clock Enable)
        // We use valid_in to control the pipeline progression for power/logic correctness
        // When AREG/BREG = 1, the A2/B2 registers are used.
        // Therefore, we must drive CEA2 and CEB2 with the clock enable.
        .CEA1(1'b0),           // A Reg 1 (Unused when AREG=1)
        .CEA2(valid_in),       // A Reg 2 (Active when AREG=1)
        .CEB1(1'b0),           // B Reg 1 (Unused when BREG=1)
        .CEB2(valid_in),       // B Reg 2 (Active when BREG=1)
        
        .CEC(valid_in),         
        .CECARRYIN(1'b0),
        .CED(1'b0),
        .CECTRL(valid_in),     // OPMODE CE
        .CEM(valid_in),        // Multiplier Register CE
        .CEP(valid_in),        // P Output Register CC
        
        // Control: 1-bit (Clock)
        .CLK(clk),
        
        // Control: 1-bit (Inmode)
        .INMODE(5'b00000), // Standard A*B
        .CEINMODE(1'b0),
        
        // Control: 7-bit (Opmode)
        .OPMODE(opmode_val),
        //.OPMODE_CE(valid_in), // Removed redundant/incorrect port. Covered by CECTRL.
        
        // Data: 30-bit (A input) -> Weight
        // Weight is 8-bit. A is 30 bit. Sign extend?
        // A[29:0]. We put weight in A[7:0] and sign extend A[29:8].
        .A({ {22{weight[7]}}, weight }),
        
        // Data: 18-bit (B input) -> Feature
        // Feature is 8-bit. B is 18 bit. Sign extend?
        // B[17:0]. Feature in B[7:0].
        .B({ {10{feature_in[7]}}, feature_in }), 
        
        // Data: 48-bit (C input) - Unused here
        .C(48'd0),
        
        // Data: 25-bit (D input) - Unused
        .D(25'd0),
        
        // Reset: 1-bit (Active High)
        .RSTA(rst_p),
        .RSTALLCARRYIN(rst_p),
        .RSTALUMODE(rst_p),
        .RSTB(rst_p),
        .RSTC(rst_p),
        .RSTCTRL(rst_p),
        .RSTD(rst_p),
        .RSTINMODE(rst_p),
        .RSTM(rst_p),
        .RSTP(rst_p),
        
        // Outputs
        .P(P_out),          // 48-bit result
        .OVERFLOW(),
        .UNDERFLOW(),
        .CARRYOUT(),
        .PATTERNDETECT(),
        .PATTERNBDETECT(),
        
        // Cascade Inputs (connect to 0/z for first PE)
        .ACIN(30'd0),
        .BCIN(18'd0),
        .CARRYCASCIN(1'b0),
        .MULTSIGNIN(1'b0),
        .PCIN(48'd0)
    );
    
    // Assign output
    assign accum_out = P_out[31:0];

endmodule
