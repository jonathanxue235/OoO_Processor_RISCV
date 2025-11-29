`timescale 1ns / 1ps

module map_table #(
    parameter AREG_WIDTH = 5,
    parameter PREG_WIDTH = 7
) (
    input logic clk,
    input logic reset,

    // Decode / Rename Interface
    input logic [AREG_WIDTH-1:0] rs1,
    input logic [AREG_WIDTH-1:0] rs2,
    input logic [AREG_WIDTH-1:0] rd,
    input logic reg_write, // Does this instruction write to rd?

    // Allocation (New PREG for rd)
    input logic [PREG_WIDTH-1:0] new_preg,

    // Branch / Recovery Interface
    input logic is_branch_dispatch, // Snapshot state (Checkpoints)
    input logic branch_mispredict,  // Restore state (Recovery)

    // Outputs
    output logic [PREG_WIDTH-1:0] prs1,
    output logic [PREG_WIDTH-1:0] prs2,
    output logic [PREG_WIDTH-1:0] old_p_dest // Needed for ROB to free later
);

    localparam NUM_AREGS = 1 << AREG_WIDTH;

    // The Main Map Table
    logic [PREG_WIDTH-1:0] map_table [0:NUM_AREGS-1];
    
    // The Shadow Map Table (Checkpoint for branch recovery)
    logic [PREG_WIDTH-1:0] map_table_shadow [0:NUM_AREGS-1];

    // Reading logic (Combinational)
    assign prs1 = map_table[rs1];
    assign prs2 = map_table[rs2];
    
    // For the ROB: We need to know what 'rd' used to map to, 
    // so we can free it when this instruction commits.
    assign old_p_dest = map_table[rd];

    // Writing / Recovery Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            // Initialize: r0->p0, r1->p1, ...
            // This assumes initial 1:1 mapping
            for (int i = 0; i < NUM_AREGS; i++) begin
                map_table[i] <= i[PREG_WIDTH-1:0];
                map_table_shadow[i] <= i[PREG_WIDTH-1:0];
            end
        end
        else begin
            if (branch_mispredict) begin
                // RECOVERY: Restore from Shadow
                for (int i = 0; i < NUM_AREGS; i++) begin
                    map_table[i] <= map_table_shadow[i];
                end
            end
            else begin
                // 1. Update Map Table with new allocation
                if (reg_write && rd != 0) begin // x0 always stays 0
                    map_table[rd] <= new_preg;
                end
                
                // 2. Snapshot if this is a branch
                if (is_branch_dispatch) begin
                    // If we are writing and branching in same cycle (rare for simple RISC-V branches, 
                    // but valid for JAL/JALR), we must snapshot the *new* state or *old* state?
                    // Typically snapshot happens *after* the rename of the current instr.
                    
                    // Copy entire table to shadow
                    // Optimization: In hardware this is heavy. 
                    // Better approach is to only snapshot valid bits or use a history buffer.
                    // For this model, we copy the array.
                    for (int i = 0; i < NUM_AREGS; i++) begin
                        if (reg_write && rd == i && rd != 0)
                            map_table_shadow[i] <= new_preg;
                        else
                            map_table_shadow[i] <= map_table[i];
                    end
                end
            end
        end
    end

endmodule