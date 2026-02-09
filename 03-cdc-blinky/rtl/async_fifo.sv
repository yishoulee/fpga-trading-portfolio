`timescale 1ns/1ps

module async_fifo #(
    parameter D_WIDTH = 8,
    parameter A_WIDTH = 4
) (
    // Write Domain (Fast)
    input  logic               w_clk,
    input  logic               w_rst_n,
    input  logic               w_inc,
    input  logic [D_WIDTH-1:0] w_data,
    output logic               w_full,

    // Read Domain (Slow)
    input  logic               r_clk,
    input  logic               r_rst_n,
    input  logic               r_inc,
    output logic [D_WIDTH-1:0] r_data,
    output logic               r_empty
);

    // --------------------------------------------------------
    // Signals
    // --------------------------------------------------------
    
    // Pointers
    logic [A_WIDTH:0] w_ptr_gray, w_ptr_bin; // Write pointers (current domain)
    logic [A_WIDTH:0] r_ptr_gray, r_ptr_bin; // Read pointers (current domain)
    
    // Synchronized Pointers
    logic [A_WIDTH:0] wq2_r_ptr_gray; // Write ptr synced to Read domain
    logic [A_WIDTH:0] rq2_w_ptr_gray; // Read ptr synced to Write domain

    // Memory (Dual Port RAM)
    // Depth is 2^A_WIDTH
    localparam DEPTH = 1 << A_WIDTH;
    logic [D_WIDTH-1:0] mem [0:DEPTH-1];

    // --------------------------------------------------------
    // Memory Access
    // --------------------------------------------------------
    
    // Write to memory
    // Note: Use binary address (excluding MSB which is for full/empty wraparound check)
    always_ff @(posedge w_clk) begin
        if (w_inc && !w_full) begin
            mem[w_ptr_bin[A_WIDTH-1:0]] <= w_data;
        end
    end

    // Read from memory
    // In typical async FIFO, we can assign this combinatorially or registered.
    // For simplicity here, combinatorial assignment (block RAMs might need clock)
    // But since this is likely Distributed RAM for small depth, this works.
    assign r_data = mem[r_ptr_bin[A_WIDTH-1:0]];

    // --------------------------------------------------------
    // Pointers
    // --------------------------------------------------------

    // Write Pointer Logic (Gray Code Counter)
    gray_counter #(.WIDTH(A_WIDTH+1)) w_ptr_inst (
        .clk(w_clk),
        .rst_n(w_rst_n),
        .inc(w_inc & !w_full),
        .gray_out(w_ptr_gray),
        .bin_out(w_ptr_bin)
    );

    // Read Pointer Logic (Gray Code Counter)
    gray_counter #(.WIDTH(A_WIDTH+1)) r_ptr_inst (
        .clk(r_clk),
        .rst_n(r_rst_n),
        .inc(r_inc & !r_empty),
        .gray_out(r_ptr_gray),
        .bin_out(r_ptr_bin)
    );

    // --------------------------------------------------------
    // Synchronizers
    // --------------------------------------------------------

    // Sync Read Pointer to Write Domain
    sync_2ff #(.WIDTH(A_WIDTH+1)) sync_r2w (
        .clk(w_clk),
        .rst_n(w_rst_n),
        .din(r_ptr_gray),
        .dout(rq2_w_ptr_gray)
    );

    // Sync Write Pointer to Read Domain
    sync_2ff #(.WIDTH(A_WIDTH+1)) sync_w2r (
        .clk(r_clk),
        .rst_n(r_rst_n),
        .din(w_ptr_gray),
        .dout(wq2_r_ptr_gray)
    );

    // --------------------------------------------------------
    // Full / Empty Generation
    // --------------------------------------------------------

    // Empty Flag (Read Domain)
    // Empty when Gray pointers are identical
    assign r_empty = (r_ptr_gray == wq2_r_ptr_gray);

    // Full Flag (Write Domain)
    // Full when Gray pointers match, except for the top two bits 
    // which follow the pattern for wrap-around.
    // Spec pattern: wr_ptr_gray == {~mask[MSB], ~mask[MSB-1], mask[rest]}
    // Actually standard Cummings is:
    // MSB must be different
    // 2nd MSB must be same (wait, no)
    
    // The spec provided the pattern: 
    // wr_ptr_gray == {~synchronized_rd_ptr_gray[ADDR_WIDTH:ADDR_WIDTH-1], synchronized_rd_ptr_gray[ADDR_WIDTH-2:0]}
    // Wait, the spec says: {~rd[MSB], rd[MSB-1]} -- wait, usually both upper bits are inverted for gray code mirror reflection logic logic.
    // Let's re-read the spec carefully.
    // Spec: `~synchronized_rd_ptr_gray[ADDR_WIDTH:ADDR_WIDTH-1]` which is a 2-bit slice.
    // So both top bits are inverted.
    
    assign w_full = (w_ptr_gray == {~rq2_w_ptr_gray[A_WIDTH:A_WIDTH-1], rq2_w_ptr_gray[A_WIDTH-2:0]});

endmodule
