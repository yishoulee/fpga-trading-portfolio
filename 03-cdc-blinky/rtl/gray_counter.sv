`timescale 1ns/1ps

module gray_counter #(
    parameter WIDTH = 4
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             inc,
    output logic [WIDTH-1:0] gray_out,
    output logic [WIDTH-1:0] bin_out
);

    logic [WIDTH-1:0] bin_cnt;
    logic [WIDTH-1:0] gray_cnt;

    // Use next state logic to register the gray output immediately
    // effectively pipelining the gray calculation to ensure glitch-free output
    logic [WIDTH-1:0] bin_next;
    logic [WIDTH-1:0] gray_next;

    assign bin_next = inc ? (bin_cnt + 1'b1) : bin_cnt;
    assign gray_next = (bin_next >> 1) ^ bin_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin_cnt  <= '0;
            gray_cnt <= '0;
        end else begin
            bin_cnt  <= bin_next;
            gray_cnt <= gray_next;
        end
    end

    assign bin_out  = bin_cnt;
    assign gray_out = gray_cnt;

endmodule
