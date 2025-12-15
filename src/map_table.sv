`timescale 1ns / 1ps

module map_table #(
    parameter AREG_WIDTH = 5,
    parameter PREG_WIDTH = 7,
    parameter ROB_WIDTH  = 4 // NEW parameter
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
    input logic [ROB_WIDTH-1:0] dispatch_tag, // NEW: Tag for saving snapshot
    
    input logic branch_mispredict,  // Restore state (Recovery)
    input logic [ROB_WIDTH-1:0] recovery_tag, // NEW: Tag for restoring snapshot

    // Outputs
    output logic [PREG_WIDTH-1:0] prs1,
    output logic [PREG_WIDTH-1:0] prs2,
    output logic [PREG_WIDTH-1:0] old_p_dest // Needed for ROB to free later
);
    localparam NUM_AREGS = 1 << AREG_WIDTH;
    localparam NUM_SNAPSHOTS = 1 << ROB_WIDTH;

    // The Main Map Table
    logic [PREG_WIDTH-1:0] map_table [0:NUM_AREGS-1];

    // The Shadow Map Table Array
    logic [PREG_WIDTH-1:0] map_table_snapshots [0:NUM_SNAPSHOTS-1][0:NUM_AREGS-1];

    // Reading logic (Combinational)
    assign prs1 = map_table[rs1];
    assign prs2 = map_table[rs2];
    assign old_p_dest = map_table[rd];

    // Writing / Recovery Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            // Initialize: r0->p0, r1->p1, ...
            for (int i = 0; i < NUM_AREGS; i++) begin
                map_table[i] <= i[PREG_WIDTH-1:0];
            end
        end
        else begin
            if (branch_mispredict) begin
                // RECOVERY: Restore from Shadow at recovery_tag
                for (int i = 0; i < NUM_AREGS; i++) begin
                    map_table[i] <= map_table_snapshots[recovery_tag][i];
                end
            end
            else begin
                // 1. Update Map Table with new allocation
                if (reg_write && rd != 0) begin // x0 always stays 0
                    map_table[rd] <= new_preg;
                end
                
                // 2. Snapshot if this is a branch
                if (is_branch_dispatch) begin
                    // Copy entire table to the snapshot slot for this branch
                    for (int i = 0; i < NUM_AREGS; i++) begin
                        // If we are writing to a register in this same cycle, 
                        // the snapshot must reflect the *new* state (post-rename).
                        if (reg_write && rd == i && rd != 0)
                            map_table_snapshots[dispatch_tag][i] <= new_preg;
                        else
                            map_table_snapshots[dispatch_tag][i] <= map_table[i];
                    end
                end
            end
        end
    end

endmodule