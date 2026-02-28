`timescale 1ns / 1ps

module npu_core (
    input  wire         clk,
    input  wire         rst_n,
    
    // Weights from AXI
    input  wire [7:0]   weight_0,
    input  wire [7:0]   weight_1,
    input  wire [7:0]   weight_2,
    input  wire [7:0]   weight_3,
    input  wire [7:0]   weight_4,
    input  wire [7:0]   weight_5,
    input  wire [7:0]   weight_6,
    input  wire [7:0]   weight_7,
    
    // Input Stream
    input  wire [7:0]   feature_in,
    input  wire         valid_in,
    
    // Output Result
    output wire [31:0]  result_out,
    output wire         result_valid
);

    // Internal wires for daisy chaining
    wire [7:0]  f_link [0:8]; // Feature links (0 to 8)
    wire [31:0] acc_link [0:8]; // Accumulator links
    wire        val_link [0:8]; // Valid shift register to track latency
    
    // Initial accumulation value is 0
    assign acc_link[0] = 32'd0;
    assign f_link[0]   = feature_in;
    
    // Latency matching for valid signal
    // Each PE has 2 pipeline stages (Input Reg -> P Reg)
    // We need to delay the valid signal by 2 * 8 cycles = 16 cycles.
    
    reg [15:0] valid_pipe; // Adjust size as needed
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= '0;
        end else begin
            valid_pipe <= {valid_pipe[14:0], valid_in};
        end
    end
    
    // Sampling early might yield partial results (e.g. 0), triggering false SELL signals.
    assign result_valid = valid_pipe[15];
    
    // PE Instances
    mac_pe pe0 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_0), .feature_in(f_link[0]), .accum_in(acc_link[0]), 
        .valid_in(1'b1), 
        .feature_out(f_link[1]), .accum_out(acc_link[1])
    );
    
    mac_pe pe1 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_1), .feature_in(f_link[1]), .accum_in(acc_link[1]), 
        .valid_in(1'b1),
        .feature_out(f_link[2]), .accum_out(acc_link[2])
    );
    
    mac_pe pe2 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_2), .feature_in(f_link[2]), .accum_in(acc_link[2]), 
        .valid_in(1'b1),
        .feature_out(f_link[3]), .accum_out(acc_link[3])
    );

    mac_pe pe3 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_3), .feature_in(f_link[3]), .accum_in(acc_link[3]), 
        .valid_in(1'b1),
        .feature_out(f_link[4]), .accum_out(acc_link[4])
    );

    mac_pe pe4 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_4), .feature_in(f_link[4]), .accum_in(acc_link[4]), 
        .valid_in(1'b1),
        .feature_out(f_link[5]), .accum_out(acc_link[5])
    );
    
    mac_pe pe5 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_5), .feature_in(f_link[5]), .accum_in(acc_link[5]), 
        .valid_in(1'b1),
        .feature_out(f_link[6]), .accum_out(acc_link[6])
    );
    
    mac_pe pe6 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_6), .feature_in(f_link[6]), .accum_in(acc_link[6]), 
        .valid_in(1'b1),
        .feature_out(f_link[7]), .accum_out(acc_link[7])
    );
    
    mac_pe pe7 (
        .clk(clk), .rst_n(rst_n),
        .weight(weight_7), .feature_in(f_link[7]), .accum_in(acc_link[7]), 
        .valid_in(1'b1),
        .feature_out(f_link[8]), .accum_out(acc_link[8])
    );
    
    assign result_out = acc_link[8];

endmodule
