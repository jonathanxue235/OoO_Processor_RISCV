`timescale 1ns / 1ps

module branch_predictor #(
    parameter PC_WIDTH = 32,
    parameter BTB_SIZE = 8
) (
    input logic clk,
    input logic reset,

    // Fetch Interface
    input logic [PC_WIDTH-1:0] fetch_pc,
    output logic pred_taken,
    output logic [PC_WIDTH-1:0] pred_target,

    // Update Interface (from Commit)
    input logic update_valid,
    input logic [PC_WIDTH-1:0] update_pc,
    input logic update_taken,
    input logic [PC_WIDTH-1:0] update_target
);

    // BTB Entry Structure
    typedef struct packed {
        logic valid;
        logic [PC_WIDTH-1:0] tag;
        logic [PC_WIDTH-1:0] target;
        logic [1:0] bht; // 00: SN, 01: WN, 10: WT, 11: ST
    } btb_entry_t;

    btb_entry_t btb [0:BTB_SIZE-1];
    logic [$clog2(BTB_SIZE)-1:0] replace_ptr; // FIFO/Round-Robin replacement

    // ----------------------------------------------------
    // Prediction Logic (Combinational)
    // ----------------------------------------------------
    logic hit;
    logic [1:0] hit_bht;
    logic [PC_WIDTH-1:0] hit_target;

    always_comb begin
        hit = 1'b0;
        hit_bht = 2'b00; // Default Not Taken
        hit_target = fetch_pc + 4; // Default fallthrough (safety)
        
        for (int i = 0; i < BTB_SIZE; i++) begin
            if (btb[i].valid && btb[i].tag == fetch_pc) begin
                hit = 1'b1;
                hit_bht = btb[i].bht;
                hit_target = btb[i].target;
            end
        end
    end

    // Predict Taken if Hit AND (Weakly Taken or Strongly Taken)
    assign pred_taken = hit && (hit_bht >= 2'b10);
    assign pred_target = hit ? hit_target : (fetch_pc + 32'd4);

    // ----------------------------------------------------
    // Update Logic (Synchronous)
    // ----------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb[i] <= '0;
            end
            replace_ptr <= '0;
        end
        else if (update_valid) begin
            int match_idx;
            logic match_found;
            
            match_found = 1'b0;
            match_idx = -1;

            // Search for existing entry
            for (int i = 0; i < BTB_SIZE; i++) begin
                if (btb[i].valid && btb[i].tag == update_pc) begin
                    match_found = 1'b1;
                    match_idx = i;
                end
            end

            if (match_found) begin
                // Update BHT
                if (update_taken) begin
                    if (btb[match_idx].bht != 2'b11)
                        btb[match_idx].bht <= btb[match_idx].bht + 1;
                end else begin
                    if (btb[match_idx].bht != 2'b00)
                        btb[match_idx].bht <= btb[match_idx].bht - 1;
                end
                // Update Target (crucial for JALR or first time learning)
                btb[match_idx].target <= update_target;
            end
            else if (update_taken) begin
                // Allocate new entry only if branch was Taken (don't train on NT branches usually, 
                // but can be adjusted. Here we allocate on Taken to learn the stream).
                btb[replace_ptr].valid <= 1'b1;
                btb[replace_ptr].tag <= update_pc;
                btb[replace_ptr].target <= update_target;
                btb[replace_ptr].bht <= 2'b10; // Initialize to Weakly Taken
                
                replace_ptr <= replace_ptr + 1;
            end
        end
    end

endmodule