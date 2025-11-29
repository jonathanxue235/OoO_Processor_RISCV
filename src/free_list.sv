`timescale 1ns / 1ps

module free_list #(
    parameter PREG_WIDTH = 7 // 128 Registers
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
    input logic branch_mispredict   // Restore Head Pointer
);

    localparam NUM_PREGS = 1 << PREG_WIDTH; // 64
    localparam NUM_AREGS = 32;              // 32 Architectural Regs

    // The Free List Queue
    // We only need to store (NUM_PREGS - NUM_AREGS) entries roughly, 
    // but sizing to NUM_PREGS is safe.
    logic [PREG_WIDTH-1:0] free_list_queue [0:NUM_PREGS-1];

    // Pointers
    logic [PREG_WIDTH:0] head_ptr; // Allocation Pointer (extra bit for wrap detection)
    logic [PREG_WIDTH:0] tail_ptr; // Commit/Free Pointer
    
    // Shadow Pointer for Recovery
    logic [PREG_WIDTH:0] head_ptr_shadow;
    
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
            head_ptr_shadow <= '0;
            
            // Initialize Free List
            // We cannot put P0-P31 in free list initially because they are mapped to x0-x31
            // So we fill free list with P32, P33, ... P63
            for (int i = 0; i < NUM_PREGS; i++) begin
                if (i < (NUM_PREGS - NUM_AREGS)) begin
                    // FIX: Removed [PREG_WIDTH-1:0] slicing on expression
                    // Implicit truncation handles the width automatically.
                    free_list_queue[i] <= i + NUM_AREGS;
                end else begin
                    free_list_queue[i] <= '0;
                end
            end
            
            // Set Tail to cover the initialized range (32 entries)
            tail_ptr <= (NUM_PREGS - NUM_AREGS); 
        end
        else begin
            if (branch_mispredict) begin
                // RECOVERY:
                // We reset the allocation pointer back to where it was at the branch.
                // Any registers allocated *after* the branch are implicitly "freed" 
                // because the head pointer moves back, making them valid for allocation again.
                head_ptr <= head_ptr_shadow;
            end
            else begin
                // 1. Allocation (Move Head)
                if (alloc_req && alloc_valid) begin
                    head_ptr <= head_ptr + 1;
                end

                // 2. Commit / Freeing (Move Tail)
                // When an instruction commits, it frees the *old* physical register 
                // that was previously mapped to its destination.
                if (commit_en && commit_old_preg != 0) begin // Never free P0
                    free_list_queue[tail_ptr[PREG_WIDTH-1:0]] <= commit_old_preg;
                    tail_ptr <= tail_ptr + 1;
                end

                // 3. Snapshot for Branch
                if (is_branch_dispatch) begin
                    // Save the state of the Head pointer *after* potential allocation
                    if (alloc_req && alloc_valid)
                        head_ptr_shadow <= head_ptr + 1;
                    else
                        head_ptr_shadow <= head_ptr;
                end
            end
        end
    end

endmodule