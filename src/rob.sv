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
    input logic branch_mispredict
);
    localparam ROB_SIZE = 1 << ROB_WIDTH;

    typedef struct packed {
        logic valid;
        logic busy;      
        logic is_branch;
        logic [PREG_WIDTH-1:0] old_prd;
        logic [31:0] pc;
    } rob_entry_t;

    rob_entry_t rob_mem [0:ROB_SIZE-1];

    logic [ROB_WIDTH-1:0] head_ptr;
    logic [ROB_WIDTH-1:0] head_ptr_shadow;
    logic [ROB_WIDTH:0] count; 

    assign o_full = (count == ROB_SIZE);
    
    assign o_commit_valid    = rob_mem[head_ptr].valid && !rob_mem[head_ptr].busy && (count > 0);
    assign o_commit_old_preg = rob_mem[head_ptr].old_prd;
    assign o_commit_tag      = head_ptr;

    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr <= 0;
            head_ptr_shadow <= 0;
            count <= 0;
            for(int i=0; i<ROB_SIZE; i++) rob_mem[i] <= '0;
        end
        else begin
            if (branch_mispredict) begin
                head_ptr <= head_ptr_shadow; 
                count <= 0; 
                for(int i=0; i<ROB_SIZE; i++) rob_mem[i].valid <= 0;
            end
            else begin
                if (i_valid && !o_full) begin
                    rob_mem[i_tag].valid <= 1;
                    rob_mem[i_tag].busy  <= 1;
                    rob_mem[i_tag].old_prd <= i_old_prd;
                    rob_mem[i_tag].is_branch <= i_is_branch;
                    rob_mem[i_tag].pc <= i_pc;
                    
                    if (!o_commit_valid) count <= count + 1;
                end
                
                if (i_cdb_valid) begin
                    rob_mem[i_cdb_tag].busy <= 0;
                end

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