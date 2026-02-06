`timescale 1ns / 1ps

module tb_axis_handshake;

    localparam DATA_WIDTH = 32;
    localparam NUM_TRANSACTIONS = 1000;

    // Signals
    logic                   clk;
    logic                   rst_n;
    logic [DATA_WIDTH-1:0]  s_axis_tdata;
    logic                   s_axis_tvalid;
    logic                   s_axis_tready;
    logic [DATA_WIDTH-1:0]  m_axis_tdata;
    logic                   m_axis_tvalid;
    logic                   m_axis_tready;

    // DUT Instantiation
    axis_register #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Queues for Scoreboard
    logic [DATA_WIDTH-1:0] expected_queue[$];
    int error_count = 0;
    int received_count = 0;

    // Monitor Logic (Concurrent)
    always @(posedge clk) begin
        if (rst_n && m_axis_tvalid && m_axis_tready) begin
            if (expected_queue.size() == 0) begin
                $error("Error: Received data but expected queue is empty!");
                error_count++;
            end else begin
                logic [DATA_WIDTH-1:0] expected_val;
                expected_val = expected_queue.pop_front();
                
                if (m_axis_tdata !== expected_val) begin
                    $error("Error: Mismatch! Expected %h, Got %h", expected_val, m_axis_tdata);
                    error_count++;
                end else begin
                    received_count++;
                    if (received_count % 100 == 0) $display("Monitor: Received %0d transactions", received_count);
                end
            end
        end
    end

    // Driver Process
    task drive_inputs();
        int i;
        logic [DATA_WIDTH-1:0] data_to_send;
        
        s_axis_tvalid <= 0;
        s_axis_tdata  <= 0;

        @(posedge rst_n);
        @(posedge clk);

        for (i = 0; i < NUM_TRANSACTIONS; i++) begin
            data_to_send = $random;

            // Randomly toggle valid to simulate bubbles
            while ($urandom_range(0, 3) == 0) begin
                s_axis_tvalid <= 0;
                @(posedge clk);
            end

            // Drive data and push to scoreboard EARLY
            s_axis_tvalid <= 1;
            s_axis_tdata  <= data_to_send;
            expected_queue.push_back(data_to_send);
            
            // Wait until handshake occurs AT the clock edge
            do begin
                @(posedge clk);
            end while (!s_axis_tready);

            s_axis_tvalid <= 0;
        end
        $display("Driver: Finished sending %0d transactions", NUM_TRANSACTIONS);
    endtask

    // Monitor Control Process (Ready Generation with Backpressure)
    task monitor_control();
        m_axis_tready <= 0;
        @(posedge rst_n);

        while (received_count < NUM_TRANSACTIONS) begin
            // 70% chance of being ready, 30% chance of stalling
            m_axis_tready <= ($urandom_range(0, 9) < 7);
            @(posedge clk);
        end
        m_axis_tready <= 0;
    endtask

    // Main Test Block
    initial begin
        $display("Simulation Started...");
        rst_n = 0;
        
        // Use fork so tasks start waiting for rst_n BEFORE it is released
        fork
            begin
                #20;
                rst_n = 1;
                $display("Reset Released...");
            end
            drive_inputs();
            monitor_control();
        join

        #50; // Final stabilization wait
        if (error_count == 0 && received_count == NUM_TRANSACTIONS) begin
            $display("Test Passed: %0d transactions completed successfully.", received_count);
        end else begin
            $display("Test Failed with %0d errors and %0d received.", error_count, received_count);
        end
        
        $finish;
    end

endmodule
