`timescale 1ns / 1ps

module tb_mac_pe;

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;
    logic [7:0] weight;
    logic [7:0] feature_in;
    logic valid_in;
    
    wire [7:0] feature_out;
    wire [31:0] accum_out;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    mac_pe dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .weight     (weight),
        .feature_in (feature_in),
        .valid_in   (valid_in),
        .feature_out(feature_out),
        .accum_out  (accum_out)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #2 clk = ~clk; // 250 MHz = 4ns period, toggle every 2ns
    end

    // -------------------------------------------------------------------------
    // Test Sequencer
    // -------------------------------------------------------------------------
    initial begin
        // Initialize
        rst_n = 0;
        weight = 8'sd5; // Weight = 5
        feature_in = 0;
        valid_in = 0;

        // Apply Reset
        #100; // Wait out the Xilinx GSR pulse
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("Starting Test...");

        // Start Stream
        // Sequence: 1, 2, 3
        // Latency:
        // Cycle 0: In=1. A_Reg captures 5, B_Reg captures 1. 
        // Cycle 1: Mult happens (M_Reg captures 5*1=5).
        // Cycle 2: P_Reg accumulates (P = 0 + 5). Output shows 5.
        // Actually, let's trace carefully.
        // T0: valid=1, feature=1.
        // T1: valid=1, feature=2. Internal: A1/B1 have valid data from T0.
        // T2: valid=1, feature=3. Internal: M has product from T0 data.
        // T3: valid=0.            Internal: P accum from T0 product.
        
        // Drive Inputs
        @(posedge clk);
        valid_in <= 1;
        feature_in <= 8'sd1;
        
        @(posedge clk);
        valid_in <= 1;
        feature_in <= 8'sd2;
        
        @(posedge clk);
        valid_in <= 1;
        feature_in <= 8'sd3;
        feature_in <= 8'sd3;
        
        // FLUSH THE PIPELINE
        // Keep valid_in high, but feed zeros to feature_in
        @(posedge clk);
        feature_in <= 8'sd0; 
        
        // Wait 3 cycles for the final data to propagate to accum_out
        repeat (3) @(posedge clk);
        
        valid_in <= 0;

        // Wait for pipeline to drain visually in the monitor

        // Wait for pipeline to drain
        repeat (10) @(posedge clk);

        // Check results
        // Expected Stream:
        // 1 * 5 = 5
        // 2 * 5 = 10 -> Accum = 5 + 10 = 15
        // 3 * 5 = 15 -> Accum = 15 + 15 = 30
        
        // Note: The accum_out is valid some cycles after valid_in is asserted.
        // We will manually inspect in waveform or add assertions here if we knew exact cycle.
        
        $finish;
    end
    
    // Monitor
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time: %t | Valid: %b | FeatIn: %d | FeatOut: %d | Accum: %d", 
                     $time, valid_in, feature_in, feature_out, accum_out);
        end
    end

endmodule
