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

    // Writeback
    input logic i_cdb_valid,
    input logic [ROB_WIDTH-1:0] i_cdb_tag,

    // Commit
    output logic o_commit_valid,
    output logic [PREG_WIDTH-1:0] o_commit_old_preg,
    output logic [ROB_WIDTH-1:0] o_commit_tag,

    // Recovery
    input logic branch_mispredict,
    input logic [ROB_WIDTH-1:0] i_mispredict_tag 
);
    localparam ROB_SIZE = 1 << ROB_WIDTH;

    typedef struct packed {
        logic valid;
        logic busy;      
        logic is_branch;
        logic reg_write; 
        logic [PREG_WIDTH-1:0] old_prd;
        logic [31:0] pc;
    } rob_entry_t;

    rob_entry_t rob_mem [0:ROB_SIZE-1];

    logic [ROB_WIDTH-1:0] head_ptr;
    logic [ROB_WIDTH-1:0] head_ptr_shadow; 
    logic [ROB_WIDTH:0] count;

    assign o_full = (count == ROB_SIZE);
    
    assign o_commit_valid = rob_mem[head_ptr].valid && !rob_mem[head_ptr].busy && (count > 0);
    assign o_commit_old_preg = (rob_mem[head_ptr].reg_write) ? rob_mem[head_ptr].old_prd : '0;
    assign o_commit_tag      = head_ptr;

    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr <= 0;
            head_ptr_shadow <= 0;
            count <= 0;
            for(int i=0; i<ROB_SIZE; i++) rob_mem[i] <= '0;
        end
        else begin
            // 1. ALWAYS process CDB updates (Mark instructions as not busy)
            // This must happen even during mispredict recovery so the branch itself completes.
            if (i_cdb_valid) begin
                rob_mem[i_cdb_tag].busy <= 0;
            end

            // 2. Recovery or Normal Operation
            if (branch_mispredict) begin
                // === SELECTIVE FLUSH ===
                // Retain instructions from Head up to and including the Mispredicted Branch
                if (i_mispredict_tag >= head_ptr) begin
                     count <= (i_mispredict_tag - head_ptr + 1);
                end else begin
                     count <= (ROB_SIZE - head_ptr) + i_mispredict_tag + 1;
                end

                // Invalidate ONLY instructions younger than the branch
                for (int i = 0; i < ROB_SIZE; i++) begin
                    logic keep;
                    // Check if index 'i' is inside the valid window [head, branch]
                    if (i_mispredict_tag >= head_ptr) begin
                        keep = (i >= head_ptr && i <= i_mispredict_tag);
                    end else begin
                        keep = (i >= head_ptr || i <= i_mispredict_tag);
                    end
                    
                    if (!keep) begin
                        rob_mem[i].valid <= 0;
                        rob_mem[i].busy  <= 0;
                    end
                end
            end
            else begin
                // Normal Allocation
                if (i_valid && !o_full) begin
                    rob_mem[i_tag].valid <= 1;
                    rob_mem[i_tag].busy  <= 1;
                    rob_mem[i_tag].old_prd <= i_old_prd;
                    rob_mem[i_tag].is_branch <= i_is_branch;
                    rob_mem[i_tag].reg_write <= i_reg_write;
                    rob_mem[i_tag].pc <= i_pc;
                    if (!o_commit_valid) count <= count + 1;
                end
                
                // Commit
                if (o_commit_valid) begin
                    rob_mem[head_ptr].valid <= 0;
                    head_ptr <= head_ptr + 1;
                    if (rob_mem[head_ptr].is_branch)
                         head_ptr_shadow <= head_ptr + 1;
                    
                    if (!i_valid) count <= count - 1;
                end
            end
        end
    end
endmodule
