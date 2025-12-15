`timescale 1ns / 1ps

module rob #(
    parameter ROB_WIDTH = 4,
    parameter PREG_WIDTH = 7
) (
    input logic clk,
    input logic reset,

    // Allocation
    input logic i_valid,
    input logic [ROB_WIDTH-1:0] i_tag,
    input logic [PREG_WIDTH-1:0] i_old_prd,
    input logic i_is_branch,
    input logic i_reg_write,
    input logic [31:0] i_pc,
    output logic o_full,

    // Writeback (CDB)
    input logic i_cdb_valid,
    input logic [ROB_WIDTH-1:0] i_cdb_tag,
    // NEW: Branch Info from BU/CDB
    input logic i_cdb_taken,
    input logic [31:0] i_cdb_target,

    // Commit
    output logic o_commit_valid,
    output logic [PREG_WIDTH-1:0] o_commit_old_preg,
    output logic [ROB_WIDTH-1:0] o_commit_tag,
    
    // NEW: Branch Update Info
    output logic o_commit_is_branch,
    output logic o_commit_taken,
    output logic [31:0] o_commit_target,
    output logic [31:0] o_commit_pc,

    // Recovery
    input logic branch_mispredict,
    input logic [ROB_WIDTH-1:0] mispredict_rob_tag
);
    localparam ROB_SIZE = 1 << ROB_WIDTH;

    typedef struct packed {
        logic valid;
        logic busy;
        logic is_branch;
        logic reg_write;
        logic [PREG_WIDTH-1:0] old_prd;
        logic [31:0] pc;
        // NEW: Store Branch Outcome
        logic taken;
        logic [31:0] target;
    } rob_entry_t;

    rob_entry_t rob_mem [0:ROB_SIZE-1];

    logic [ROB_WIDTH-1:0] head_ptr;
    logic [ROB_WIDTH-1:0] tail_ptr;
    logic [ROB_WIDTH-1:0] tail_ptr_shadow;
    logic [ROB_WIDTH:0] count;

    assign o_full = (count == ROB_SIZE);
    
    // Commit Outputs
    assign o_commit_valid = rob_mem[head_ptr].valid && !rob_mem[head_ptr].busy && (count > 0);
    assign o_commit_old_preg = (rob_mem[head_ptr].reg_write) ? rob_mem[head_ptr].old_prd : '0;
    assign o_commit_tag = head_ptr;
    
    // Update Outputs
    assign o_commit_is_branch = rob_mem[head_ptr].is_branch;
    assign o_commit_taken = rob_mem[head_ptr].taken;
    assign o_commit_target = rob_mem[head_ptr].target;
    assign o_commit_pc = rob_mem[head_ptr].pc;

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
                logic [ROB_WIDTH-1:0] new_tail;
                logic [ROB_WIDTH:0] new_count;
                logic [ROB_WIDTH-1:0] next_head;

                new_tail = mispredict_rob_tag + 1;

                for(int i=0; i<ROB_SIZE; i++) begin
                    logic [ROB_WIDTH-1:0] idx;
                    idx = i[ROB_WIDTH-1:0];
                    if (new_tail <= tail_ptr) begin
                        if (idx >= new_tail && idx < tail_ptr) rob_mem[idx].valid <= 0;
                    end else begin
                        if (idx >= new_tail || idx < tail_ptr) rob_mem[idx].valid <= 0;
                    end
                end

                tail_ptr <= new_tail;

                if (i_cdb_valid) begin
                    rob_mem[i_cdb_tag].busy <= 0;
                    if (rob_mem[i_cdb_tag].is_branch) begin
                        rob_mem[i_cdb_tag].taken <= i_cdb_taken;
                        rob_mem[i_cdb_tag].target <= i_cdb_target;
                    end
                end

                next_head = head_ptr;
                if (o_commit_valid) begin
                    rob_mem[head_ptr].valid <= 0;
                    head_ptr <= head_ptr + 1;
                    next_head = head_ptr + 1;
                end

                if (new_tail >= next_head)
                    new_count = new_tail - next_head;
                else
                    new_count = ROB_SIZE - next_head + new_tail;
                count <= new_count;
            end
            else begin
                logic alloc_this_cycle = i_valid && !o_full;
                logic commit_this_cycle = o_commit_valid;

                if (alloc_this_cycle) begin
                    rob_mem[i_tag].valid <= 1;
                    rob_mem[i_tag].busy <= 1;
                    rob_mem[i_tag].old_prd <= i_old_prd;
                    rob_mem[i_tag].is_branch <= i_is_branch;
                    rob_mem[i_tag].reg_write <= i_reg_write;
                    rob_mem[i_tag].pc <= i_pc;
                    // Reset outcome fields
                    rob_mem[i_tag].taken <= 0;
                    rob_mem[i_tag].target <= 0;
                    
                    tail_ptr <= i_tag + 1;
                    if (i_is_branch) tail_ptr_shadow <= i_tag + 1;
                end

                if (i_cdb_valid) begin
                    rob_mem[i_cdb_tag].busy <= 0;
                    if (rob_mem[i_cdb_tag].is_branch) begin
                        rob_mem[i_cdb_tag].taken <= i_cdb_taken;
                        rob_mem[i_cdb_tag].target <= i_cdb_target;
                    end
                end

                if (commit_this_cycle) begin
                    rob_mem[head_ptr].valid <= 0;
                    head_ptr <= head_ptr + 1;
                end

                if (alloc_this_cycle && !commit_this_cycle) count <= count + 1;
                else if (!alloc_this_cycle && commit_this_cycle) count <= count - 1;
            end
        end
    end
endmodule