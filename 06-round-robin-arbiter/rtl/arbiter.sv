module arbiter #(
    parameter N = 3 // Number of Requestors
)(
    input  logic           clk,
    input  logic           rst_n,
    input  logic [N-1:0]   req,   // Request Vector (Bit 0 = Agent 0)
    output logic [N-1:0]   grant  // One-Hot Grant Vector
);

    // Pointer to the current highest priority request
    // This rotates after every grant to ensure fairness
    logic [N-1:0] pointer_reg;
    logic [N-1:0] next_grant;

    // Internal signals for Mask/Pointer Based Arbitration
    // Declared outside always_comb to avoid SystemVerilog block declaration issues in Vivado
    logic [N-1:0] mask;
    logic [N-1:0] req_masked;
    logic [N-1:0] grant_masked;
    logic [N-1:0] grant_raw;

    // Combinational logic to find the winner
    always_comb begin
        // default
        next_grant = '0; 
        
        // Strategy: standard "2 Priority Arbiters" method for Round Robin
        // Arb 1: Masked requests (Req & Mask) where Mask allows bits >= pointer
        // Arb 2: Unmasked requests (Req)
        // If Arb 1 finds a winner, pick it. Else pick Arb 2 winner.
        
        // Create mask: if pointer is at bit k, mask has 1s at k, k+1... N-1
        // Example: ptr=001 -> mask=111. ptr=010 -> mask=110. ptr=100 -> mask=100
        // Formula: mask = ~(pointer_reg - 1) logic is for "thermo code from LSB".
        // We want 1s at MSBs. 
        // mask = ~(pointer_reg - 1) | pointer_reg; // 0010 -> 0001 inv -> 1110 | 0010 -> 1110. Correct.
        mask = ~(pointer_reg - 1'b1) | pointer_reg; // Simplified
        
        req_masked = req & mask;
        
        // Priority Arbitrator 1 (Masked)
        // Simple Fixed Priority (LSB High Priority)
        // Extract the lowest set bit: x & (-x)
        grant_masked = req_masked & (-req_masked);
        
        // Priority Arbitrator 2 (Raw)
        // Simple Fixed Priority (LSB High Priority)
        grant_raw = req & (-req);
        
        // Final Grant Selection
        // If any masked request is active, it takes precedence (because it's higher or equal to pointer)
        if (|req_masked) begin
            next_grant = grant_masked;
        end else begin
            next_grant = grant_raw;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_reg <= 1; // Start with priority at bit 0
            grant <= '0;
        end else begin
            grant <= next_grant;
            
            // Rotate pointer only if a grant occurred.
            // Make the NEW priority the bit to the LEFT of the winner.
            // pointer updates to: {grant[N-2:0], grant[N-1]} (Left Rotate)
            if (|next_grant) begin
                pointer_reg <= {next_grant[N-2:0], next_grant[N-1]};
            end
        end
    end

endmodule
