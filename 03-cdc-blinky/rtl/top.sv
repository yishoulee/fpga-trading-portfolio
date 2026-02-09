`timescale 1ns/1ps

module top (
    input  logic       sys_clk,      // 50MHz Input
    input  logic       btn_rst_n,    // Active Low Reset
    output logic [3:0] leds
);

    logic clk_100, clk_33;
    logic mmcm_locked;
    
    // Reset generation
    logic rst_n;
    assign rst_n = btn_rst_n & mmcm_locked;

    logic clkfb;

    // Clock Generation (Using 7-Series MMCM primitive)
    // 50MHz In -> 100MHz (clk_100), 33.33MHz (clk_33)
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(20.0),      // 50MHz * 20 = 1000MHz VCO
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(20.0),        // 50MHz
        .CLKOUT0_DIVIDE_F(10.0),     // 1000 / 10 = 100MHz
        .CLKOUT1_DIVIDE(30),         // 1000 / 30 = 33.333MHz
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.0),
        .STARTUP_WAIT("FALSE")
    ) mmcm_inst (
        .CLKOUT0(clk_100),
        .CLKOUT1(clk_33),
        .CLKFBOUT(clkfb),
        .LOCKED(mmcm_locked),
        .CLKIN1(sys_clk),
        .PWRDWN(1'b0),
        .RST(~btn_rst_n),      // MMCM reset is active high
        .CLKFBIN(clkfb)
    );

    // ----------------------------------------------------
    // Writer (100 MHz Domain)
    // ----------------------------------------------------
    logic [31:0] wr_counter;
    logic        wr_en;
    logic        full;
    
    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            wr_counter <= '0;
            wr_en      <= 1'b0;
        end else begin
            wr_en      <= 1'b1; // Always try to write
            
            if (wr_en && !full) begin
                wr_counter <= wr_counter + 1;
            end
        end
    end

    // ----------------------------------------------------
    // FIFO
    // ----------------------------------------------------
    logic [31:0] rd_data;
    logic        empty;
    logic        rd_en;

    async_fifo #(
        .D_WIDTH(32),
        .A_WIDTH(4)
    ) fifo_inst (
        .w_clk   (clk_100),
        .w_rst_n (rst_n),
        .w_inc   (wr_en),
        .w_data  (wr_counter),
        .w_full  (full),
        
        .r_clk   (clk_33),
        .r_rst_n (rst_n),
        .r_inc   (rd_en),
        .r_data  (rd_data),
        .r_empty (empty)
    );

    // ----------------------------------------------------
    // Reader (33 MHz Domain)
    // ----------------------------------------------------
    always_ff @(posedge clk_33 or negedge rst_n) begin
        if (!rst_n) begin
            rd_en <= 1'b0;
        end else begin
            rd_en <= !empty;
        end
    end
    
    // LEDs display high bits of the data to visualize the counter
    // Invert because LEDs on Alinx AX7015B are active low
    assign leds = ~rd_data[27:24]; 

endmodule
