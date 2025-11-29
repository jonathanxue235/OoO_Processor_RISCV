module fetch#(
    parameter type T = logic [31:0]
) (
    input logic     clk,
    input logic     reset,

    input logic     take_branch,
    input T         branch_loc,

    input T         instr_from_cache,
    output T        pc_to_cache,

    output T        instr_to_decode,
    output T        pc_to_decode,

    input logic     ready,
    output logic    valid
);

    // Internal registers
    T pc_reg;               // Program counter register
    T fetched_instr_reg;    // Instruction register (for icache latency)
    T fetched_pc_reg;       // PC register (for icache latency)
    logic valid_reg;        // Valid register

    // Fetch logic
    always_ff @(posedge clk) begin
        if (reset) begin
            // Reset to start address (0x0)
            pc_reg <= 32'h0;
            fetched_instr_reg <= 32'h0;
            fetched_pc_reg <= 32'h0;
            valid_reg <= 1'b0;
        end
        else begin
            // Handle branch redirection
            if (take_branch) begin
                pc_reg <= branch_loc;
                valid_reg <= 1'b0;  // Invalidate current fetch due to branch
            end
            // Normal fetch operation when downstream is ready
            else if (ready || !valid_reg) begin
                // Store fetched instruction and PC from icache (1-cycle latency)
                fetched_instr_reg <= instr_from_cache;
                fetched_pc_reg <= pc_reg;
                valid_reg <= 1'b1;

                // Increment PC by 4 for next instruction (word-aligned)
                pc_reg <= pc_reg + 32'd4;
            end
            // If downstream is not ready, stall (keep PC and valid unchanged)
        end
    end

    // Output assignments
    assign pc_to_cache = pc_reg;              // Send current PC to icache
    assign instr_to_decode = fetched_instr_reg;  // Send fetched instruction to decode
    assign pc_to_decode = fetched_pc_reg;        // Send fetched PC to decode
    assign valid = valid_reg;                    // Valid signal for downstream

endmodule
