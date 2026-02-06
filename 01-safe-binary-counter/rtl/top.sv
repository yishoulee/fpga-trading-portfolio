module top (
    input  logic       clk,
    input  logic       btn_rst_n, // Physical button input
    output logic [3:0] leds
);
    logic sys_rst_n;

    // Instantiate the Safety Logic (Reset Bridge)
    reset_bridge u_reset_bridge (
        .clk(clk),
        .arst_n(btn_rst_n),
        .rst_n(sys_rst_n)
    );

    // Instantiate the Core Logic (Counter)
    counter u_counter (
        .clk(clk),
        .rst_n(sys_rst_n),
        .leds(leds)
    );
endmodule
