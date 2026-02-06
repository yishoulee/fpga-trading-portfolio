module counter (
    input  logic        clk,
    input  logic        rst_n,
    output logic [3:0]  leds
);
    logic [31:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            count <= count + 1;
        end
    end

    // Assign upper bits to LEDs for visibility
    // Active Low LEDs (inverted logic)
    assign leds = ~count[26:23];
endmodule
