`timescale 1ns / 1ps

module checkpoint_buffer #(
    parameter DATA_WIDTH      = 32,  // Width of state to save
    parameter ROB_WIDTH       = 4,   // Width of ROB Tag
    parameter NUM_CHECKPOINTS = 8    // Depth of speculation
) (
    input logic clk,
    input logic reset,

    // ==========================================
    // Allocation (Dispatch Stage)
    // ==========================================
    input  logic                   i_alloc,       // Snapshot trigger (is_branch_dispatch)
    input  logic [ROB_WIDTH-1:0]   i_rob_tag,     // Tag of the branch instruction
    input  logic [DATA_WIDTH-1:0]  i_data,        // State to save
    output logic                   o_full,

    // ==========================================
    // Commit (ROB Stage)
    // ==========================================
    input  logic                   i_commit,      // Instruction commit trigger
    input  logic [ROB_WIDTH-1:0]   i_commit_tag,  // Tag of committing instruction

    // ==========================================
    // Recovery (Writeback/ROB Stage)
    // ==========================================
    input  logic                   i_restore,     // Branch mispredict trigger
    input  logic [ROB_WIDTH-1:0]   i_restore_tag, // Tag of the mispredicted branch
    output logic [DATA_WIDTH-1:0]  o_restore_data // Restored state
);

    // Buffer Entry Structure
    typedef struct packed {
        logic [DATA_WIDTH-1:0] data;
        logic [ROB_WIDTH-1:0]  rob_tag;
    } checkpoint_t;

    checkpoint_t buffer [0:NUM_CHECKPOINTS-1];

    // Pointers for Circular Buffer
    localparam PTR_WIDTH = $clog2(NUM_CHECKPOINTS);
    logic [PTR_WIDTH:0] head_ptr; // Write pointer (Alloc)
    logic [PTR_WIDTH:0] tail_ptr; // Read pointer (Commit)
    
    logic [PTR_WIDTH:0] count;
    assign count = head_ptr - tail_ptr;

    // We consider it full if we wrap around
    assign o_full = (count == NUM_CHECKPOINTS);

    // -------------------------------------------------------------------------
    // Restore Logic (Combinational Search)
    // -------------------------------------------------------------------------
    logic found_checkpoint;
    logic [PTR_WIDTH-1:0] restore_idx;
    
    always_comb begin
        found_checkpoint = 1'b0;
        restore_idx = '0;
        o_restore_data = '0;
        
        // In case of misprediction, find the checkpoint corresponding to the branch
        if (i_restore) begin
            for (int i = 0; i < NUM_CHECKPOINTS; i++) begin
                if (buffer[i].rob_tag == i_restore_tag) begin
                    restore_idx = i[PTR_WIDTH-1:0];
                    o_restore_data = buffer[i].data;
                    found_checkpoint = 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sequential Logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            head_ptr <= '0;
            tail_ptr <= '0;
            for (int i = 0; i < NUM_CHECKPOINTS; i++) buffer[i] <= '0;
        end 
        else if (i_restore) begin
            // RECOVERY: Rollback Head pointer
            if (found_checkpoint) begin
                // Reset Head to the slot *after* the restored checkpoint
                // This preserves the valid checkpoint (conceptually) or effectively
                // frees all speculative checkpoints allocated *after* this branch.
                // Note: The specific pointer math depends on if you want to keep the current 
                // branch's checkpoint alive or not. Usually, once resolved, we don't need it 
                // for *this* branch anymore, but we might keep it if we treat it as arch state.
                // Here we essentially flush everything younger.
                
                // Assuming we reconstruct head based on the index found:
                // We keep the "phase" bit from the tail side logic or just simplify:
                head_ptr <= {head_ptr[PTR_WIDTH], restore_idx} + 1'b1;
            end
        end
        else begin
            // 1. COMMIT (Freeing Checkpoints)
            // If the oldest checkpoint matches the committing instruction, free it.
            if (i_commit && (count > 0)) begin
                if (buffer[tail_ptr[PTR_WIDTH-1:0]].rob_tag == i_commit_tag) begin
                    tail_ptr <= tail_ptr + 1'b1;
                end
            end

            // 2. ALLOCATION (Saving Checkpoints)
            if (i_alloc && !o_full) begin
                buffer[head_ptr[PTR_WIDTH-1:0]].data    <= i_data;
                buffer[head_ptr[PTR_WIDTH-1:0]].rob_tag <= i_rob_tag;
                head_ptr <= head_ptr + 1'b1;
            end
        end
    end

endmodule