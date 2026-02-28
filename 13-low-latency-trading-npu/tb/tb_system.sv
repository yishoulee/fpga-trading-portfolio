`timescale 1ns / 1ps

module tb_system;

    // -------------------------------------------------------------------------
    // Testbench Signals
    // -------------------------------------------------------------------------
    logic sys_clk;
    logic sys_rst_n;
    
    // Ethernet
    logic [7:0] gmii_rxd;
    logic       gmii_rx_dv;
    logic       gmii_rx_clk;
    
    // AXI
    logic s_axi_aclk;
    logic s_axi_aresetn;
    logic [5:0] s_axi_awaddr;
    logic [2:0] s_axi_awprot;
    logic s_axi_awvalid;
    logic s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic [3:0] s_axi_wstrb;
    logic s_axi_wvalid;
    logic s_axi_wready;
    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;
    
    // LEDs (Active Low)
    logic led_buy;
    logic led_sell;
    logic led_activity;
    logic led_idle;

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk; // 100MHz
    end
    
    initial begin
        gmii_rx_clk = 0;
        forever #4 gmii_rx_clk = ~gmii_rx_clk; // 125MHz (Gigabit)
    end
    
    initial begin
        s_axi_aclk = 0;
        forever #10 s_axi_aclk = ~s_axi_aclk; // 50MHz AXI
    end

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    top #(
        .LED_PULSE_TICKS(100) // Fast 100-cycle pulse for simulation
    ) dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_clk(gmii_rx_clk),
        
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(0),
        .s_axi_arprot(0),
        .s_axi_arvalid(0),
        .s_axi_arready(),
        .s_axi_rdata(),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(1'b0),
        
        // LEDs
        .led_buy(led_buy),
        .led_sell(led_sell),
        .led_activity(led_activity),
        .led_idle(led_idle)
    );

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------
    
    // AXI Write Task
    task axi_write(input [5:0] addr, input [31:0] data);
        begin
            @(posedge s_axi_aclk);
            s_axi_awaddr <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata <= data;
            s_axi_wvalid <= 1;
            s_axi_wstrb <= 4'hF;
            s_axi_bready <= 1;
            
            wait(s_axi_awready && s_axi_wready);
            
            @(posedge s_axi_aclk);
            s_axi_awvalid <= 0;
            s_axi_wvalid <= 0;
            
            wait(s_axi_bvalid);
            @(posedge s_axi_aclk);
            s_axi_bready <= 0;
        end
    endtask

    // Send UDP Packet Task
    task send_udp_packet(input [31:0] symbol, input [31:0] price_val);
        integer i;
        logic [7:0] packet_data [0:63];
        begin
            // Construct dummy packet
            // Preamble 7 bytes + SFD 1 byte
            // Ethernet Header (14 bytes)
            // IP Header (20 bytes)
            // UDP Header (8 bytes)
            // Payload...
            // Our parser looks for Symbol at byte 42-45 (0-indexed in payload or absolute?)
            // `byte_counter` resets on TLAST.
            // In payload mode:
            // 0..41: Irrelevant headers
            // 42..45: Symbol
            // 46..49: Price
            
            // Fill with zeros/dummy
            for(i=0; i<64; i++) packet_data[i] = 8'h00;
            
            // Standard Ethernet offset for UDP payload start is 42
            
            // Set Symbol using input argument
            // symbol[31:24] -> data[42]
            packet_data[42] = symbol[31:24];
            packet_data[43] = symbol[23:16];
            packet_data[44] = symbol[15:8];
            packet_data[45] = symbol[7:0];
            
            // Set Price (46..49)
            packet_data[46] = price_val[31:24];
            packet_data[47] = price_val[23:16];
            packet_data[48] = price_val[15:8];
            packet_data[49] = price_val[7:0];
            
            // Preamble
            @(posedge gmii_rx_clk);
            gmii_rx_dv <= 1;
            gmii_rxd <= 8'h55;
            repeat(7) @(posedge gmii_rx_clk);
            gmii_rxd <= 8'hD5; // SFD
            @(posedge gmii_rx_clk);
            
            // Payload
            for(i=0; i<55; i++) begin
                gmii_rxd <= packet_data[i];
                @(posedge gmii_rx_clk);
            end
            
            // End
            gmii_rx_dv <= 0;
            @(posedge gmii_rx_clk);
             @(posedge gmii_rx_clk); // Inter-packet gap
        end
    endtask

    // Capture triggers
    logic buy_triggered;
    logic sell_triggered;
    
    initial begin
        buy_triggered  = 0;
        sell_triggered = 0;
    end
    
    // Active Low LEDs: Trigger on Negative Edge
    always @(negedge led_buy) begin
        buy_triggered = 1;
        $display("Time %0t: BUY Signal Triggered (LED went Low)", $time);
    end
    
    always @(negedge led_sell) begin
        sell_triggered = 1;
        $display("Time %0t: SELL Signal Triggered (LED went Low)", $time);
    end

    // -------------------------------------------------------------------------
    // Main Stimulus
    // -------------------------------------------------------------------------
    integer pkt_i;

    initial begin

        // Initialize
        sys_rst_n = 0;
        s_axi_aresetn = 0;
        gmii_rx_dv = 0;
        gmii_rxd = 0;
        
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        
        #100;
        sys_rst_n = 1;
        s_axi_aresetn = 1;
        #100;
        
        // 1. Configure Weights via AXI
        $display("Configuring Weights...");
        // Reg0-Reg7: Set all weights to 1 for simplicity
        axi_write(6'h00, 32'd1); // Weight 0
        axi_write(6'h04, 32'd1); // Weight 1
        axi_write(6'h08, 32'd1); // Weight 2
        axi_write(6'h0C, 32'd1); // Weight 3
        axi_write(6'h10, 32'd1); // Weight 4
        axi_write(6'h14, 32'd1); // Weight 5
        axi_write(6'h18, 32'd1); // Weight 6
        axi_write(6'h1C, 32'd1); // Weight 7
        
        // Threshold in Reg8 (Offset 0x20 = 32)
        axi_write(6'h20, 32'd100); // Threshold = 100
        
        #200;
        
        // ---------------------------------------------------------------------
        // Test Case 1: High Price -> SELL Signal
        // ---------------------------------------------------------------------
        // Price = 20. Logic: 8 PEs * 1 Weight * 20 Price = 160.
        // 160 > 100 -> SELL.
        
        buy_triggered = 0;
        sell_triggered = 0;
        
        $display("---------------------------------------------------");
        $display("Test 1: Sending Price 20 (Result 160 > 100) -> Expect SELL");
        // UDP Payload for Price 20 (0x14)
        // Check pack_udp task usage... it looks like it constructs packet properly.
        // wait... send_udp_packet implementation:
        // packet_data[46] is MSB.
        // If we send 32'h00000014, Byte 49 is 0x14.
        // Parser reads 4 bytes.
        // Packet: ... [Symbol] [00] [00] [00] [14] ...
        // Parser reconstructs 0x00000014 = 20. Correct.
        
        // Construct standard UDP frame for "0050" with price 20
        // We write bytes 0 to 63 manually in the task
        // Just call the task.
        
        // Task expects [31:0] symbol, [31:0] price.
        // "0050" = 0x30303530
        send_udp_packet(32'h30303530, 32'd20);
        
        // Wait for NPU latency (16 cycles) + LED latch
        #2000; 
        
        if (sell_triggered && !buy_triggered) 
            $display("SUCCESS: SELL Triggered correctly.");
        else
            $display("FAILURE: Expected SELL. Got Buy=%b Sell=%b", buy_triggered, sell_triggered);
            
        // Reset flags
        buy_triggered = 0;
        sell_triggered = 0;

        // Wait for LEDs to reset (Pulse is fast in sim)
        #1000;
            
        // ---------------------------------------------------------------------
        // Test Case 2: Low Price -> BUY Signal
        // ---------------------------------------------------------------------
        // Price = 10. Logic: 8 PEs * 1 Weight * 10 Price = 80.
        // 80 < 100 -> BUY.
        
        $display("---------------------------------------------------");
        $display("Test 2: Sending Price 10 (Result 80 < 100) -> Expect BUY");
        send_udp_packet(32'h30303530, 32'd10);
        
        #2000;
        
        if (buy_triggered && !sell_triggered) 
            $display("SUCCESS: BUY Triggered correctly.");
        else
            $display("FAILURE: Expected BUY. Got Buy=%b Sell=%b", buy_triggered, sell_triggered);

        $display("---------------------------------------------------");
        $finish;
    end

endmodule
