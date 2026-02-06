`timescale 1ns / 1ps

module axis_register #(
    parameter DATA_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // Slave Interface (Input)
    input  logic [DATA_WIDTH-1:0]  s_axis_tdata,
    input  logic                   s_axis_tvalid,
    output logic                   s_axis_tready,

    // Master Interface (Output)
    output logic [DATA_WIDTH-1:0]  m_axis_tdata,
    output logic                   m_axis_tvalid,
    input  logic                   m_axis_tready
);

    // This is a "Forward Registered" pipeline stage.
    // It breaks the timing path on the Data and Valid signals.
    // The Ready signal remains combinatorial (pointing backwards).
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= '0;
        end else begin
            // If the downstream is ready to accept data, OR if we are currently holding invalid data (empty),
            // we can accept new data from the inputs.
            if (m_axis_tready || !m_axis_tvalid) begin
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tdata  <= s_axis_tdata;
            end
        end
    end

    // Upstream is ready if:
    // 1. Downstream is ready (we can pass data through immediately in the next cycle), OR
    // 2. We are empty (m_axis_tvalid is low), so we can accept into our register.
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

endmodule
