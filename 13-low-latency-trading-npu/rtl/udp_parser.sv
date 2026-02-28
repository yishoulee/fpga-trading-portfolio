`timescale 1ns / 1ps

module udp_parser (
    input  logic        clk,
    input  logic        rst_n,

    // AXI-Stream Input (From MAC)
    input  logic [7:0]  s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,

    // Configuration
    input  logic [31:0] target_symbol, // e.g., "TSLA" or "0050"

    // Output Interface
    output logic [7:0]  price_out, // Truncated to 8-bit for NPU
    output logic        price_valid
);

    // Byte counter to track position in the packet
    logic [15:0] byte_counter;
    
    // Internal registers for symbol and price accumulation
    logic [31:0] current_symbol;
    logic [31:0] current_price;
    
    // Main processing logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_counter    <= '0;
            current_symbol  <= '0;
            current_price   <= '0;
            price_out       <= '0;
            price_valid     <= 1'b0;
        end else begin
            // Default valid low (pulse for one cycle)
            price_valid <= 1'b0;

            if (s_axis_tvalid) begin
                // Update counter
                if (!s_axis_tlast) begin
                    byte_counter <= byte_counter + 1;
                end else begin
                    byte_counter <= '0;
                end

                // Shift in Symbol (Bytes 42-45) - Standard UDP Payload Start
                if (byte_counter >= 16'd42 && byte_counter <= 16'd45) begin
                    current_symbol <= {current_symbol[23:0], s_axis_tdata};
                end

                // Shift in Price (Bytes 46-49)
                if (byte_counter >= 16'd46 && byte_counter <= 16'd49) begin
                    current_price <= {current_price[23:0], s_axis_tdata};
                end

                // Trigger Logic (At the exact moment the last byte arrives - Byte 49)
                if (byte_counter == 16'd49) begin
                    // Check if the accumulated symbol matches target
                    if (current_symbol == target_symbol) begin
                        price_out   <= {current_price[23:0], s_axis_tdata}; 
                        price_valid <= 1'b1;
                    end
                end
            end else begin
              price_valid <= 1'b0;
            end
            
            // Auto-clear price_out one cycle after valid
            if (price_valid) begin
                price_out <= 8'd0;
            end
        end
    end
endmodule

