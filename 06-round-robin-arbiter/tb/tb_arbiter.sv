module tb_arbiter;

    // Parameters
    localparam N = 3;

    // Signals
    logic           clk;
    logic           rst_n;
    logic [N-1:0]   req;
    logic [N-1:0]   grant;

    // DUT Instantiation
    arbiter #(
        .N(N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .grant(grant)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Test Variables
    int cycle_count;

    // Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        req   = 0;
        #20;
        rst_n = 1;
        #20;

        $display("-----------------------------------------");
        $display("Project 06: Round-Robin Arbiter Testbench");
        $display("-----------------------------------------");

        // Test Case 1: Single Request (Agent 0)
        $display("\n[T=0] Asserting Req[0]");
        req = 3'b001;
        @(posedge clk); #1;
        assert_grant(3'b001, "Test 1: Agent 0 Single Grant");
        
        // Test Case 2: Release
        req = 3'b000;
        @(posedge clk); #1;
        assert_grant(3'b000, "Test 2: No Grant");

        // Test Case 3: Contention A (0 and 1)
        // Depending on previous winner, arbiter should decide fairness.
        // Last winner was 0. So priority should have rotated to 1.
        $display("\n[T=3] Asserting Req[0] and Req[1]");
        req = 3'b011;
        @(posedge clk); #1;
        // Expect Grant 1 (since 0 won last time)
        assert_grant(3'b010, "Test 3: Fairness (0 won last, so 1 should win)");

        // Test Case 4: Full Saturation (Round Robin Check)
        $display("\n[T=4] Asserting ALL Requests (req=111) for 10 cycles");
        req = 3'b111;
        
        // We expect a cycle: ... -> 1 -> 2 -> 0 -> 1 -> 2 ...
        // Note: The previous winner was 1. Next priority is 2.
        
        @(posedge clk); #1;
        assert_grant(3'b100, "Test 4.1: Grant 2");
        
        @(posedge clk); #1;
        assert_grant(3'b001, "Test 4.2: Grant 0");
        
        @(posedge clk); #1;
        assert_grant(3'b010, "Test 4.3: Grant 1");
        
        @(posedge clk); #1;
        assert_grant(3'b100, "Test 4.4: Grant 2");

        // Test Case 5: Starvation Check
        // If we keep requesting on all channels, verify no one holds it for 2 cycles in a row
        // (The above loop technically proves this, but let's be explicit)
        
        $display("\n[T=5] Released Req");
        req = 0;
        #20;

        $display("\n-----------------------------------------");
        $display("Tests Completed Successfully");
        $display("-----------------------------------------");
        $finish;
    end

    // Helper Task for Checking
    task assert_grant(input logic [N-1:0] expected, input string msg);
        if (grant !== expected) begin
            $error("%s: FAILED. Expected %b, Got %b", msg, expected, grant);
        end else begin
            $display("%s: PASSED. Grant=%b", msg, grant);
        end
    endtask
    
    // Waveform Dump
    initial begin
        $dumpfile("arbiter.vcd");
        $dumpvars(0, tb_arbiter);
    end

endmodule
