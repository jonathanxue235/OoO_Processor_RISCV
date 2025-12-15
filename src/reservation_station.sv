`timescale 1ns / 1ps

module reservation_station #(
    parameter PREG_WIDTH = 7,
    parameter ROB_WIDTH  = 4,
    parameter RS_SIZE    = 8,
    parameter STRICT_ORDER = 0 // NEW PARAMETER: Default to 0 (OoO)
) (
    input logic clk,
    input logic reset,
    // ... (Keep existing ports unchanged)
    // Allocation Interface
    input logic i_valid,          
    input logic [31:0]           i_pc,
    input logic [PREG_WIDTH-1:0] i_prs1,
    input logic [PREG_WIDTH-1:0] i_prs2,
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,
    input logic [31:0]           i_imm,
    input logic [3:0]            i_alu_op,
    input logic                  i_alusrc,
    input logic                  i_memwrite,

    // Initial Readiness
    input logic i_rs1_ready,
    input logic i_rs2_ready,

    output logic o_full,

    // Writeback / Wakeup
    input logic                  i_cdb_valid,
    input logic [PREG_WIDTH-1:0] i_cdb_prd,

    // Issue Interface
    input  logic i_eu_ready,
    output logic o_issue_valid,
    output logic [PREG_WIDTH-1:0] o_issue_prs1,
    output logic [PREG_WIDTH-1:0] o_issue_prs2,
    output logic [PREG_WIDTH-1:0] o_issue_prd,
    output logic [ROB_WIDTH-1:0]  o_issue_rob_tag,
    output logic [31:0]           o_issue_imm,
    output logic [3:0]            o_issue_alu_op,
    output logic [31:0]           o_issue_pc,
    output logic                  o_issue_alusrc,
    output logic                  o_issue_memwrite,

    // Recovery
    input logic branch_mispredict,
    input logic [ROB_WIDTH-1:0] mispredict_rob_tag
);

    // ... (Keep struct and rs_entries declaration unchanged)
    typedef struct packed {
        logic valid;
        logic rs1_ready;
        logic rs2_ready;
        logic [PREG_WIDTH-1:0] prs1;
        logic [PREG_WIDTH-1:0] prs2;
        logic [PREG_WIDTH-1:0] prd;
        logic [ROB_WIDTH-1:0]  rob_tag;
        logic [31:0]           imm;
        logic [3:0]            alu_op;
        logic [31:0]           pc;
        logic                  alusrc;
        logic                  memwrite;
    } rs_entry_t;

    rs_entry_t rs_entries [0:RS_SIZE-1];

    // --- Allocation (Priority Encoder) ---
    // (Keep allocation logic unchanged)
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

    // --- Issue Logic ---
    logic [31:0] issue_idx;
    logic        found_ready;

    always_comb begin
        issue_idx = 0;
        found_ready = 0;

        if (STRICT_ORDER) begin
            // STRICT ORDER MODE: Only issue the OLDEST valid instruction if it is ready.
            // We find the entry with the "smallest" ROB tag (handling wrapping).
            int oldest_idx = -1;
            logic [ROB_WIDTH-1:0] min_tag;
            
            for (int i = 0; i < RS_SIZE; i++) begin
                if (rs_entries[i].valid) begin
                    if (oldest_idx == -1) begin
                        oldest_idx = i;
                        min_tag = rs_entries[i].rob_tag;
                    end else begin
                        // Compare tags: (TagB - TagA) < (HalfRange) implies A is older
                        // Width=4 -> Size=16. Half=8.
                        logic [ROB_WIDTH-1:0] tag_curr = rs_entries[i].rob_tag;
                        logic [ROB_WIDTH-1:0] diff = min_tag - tag_curr; // (Oldest - Curr)
                        
                        // If (min - curr) is large positive (negative in signed), then min is actually YOUNGER (wrapped).
                        // Easier check: Is (Curr - Min) < 8? Then Curr is Young (Min is Old).
                        // Is (Min - Curr) < 8? Then Min is Young (Curr is Old).
                        
                        if ((min_tag - tag_curr) < (1 << (ROB_WIDTH-1))) begin
                            // min_tag is "younger" (larger) than tag_curr in circular logic, 
                            // so tag_curr is the new oldest.
                            oldest_idx = i;
                            min_tag = tag_curr;
                        end
                    end
                end
            end

            // Check if the identified oldest instruction is ready
            if (oldest_idx != -1 && rs_entries[oldest_idx].rs1_ready && rs_entries[oldest_idx].rs2_ready) begin
                issue_idx = oldest_idx;
                found_ready = 1;
            end

        end else begin
            // STANDARD OoO MODE: First Ready
            for (int i = 0; i < RS_SIZE; i++) begin
                if (rs_entries[i].valid && rs_entries[i].rs1_ready && rs_entries[i].rs2_ready) begin
                    issue_idx = i;
                    found_ready = 1;
                    break;
                end
            end
        end
    end

    assign o_issue_valid = found_ready;
    
    // ... (Rest of module: Output muxing and Sequential Logic unchanged)
    always_comb begin
        if (found_ready) begin
            o_issue_prs1    = rs_entries[issue_idx].prs1;
            o_issue_prs2    = rs_entries[issue_idx].prs2;
            o_issue_prd     = rs_entries[issue_idx].prd;
            o_issue_rob_tag = rs_entries[issue_idx].rob_tag;
            o_issue_imm     = rs_entries[issue_idx].imm;
            o_issue_alu_op  = rs_entries[issue_idx].alu_op;
            o_issue_pc      = rs_entries[issue_idx].pc;
            o_issue_alusrc  = rs_entries[issue_idx].alusrc;
            o_issue_memwrite = rs_entries[issue_idx].memwrite; 
        end else begin
            o_issue_prs1 = '0;
            o_issue_prs2 = '0; o_issue_prd = '0;
            o_issue_rob_tag = '0; o_issue_imm = '0; o_issue_alu_op = '0; 
            o_issue_pc = '0;
            o_issue_alusrc = '0;
            o_issue_memwrite = '0;
        end
    end

    // Sequential Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < RS_SIZE; i++) begin
                rs_entries[i].valid <= 0;
                rs_entries[i].rs1_ready <= 0;
                rs_entries[i].rs2_ready <= 0;
                rs_entries[i].memwrite <= 0;
            end
        end
        else if (branch_mispredict) begin
            for (int i = 0; i < RS_SIZE; i++) begin
                if (rs_entries[i].valid) begin
                    // Modular comparison logic for flushing younger instructions
                    logic [ROB_WIDTH-1:0] diff_tag = rs_entries[i].rob_tag - mispredict_rob_tag;
                    if (diff_tag < (1 << (ROB_WIDTH-1)) && diff_tag != 0) begin 
                       // If tag > mispredict (circularly), invalidate
                        rs_entries[i].valid <= 0;
                        rs_entries[i].rs1_ready <= 0;
                        rs_entries[i].rs2_ready <= 0;
                    end
                end
            end
            
            if (found_ready && i_eu_ready) begin
                rs_entries[issue_idx].valid <= 0;
                rs_entries[issue_idx].rs1_ready <= 0;
                rs_entries[issue_idx].rs2_ready <= 0;
            end
        end
        else begin
            // ALLOCATION
            if (i_valid && !o_full) begin
                rs_entries[alloc_idx].valid     <= 1'b1;
                rs_entries[alloc_idx].prs1      <= i_prs1;
                rs_entries[alloc_idx].prs2      <= i_prs2;
                rs_entries[alloc_idx].prd       <= i_prd;
                rs_entries[alloc_idx].rob_tag   <= i_rob_tag;
                rs_entries[alloc_idx].imm       <= i_imm;
                rs_entries[alloc_idx].alu_op    <= i_alu_op;
                rs_entries[alloc_idx].pc        <= i_pc;
                rs_entries[alloc_idx].alusrc    <= i_alusrc;
                rs_entries[alloc_idx].memwrite  <= i_memwrite;
                
                rs_entries[alloc_idx].rs1_ready <= i_rs1_ready || (i_cdb_valid && i_cdb_prd == i_prs1 && i_prs1 != 0);
                rs_entries[alloc_idx].rs2_ready <= i_rs2_ready || (i_cdb_valid && i_cdb_prd == i_prs2 && i_prs2 != 0);
            end

            // WAKEUP
            if (i_cdb_valid) begin
                for (int i = 0; i < RS_SIZE; i++) begin
                    if (rs_entries[i].valid) begin
                        if (!rs_entries[i].rs1_ready && rs_entries[i].prs1 == i_cdb_prd && i_cdb_prd != 0)
                            rs_entries[i].rs1_ready <= 1'b1;
                        if (!rs_entries[i].rs2_ready && rs_entries[i].prs2 == i_cdb_prd && i_cdb_prd != 0)
                            rs_entries[i].rs2_ready <= 1'b1;
                    end
                end
            end

            // ISSUE
            if (found_ready && i_eu_ready) begin
                rs_entries[issue_idx].valid <= 0;
                rs_entries[issue_idx].rs1_ready <= 0;
                rs_entries[issue_idx].rs2_ready <= 0;
            end
        end
    end
endmodule