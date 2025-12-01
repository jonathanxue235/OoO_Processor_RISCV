`timescale 1ns / 1ps

module reservation_station #(
    parameter PREG_WIDTH = 7,
    parameter ROB_WIDTH  = 4,
    parameter RS_SIZE    = 8
) (
    input logic clk,
    input logic reset,

    // ------------------------------------
    // Allocation Interface
    // ------------------------------------
    input logic i_valid,          
    input logic [31:0]           i_pc,
    input logic [PREG_WIDTH-1:0] i_prs1,
    input logic [PREG_WIDTH-1:0] i_prs2,
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,
    input logic [31:0]           i_imm,
    input logic [3:0]            i_alu_op,

    // Initial Readiness (from Rat/BusyTable at Dispatch)
    input logic i_rs1_ready,
    input logic i_rs2_ready,

    output logic o_full,

    // ------------------------------------
    // Writeback / Wakeup Interface (CDB Snooping)
    // ------------------------------------
    input logic                  i_cdb_valid,
    input logic [PREG_WIDTH-1:0] i_cdb_prd,

    // ------------------------------------
    // Issue Interface (To Execution)
    // ------------------------------------
    input  logic i_eu_ready,
    output logic o_issue_valid,
    output logic [PREG_WIDTH-1:0] o_issue_prs1,
    output logic [PREG_WIDTH-1:0] o_issue_prs2,
    output logic [PREG_WIDTH-1:0] o_issue_prd,
    output logic [ROB_WIDTH-1:0]  o_issue_rob_tag,
    output logic [31:0]           o_issue_imm,
    output logic [3:0]            o_issue_alu_op,
    output logic [31:0]           o_issue_pc,

    // Recovery
    input logic branch_mispredict
);

    // RS Entry Struct
    typedef struct packed {
        logic valid;
        logic rs1_ready; // Split ready bit
        logic rs2_ready; // Split ready bit
        logic [PREG_WIDTH-1:0] prs1;
        logic [PREG_WIDTH-1:0] prs2;
        logic [PREG_WIDTH-1:0] prd;
        logic [ROB_WIDTH-1:0]  rob_tag;
        logic [31:0]           imm;
        logic [3:0]            alu_op;
        logic [31:0]           pc;
    } rs_entry_t;

    rs_entry_t rs_entries [0:RS_SIZE-1];

    // --- Allocation (Priority Encoder) ---
    logic [31:0] alloc_idx;
    logic        found_free;

    always_comb begin
        alloc_idx = 0;
        found_free = 0;
        for (int i = 0; i < RS_SIZE; i++) begin
            if (!rs_entries[i].valid) begin
                alloc_idx = i;
                found_free = 1;
                break;
            end
        end
    end

    assign o_full = !found_free;

    // --- Issue (Priority Encoder) ---
    logic [31:0] issue_idx;
    logic        found_ready;

    always_comb begin
        issue_idx = 0;
        found_ready = 0;
        for (int i = 0; i < RS_SIZE; i++) begin
            // Instruction is ready if VALID and BOTH operands are READY
            if (rs_entries[i].valid && rs_entries[i].rs1_ready && rs_entries[i].rs2_ready) begin
                issue_idx = i;
                found_ready = 1;
                break;
            end
        end
    end

    assign o_issue_valid = found_ready;

    always_comb begin
        if (found_ready) begin
            o_issue_prs1    = rs_entries[issue_idx].prs1;
            o_issue_prs2    = rs_entries[issue_idx].prs2;
            o_issue_prd     = rs_entries[issue_idx].prd;
            o_issue_rob_tag = rs_entries[issue_idx].rob_tag;
            o_issue_imm     = rs_entries[issue_idx].imm;
            o_issue_alu_op  = rs_entries[issue_idx].alu_op;
            o_issue_pc      = rs_entries[issue_idx].pc;
        end else begin
            o_issue_prs1 = '0; o_issue_prs2 = '0;
            o_issue_prd = '0;
            o_issue_rob_tag = '0; o_issue_imm = '0; o_issue_alu_op = '0; o_issue_pc = '0;
        end
    end

    // --- Sequential Logic ---
    always_ff @(posedge clk) begin
        if (reset || branch_mispredict) begin
            for (int i = 0; i < RS_SIZE; i++) begin
                rs_entries[i].valid <= 0;
                rs_entries[i].rs1_ready <= 0;
                rs_entries[i].rs2_ready <= 0;
            end
        end
        else begin
            // 1. ALLOCATION
            if (i_valid && !o_full) begin
                rs_entries[alloc_idx].valid     <= 1'b1;
                rs_entries[alloc_idx].prs1      <= i_prs1;
                rs_entries[alloc_idx].prs2      <= i_prs2;
                rs_entries[alloc_idx].prd       <= i_prd;
                rs_entries[alloc_idx].rob_tag   <= i_rob_tag;
                rs_entries[alloc_idx].imm       <= i_imm;
                rs_entries[alloc_idx].alu_op    <= i_alu_op;
                rs_entries[alloc_idx].pc        <= i_pc;

                // Initial Readiness Check
                // If the operand is ready at dispatch OR if it's being broadcast on CDB *right now*
                rs_entries[alloc_idx].rs1_ready <= i_rs1_ready || (i_cdb_valid && i_cdb_prd == i_prs1 && i_prs1 != 0);
                rs_entries[alloc_idx].rs2_ready <= i_rs2_ready || (i_cdb_valid && i_cdb_prd == i_prs2 && i_prs2 != 0);
            end

            // 2. WAKEUP (CDB Snooping)
            if (i_cdb_valid) begin
                for (int i = 0; i < RS_SIZE; i++) begin
                    if (rs_entries[i].valid) begin
                        // If waiting for rs1 and CDB broadcasts it
                        if (!rs_entries[i].rs1_ready && rs_entries[i].prs1 == i_cdb_prd && i_cdb_prd != 0) begin
                            rs_entries[i].rs1_ready <= 1'b1;
                        end
                        // If waiting for rs2 and CDB broadcasts it
                        if (!rs_entries[i].rs2_ready && rs_entries[i].prs2 == i_cdb_prd && i_cdb_prd != 0) begin
                            rs_entries[i].rs2_ready <= 1'b1;
                        end
                    end
                end
            end

            // 3. ISSUE (Clear entry)
            // Note: If we allocate and issue in same cycle, issue logic must handle it. 
            // Simplified here: Issue takes precedence over keeping the entry.
            if (found_ready && i_eu_ready) begin
                rs_entries[issue_idx].valid <= 0;
                rs_entries[issue_idx].rs1_ready <= 0;
                rs_entries[i_eu_ready ? issue_idx : issue_idx].rs2_ready <= 0; // Fix ternary syntax for cleanliness
            end
        end
    end
endmodule