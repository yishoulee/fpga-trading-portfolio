`timescale 1ns / 1ps

module top_tb;
    logic clk;
    logic btn_rst_n;
    logic [3:0] leds;

    top u_top (
        .clk(clk),
        .btn_rst_n(btn_rst_n),
        .leds(leds)
    );

    // 50 MHz clock -> 20ns period
    always #10 clk = ~clk;

    initial begin
        // Initialize inputs
        clk = 0;
        btn_rst_n = 0; // Assert reset initially
        
        // Dump waves for GTKWave/Vivado
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        
        $display("Starting simulation...");
        $display("Time: %0t | Reset Pin: %b | Internal Reset: %b", $time, btn_rst_n, u_top.u_reset_bridge.rst_n);

        // Hold reset for 100ns
        #100;
        
        $display("Time: %0t | Releasing reset asynchronously (offset from clock edge)...", $time);
        #3; // Wait 3ns to be off-grid from clock (which toggles at 10, 20...)
        btn_rst_n = 1; // Release reset external pin
        
        $display("Time: %0t | Reset Pin: %b | Internal Reset: %b (Should still be LOW due to sync)", $time, btn_rst_n, u_top.u_reset_bridge.rst_n);
        
        if (u_top.u_reset_bridge.rst_n == 0) 
            $display("PASS: Reset Bridge held internal reset low asynchronously.");
        else
            $display("FAIL: Internal reset changed immediately!");

        // Wait for sync (needs 2 clocks: metareg -> rst_n_reg)
        @(posedge clk);
        @(posedge clk);
        #1; // Output delay
        
        $display("Time: %0t | Reset Pin: %b | Internal Reset: %b (Should be HIGH now)", $time, btn_rst_n, u_top.u_reset_bridge.rst_n);

        if (u_top.u_reset_bridge.rst_n == 1) 
            $display("PASS: Internal reset synchronized and released.");
        else 
            $display("FAIL: Internal reset stuck low.");
        
        // Fast-forward
        $display("Fast-forwarding counter to test LED toggle...");
        u_top.u_counter.count = 32'h007FFFF0;

        // Run long enough to see the overflow to bit 23
        #2000; 
        
        $display("Time: %0t | LEDs: %b (Should have changed)", $time, leds);
        $finish;
    end
endmodule
