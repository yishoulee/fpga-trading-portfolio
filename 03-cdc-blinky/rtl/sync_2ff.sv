`timescale 1ns/1ps

module sync_2ff #(
    parameter WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    logic [WIDTH-1:0] stage1;
    logic [WIDTH-1:0] stage2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= '0;
            stage2 <= '0;
        end else begin
            stage1 <= din;
            stage2 <= stage1;
        end
    end

    assign dout = stage2;

endmodule
