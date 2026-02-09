`timescale 1ns/1ps

module tb_async_fifo;
    logic w_clk, r_clk;
    logic rst_n;
    
    // Gen clocks
    initial w_clk = 0;
    always #5 w_clk = ~w_clk; // 100 MHz (10ns period)
    
    initial r_clk = 0;
    always #15 r_clk = ~r_clk; // 33.33 MHz approx (30ns period)

    logic [31:0] w_data, r_data;
    logic w_inc, w_full;
    logic r_inc, r_empty;

    async_fifo #(
        .D_WIDTH(32),
        .A_WIDTH(4)
    ) DUT (
        .w_clk(w_clk), .w_rst_n(rst_n), .w_inc(w_inc), .w_data(w_data), .w_full(w_full),
        .r_clk(r_clk), .r_rst_n(rst_n), .r_inc(r_inc), .r_data(r_data), .r_empty(r_empty)
    );

    initial begin
        rst_n = 0;
        w_inc = 0; r_inc = 0; w_data = 0;
        #100;
        rst_n = 1;
        #20;
        
        // Write some data
        $display("Starting Writes at time %0t", $time);
        repeat(20) begin
            @(posedge w_clk);
            if (!w_full) begin
                w_inc = 1;
                w_data = w_data + 1;
            end else w_inc = 0;
        end
        w_inc = 0;
        
        // Read some data
        #100;
        $display("Starting Reads at time %0t", $time);
        repeat(20) begin
            @(posedge r_clk);
            if (!r_empty) begin
                r_inc = 1;
            end else r_inc = 0;
        end
        r_inc = 0;
        
        #500;
        $display("Simulation Passed!");
        $finish;
    end
endmodule
