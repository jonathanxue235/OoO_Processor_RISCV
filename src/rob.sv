`timescale 1ns / 1ps

module rob #(
    parameter ROB_WIDTH = 4,
    parameter PREG_WIDTH = 7
) (
    input logic clk,
    input logic reset,

    // Allocation
    input logic i_valid,                 // From Dispatch (rob_alloc)
    input logic [ROB_WIDTH-1:0] i_tag,   // Direct from Rename
    input logic [PREG_WIDTH-1:0] i_old_prd, // Direct from Rename
    input logic i_is_branch,             // Direct from Rename (FUtype or Branch flag)
    input logic i_reg_write,             // NEW: From Rename/Dispatch
    input logic [31:0] i_pc,             // Direct from Rename
    
    output logic o_full,

    // Writeback (Placeholder for CDB)
    input logic i_cdb_valid,
    input logic [ROB_WIDTH-1:0] i_cdb_tag,

    // Commit (To Rename/Arch State)
    output logic o_commit_valid,
    output logic [PREG_WIDTH-1:0] o_commit_old_preg,
    output logic [ROB_WIDTH-1:0] o_commit_tag,

    // Recovery
    input logic branch_mispredict,
    input logic [ROB_WIDTH-1:0] mispredict_rob_tag  // Tag of the mispredicting branch
);
    localparam ROB_SIZE = 1 << ROB_WIDTH;

    typedef struct packed {
        logic valid;
        logic busy;
        logic is_branch;
        logic reg_write; // Track if instruction writes to register
        logic [PREG_WIDTH-1:0] old_prd;
        logic [31:0] pc;
    } rob_entry_t;

    rob_entry_t rob_mem [0:ROB_SIZE-1];

    logic [ROB_WIDTH-1:0] head_ptr;
    logic [ROB_WIDTH-1:0] tail_ptr;         // Explicitly track tail
    logic [ROB_WIDTH-1:0] tail_ptr_shadow;  // Shadow tail for recovery
    logic [ROB_WIDTH:0] count;

    assign o_full = (count == ROB_SIZE);
    
    assign o_commit_valid = rob_mem[head_ptr].valid && !rob_mem[head_ptr].busy && (count > 0);
    
    // Mask commit_old_preg: Only valid if the committing instruction actually writes a register
    assign o_commit_old_preg = (rob_mem[head_ptr].reg_write) ? rob_mem[head_ptr].old_prd : '0;
    
    assign o_commit_tag      = head_ptr;

    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr <= 0;
            tail_ptr <= 0;
            tail_ptr_shadow <= 0;
            count <= 0;
            for(int i=0; i<ROB_SIZE; i++) rob_mem[i] <= '0;
        end
        else begin
            if (branch_mispredict) begin
                // Flush all instructions younger than the mispredicting branch
                // Keep the branch and all older instructions intact
                logic [ROB_WIDTH-1:0] new_tail;
                logic [ROB_WIDTH:0] new_count;

                // New tail is one past the mispredicting branch
                new_tail = mispredict_rob_tag + 1;

                // Invalidate all entries between new_tail and current tail
                for(int i=0; i<ROB_SIZE; i++) begin
                    logic [ROB_WIDTH-1:0] idx;
                    idx = i[ROB_WIDTH-1:0];
                    // Check if idx is in range [new_tail, tail_ptr) with wrapping
                    if (new_tail <= tail_ptr) begin
                        // No wrap: invalidate if new_tail <= idx < tail_ptr
                        if (idx >= new_tail && idx < tail_ptr)
                            rob_mem[idx].valid <= 0;
                    end else begin
                        // Wrap: invalidate if idx >= new_tail OR idx < tail_ptr
                        if (idx >= new_tail || idx < tail_ptr)
                            rob_mem[idx].valid <= 0;
                    end
                end

                // Update tail pointer
                tail_ptr <= new_tail;

                // Recalculate count: distance from head to new tail
                if (new_tail >= head_ptr)
                    new_count = new_tail - head_ptr;
                else
                    new_count = ROB_SIZE - head_ptr + new_tail;

                count <= new_count;
            end
            else begin
                // Normal operation
                logic alloc_this_cycle, commit_this_cycle;
                alloc_this_cycle = i_valid && !o_full;
                commit_this_cycle = o_commit_valid;

                // Allocation: advance tail
                if (alloc_this_cycle) begin
                    rob_mem[i_tag].valid <= 1;
                    rob_mem[i_tag].busy  <= 1;
                    rob_mem[i_tag].old_prd <= i_old_prd;
                    rob_mem[i_tag].is_branch <= i_is_branch;
                    rob_mem[i_tag].reg_write <= i_reg_write;
                    rob_mem[i_tag].pc <= i_pc;

                    tail_ptr <= i_tag + 1;

                    // Save shadow tail if this is a branch dispatch
                    if (i_is_branch)
                        tail_ptr_shadow <= i_tag + 1;
                end

                // Writeback: mark as ready
                if (i_cdb_valid) begin
                    rob_mem[i_cdb_tag].busy <= 0;
                end

                // Commit: advance head
                if (commit_this_cycle) begin
                    rob_mem[head_ptr].valid <= 0;
                    head_ptr <= head_ptr + 1;
                end

                // Update count
                if (alloc_this_cycle && !commit_this_cycle)
                    count <= count + 1;
                else if (!alloc_this_cycle && commit_this_cycle)
                    count <= count - 1;
                // else count stays the same
            end
        end
    end
endmodule