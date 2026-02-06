module reset_bridge (
    input  logic clk,
    input  logic arst_n, // Asynchronous reset (active low) from button
    output logic rst_n   // Synchronized reset (active low) to core logic
);
    logic rst_n_meta;

    // Asynchronous Assert, Synchronous De-assert
    // When arst_n is low (active), we immediately reset.
    // When arst_n goes high, we clock in the '1' through two stages.
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            rst_n_meta <= 1'b0;
            rst_n      <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n      <= rst_n_meta;
        end
    end
endmodule
