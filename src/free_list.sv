`timescale 1ns / 1ps

module free_list #(
    parameter PREG_WIDTH = 7, // 128 Registers
    parameter ROB_WIDTH  = 4  // NEW: Needed for snapshot indexing
) (
    input logic clk,
    input logic reset,

    // Allocate Interface (Rename Stage)
    input logic alloc_req,          // We need a register
    output logic [PREG_WIDTH-1:0] alloc_preg, // The register given
    output logic alloc_valid,       // Is a register actually available?

    // Commit Interface (ROB Stage)
    input logic commit_en,
    input logic [PREG_WIDTH-1:0] commit_old_preg, // The register being freed

    // Branch / Recovery Interface
    input logic is_branch_dispatch, // Snapshot Head Pointer
    input logic [ROB_WIDTH-1:0] dispatch_tag, // NEW: Tag of the dispatching branch
    
    input logic branch_mispredict,   // Restore Head Pointer
    input logic [ROB_WIDTH-1:0] recovery_tag // NEW: Tag of the mispredicting branch
);
    localparam NUM_PREGS = 1 << PREG_WIDTH; // 128
    localparam NUM_AREGS = 32;
    // 32 Architectural Regs
    localparam NUM_SNAPSHOTS = 1 << ROB_WIDTH;

    // The Free List Queue
    logic [PREG_WIDTH-1:0] free_list_queue [0:NUM_PREGS-1];

    // Pointers
    logic [PREG_WIDTH:0] head_ptr; // Allocation Pointer
    logic [PREG_WIDTH:0] tail_ptr; // Commit/Free Pointer
    
    // Shadow Pointer Array for Recovery
    logic [PREG_WIDTH:0] head_ptr_snapshots [0:NUM_SNAPSHOTS-1]; // NEW: Array

    // Count of free registers
    logic [PREG_WIDTH:0] count;
    assign count = tail_ptr - head_ptr;

    // Are we empty?
    assign alloc_valid = (count != 0);

    // Current free register is at the Head
    assign alloc_preg = free_list_queue[head_ptr[PREG_WIDTH-1:0]];

    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr <= '0;
            tail_ptr <= '0;
            
            // Initialize Free List
            for (int i = 0; i < NUM_PREGS; i++) begin
                if (i < (NUM_PREGS - NUM_AREGS)) 
                    free_list_queue[i] <= i + NUM_AREGS;
                else 
                    free_list_queue[i] <= '0;
            end
            
            tail_ptr <= (NUM_PREGS - NUM_AREGS);
        end
        else begin
            if (branch_mispredict) begin
                // RECOVERY:
                // Restore head ptr from the specific snapshot corresponding to the mispredicted branch
                head_ptr <= head_ptr_snapshots[recovery_tag];
            end
            else begin
                // 1. Allocation (Move Head)
                if (alloc_req && alloc_valid) begin
                    head_ptr <= head_ptr + 1;
                end

                // 2. Commit / Freeing (Move Tail)
                if (commit_en && commit_old_preg != 0) begin // Never free P0
                    free_list_queue[tail_ptr[PREG_WIDTH-1:0]] <= commit_old_preg;
                    tail_ptr <= tail_ptr + 1;
                end

                // 3. Snapshot for Branch
                if (is_branch_dispatch) begin
                    // Save the state of the Head pointer *after* potential allocation
                    // into the slot corresponding to the current branch's ROB tag
                    if (alloc_req && alloc_valid)
                        head_ptr_snapshots[dispatch_tag] <= head_ptr + 1;
                    else
                        head_ptr_snapshots[dispatch_tag] <= head_ptr;
                end
            end
        end
    end

endmodule