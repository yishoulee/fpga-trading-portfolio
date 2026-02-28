`timescale 1ns / 1ps

module mac_rx (
    input  wire       rx_clk,
    input  wire       rst_n,

    // GMII Interface (from PHY)
    input  wire [7:0] gmii_rxd,
    input  wire       gmii_rx_dv,

    // AXI-Stream Interface (to FPGA Logic)
    output reg  [7:0] m_axis_tdata,
    output reg        m_axis_tvalid,
    output reg        m_axis_tlast,
    output reg        m_axis_tuser  // 1 = Error (e.g. premature end)
);
    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PREAMBLE,
        PAYLOAD,
        WAIT_END
    } state_t;

    state_t state;

    // Registered Inputs for stable pipeline and TLAST generation
    logic [7:0] r_rxd;
    logic       r_dv;

    always_ff @(posedge rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            r_rxd           <= 8'h00;
            r_dv            <= 1'b0;
            m_axis_tdata    <= 8'h00;
            m_axis_tvalid   <= 1'b0;
            m_axis_tlast    <= 1'b0;
            m_axis_tuser    <= 1'b0;
        end else begin
            // 1. Input Registration (Pipeline Stage 1)
            r_rxd <= gmii_rxd;
            r_dv  <= gmii_rx_dv;
            
            // Default outputs
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= 1'b0;

            // 2. FSM & Output Logic
            case (state)

                IDLE: begin
                    if (r_dv) begin
                        if (r_rxd == 8'hD5) begin
                            state <= PAYLOAD;
                        end else if (r_rxd == 8'h55) begin
                            state <= PREAMBLE;
                        end
                    end
                end

                PREAMBLE: begin
                    if (!r_dv) begin
                        state <= IDLE;
                    end else if (r_rxd == 8'hD5) begin
                        state <= PAYLOAD;
                    end else if (r_rxd == 8'h55) begin
                        state <= PREAMBLE;
                    end else begin
                        state <= IDLE;
                    end
                end

                PAYLOAD: begin
                    if (r_dv) begin
                        m_axis_tdata  <= r_rxd;
                        m_axis_tvalid <= 1'b1;
                        
                        // Look-ahead for TLAST
                        if (!gmii_rx_dv) begin
                            m_axis_tlast <= 1'b1;
                            state        <= IDLE;
                        end else begin
                            m_axis_tlast <= 1'b0;
                        end
                    end else begin
                        state         <= IDLE;
                        m_axis_tvalid <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
