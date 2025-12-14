`timescale 1ns / 1ps

module rob #(
    parameter ROB_WIDTH = 4,
    parameter PREG_WIDTH = 7
) (
    input logic clk,
    input logic reset,
    
    // Dispatch Interface
    input logic i_valid,                 
    input logic [ROB_WIDTH-1:0] i_tag,   
    input logic [PREG_WIDTH-1:0] i_old_prd, 
    input logic i_is_branch,       
    input logic i_reg_write,        
    input logic [31:0] i_pc,             
    output logic o_full,
    
    // CDB / Writeback Interface
    input logic i_cdb_valid,
    input logic [ROB_WIDTH-1:0] i_cdb_tag,
    input logic branch_mispredict, // High if the CDB result is a misprediction

    // Commit Interface
    output logic o_commit_valid,
    output logic [PREG_WIDTH-1:0] o_commit_old_preg,
    output logic [ROB_WIDTH-1:0] o_commit_tag
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
    logic [ROB_WIDTH-1:0] tail_ptr;         
    logic [ROB_WIDTH-1:0] tail_ptr_shadow;  // Maintained for debug/legacy, not used for flush
    logic [ROB_WIDTH:0] count;              // 1 extra bit to distinguish full vs empty

    assign o_full = (count == ROB_SIZE);
    
    // Commit Logic: Head must be valid, not busy, and ROB must not be empty
    assign o_commit_valid = rob_mem[head_ptr].valid && !rob_mem[head_ptr].busy && (count > 0);
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
            // ---------------------------------------------------------
            // 1. CDB Writeback (Always process, independent of flush)
            // ---------------------------------------------------------
            if (i_cdb_valid) begin
                rob_mem[i_cdb_tag].busy <= 0;
            end

            // ---------------------------------------------------------
            // 2. Branch Misprediction Handling (High Priority)
            // ---------------------------------------------------------
            if (branch_mispredict) begin
                // FLUSH LOGIC FIXED:
                // Use the tag from the CDB (the branch that just executed) to determine
                // the restore point. We keep the branch (it will commit), but flush
                // everything allocated *after* it.
                // New tail becomes the slot immediately following the branch.
                tail_ptr <= i_cdb_tag + 1'b1;

                // Recalculate count based on the dropped instructions.
                // The number of items remaining is the distance from head to the new tail.
                // (Using ROB_WIDTH bits automatically handles the modulo wrapping)
                count <= {1'b0, (ROB_WIDTH)'((i_cdb_tag + 1'b1) - head_ptr)};
                
                // Note: We do NOT increment head_ptr in the flush cycle to avoid race conditions 
                // on 'count' and to ensure the pipeline stabilizes. The mispredicting branch 
                // will commit in the next cycle (since we just cleared its busy bit above).
            end
            else begin
                // ---------------------------------------------------------
                // 3. Normal Operation (Dispatch & Commit)
                // ---------------------------------------------------------
                
                // --- Dispatch (Allocation) ---
                if (i_valid && !o_full) begin
                    rob_mem[i_tag].valid     <= 1;
                    rob_mem[i_tag].busy      <= 1;
                    rob_mem[i_tag].old_prd   <= i_old_prd;
                    rob_mem[i_tag].is_branch <= i_is_branch;
                    rob_mem[i_tag].reg_write <= i_reg_write;
                    rob_mem[i_tag].pc        <= i_pc;

                    tail_ptr <= tail_ptr + 1;
                    if (i_is_branch)
                        tail_ptr_shadow <= tail_ptr + 1; // Snapshot for legacy/debug
                end

                // --- Commit Update ---
                if (o_commit_valid) begin
                    rob_mem[head_ptr].valid <= 0; // Mark done
                    head_ptr <= head_ptr + 1;
                end
                
                // --- Count Update ---
                // Handle simultaneous Dispatch and Commit
                if ((i_valid && !o_full) && !o_commit_valid) begin
                    count <= count + 1;
                end
                else if (!(i_valid && !o_full) && o_commit_valid) begin
                    count <= count - 1;
                end
                // If both happen, count stays the same.
            end
        end
    end

endmodule