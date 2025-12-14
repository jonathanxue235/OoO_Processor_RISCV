`timescale 1ns / 1ps

module lsq #(
    parameter LSQ_SIZE = 16,
    parameter ROB_WIDTH = 4,
    parameter PREG_WIDTH = 7
)(
    input logic clk,
    input logic reset,

    // ========================================
    // Allocation Interface (from Dispatch)
    // ========================================
    input  logic                  i_alloc,
    input  logic [ROB_WIDTH-1:0]  i_alloc_rob_tag,
    input  logic                  i_is_store,
    input  logic [2:0]            i_mem_op,        // funct3 (LB/LH/LW/LBU/LHU/SB/SH/SW)
    input  logic [PREG_WIDTH-1:0] i_prd,           // Physical destination (for loads)
    output logic [3:0]            o_alloc_index,   // LSQ index allocated
    output logic                  o_full,          // LSQ is full

    // ========================================
    // Address Calculation Interface (from RS issue)
    // ========================================
    input  logic                  i_issue_valid,
    input  logic [3:0]            i_issue_lsq_index,
    input  logic [31:0]           i_base_addr,
    input  logic [31:0]           i_offset,
    input  logic [31:0]           i_store_data,    // For stores

    // ========================================
    // Load Issue to Memory Interface
    // ========================================
    output logic                  o_load_issue_valid,
    output logic [31:0]           o_load_addr,
    output logic [3:0]            o_load_lsq_index,
    output logic [2:0]            o_load_mem_op,
    output logic [1:0]            o_load_byte_offset,
    input  logic                  i_memory_ready,

    // ========================================
    // Load Completion from Memory Interface
    // ========================================
    input  logic                  i_load_complete_valid,
    input  logic [3:0]            i_load_complete_lsq_index,
    input  logic [31:0]           i_load_data,

    // ========================================
    // CDB Writeback Interface
    // ========================================
    output logic                  o_cdb_valid,
    output logic [PREG_WIDTH-1:0] o_cdb_prd,
    output logic [ROB_WIDTH-1:0]  o_cdb_rob_tag,
    output logic [31:0]           o_cdb_data,

    // ========================================
    // Store Commit Interface (from ROB)
    // ========================================
    input  logic                  i_commit_valid,
    input  logic [ROB_WIDTH-1:0]  i_commit_rob_tag,
    input  logic                  i_commit_is_store,
    output logic                  o_store_commit_valid,
    output logic [31:0]           o_store_commit_addr,
    output logic [31:0]           o_store_commit_data,
    output logic [2:0]            o_store_commit_op,
    output logic [1:0]            o_store_commit_byte_offset,

    // ========================================
    // Branch Recovery Interface
    // ========================================
    input  logic                  i_branch_mispredict,
    input  logic [ROB_WIDTH-1:0]  i_branch_rob_tag
);

    // ========================================
    // LSQ Entry Structure
    // ========================================
    typedef struct packed {
        logic                  valid;          // Entry is allocated
        logic                  is_store;       // 1=Store, 0=Load
        logic [ROB_WIDTH-1:0]  rob_tag;        // ROB tag for ordering

        // Address Information
        logic                  addr_valid;     // Address has been calculated
        logic [31:0]           address;        // Effective memory address (full 32-bit)
        logic [1:0]            byte_offset;    // Byte offset within word

        // Data Information (for stores)
        logic                  data_valid;     // Store data is ready
        logic [31:0]           store_data;     // Data to store

        // Operation Information
        logic [2:0]            mem_op;         // Memory operation (funct3)

        // Writeback Information (for loads)
        logic [PREG_WIDTH-1:0] prd;            // Physical destination register

        // Execution State
        logic                  issued;         // Load has been issued to memory
        logic                  completed;      // Load data has been received / forwarded
    } lsq_entry_t;

    // ========================================
    // LSQ Entry Array
    // ========================================
    lsq_entry_t lsq_entries [0:LSQ_SIZE-1];

    // ========================================
    // Allocation Logic (Priority Encoder)
    // ========================================
    logic [3:0] alloc_idx;
    logic       found_free;

    always_comb begin
        alloc_idx = 0;
        found_free = 0;
        for (int i = 0; i < LSQ_SIZE; i++) begin
            if (!lsq_entries[i].valid) begin
                alloc_idx = i[3:0];
                found_free = 1;
                break;
            end
        end
    end

    assign o_full = !found_free;
    assign o_alloc_index = alloc_idx;

    // ========================================
    // ROB Tag Age Comparison Helper Function
    // ========================================
    function automatic logic is_older(logic [ROB_WIDTH-1:0] tag_a, logic [ROB_WIDTH-1:0] tag_b);
        // Returns 1 if tag_a is older than tag_b in circular ROB
        logic [ROB_WIDTH:0] diff;
        diff = (tag_b - tag_a) & ((1 << ROB_WIDTH) - 1);
        return (diff > 0 && diff < (1 << (ROB_WIDTH-1)));
    endfunction

    // ========================================
    // Dependency Checking and Forwarding Logic
    // ========================================
    logic [3:0]  dep_check_lsq_idx;
    logic        dep_has_dependency;
    logic        dep_can_forward;
    logic [3:0]  dep_forward_from_idx;
    logic [31:0] dep_forwarded_data;

    always_comb begin
        dep_has_dependency = 0;
        dep_can_forward = 0;
        dep_forward_from_idx = 0;
        dep_forwarded_data = 32'b0;

        if (i_issue_valid && !lsq_entries[i_issue_lsq_index].is_store) begin
            // This is a load being issued
            logic [ROB_WIDTH-1:0] load_rob_tag;
            logic [31:0] load_addr;

            load_rob_tag = lsq_entries[i_issue_lsq_index].rob_tag;
            load_addr = i_base_addr + i_offset;

            // Check all LSQ entries for older stores
            for (int i = 0; i < LSQ_SIZE; i++) begin
                if (lsq_entries[i].valid && lsq_entries[i].is_store) begin
                    if (is_older(lsq_entries[i].rob_tag, load_rob_tag)) begin
                        // This store is older than the load

                        if (!lsq_entries[i].addr_valid) begin
                            // Store address unknown - MUST WAIT
                            dep_has_dependency = 1;
                            dep_can_forward = 0;
                            break;
                        end
                        else if (lsq_entries[i].address[31:2] == load_addr[31:2]) begin
                            // Address conflict detected (word-level match)
                            if (lsq_entries[i].data_valid) begin
                                // Store data ready - CAN FORWARD
                                dep_can_forward = 1;
                                dep_forward_from_idx = i[3:0];
                                // Note: actual data extraction happens in forwarding logic below
                            end
                            else begin
                                // Store data not ready - MUST WAIT
                                dep_has_dependency = 1;
                                dep_can_forward = 0;
                                break;
                            end
                        end
                        // Different addresses - no conflict, continue checking
                    end
                end
            end
        end
    end

    // ========================================
    // Store-to-Load Forwarding Data Extraction
    // ========================================
    logic [31:0] forwarded_data_formatted;

    always_comb begin
        logic [31:0] load_effective_addr;
        logic [1:0]  load_byte_offset;

        forwarded_data_formatted = 32'b0;
        load_effective_addr = i_base_addr + i_offset;
        load_byte_offset = load_effective_addr[1:0];

        if (dep_can_forward) begin
            logic [31:0] store_data;
            logic [2:0]  load_mem_op;
            logic [7:0]  byte_data;
            logic [15:0] half_data;

            store_data = lsq_entries[dep_forward_from_idx].store_data;
            load_mem_op = lsq_entries[i_issue_lsq_index].mem_op;

            // Extract byte or half-word from store data
            byte_data = store_data[8*load_byte_offset +: 8];
            half_data = store_data[16*load_byte_offset[1] +: 16];

            // Format based on load type
            case (load_mem_op)
                3'b000: forwarded_data_formatted = {{24{byte_data[7]}}, byte_data}; // LB (sign-extend)
                3'b001: forwarded_data_formatted = {{16{half_data[15]}}, half_data}; // LH (sign-extend)
                3'b010: forwarded_data_formatted = store_data;                        // LW
                3'b100: forwarded_data_formatted = {24'b0, byte_data};                // LBU (zero-extend)
                3'b101: forwarded_data_formatted = {16'b0, half_data};                // LHU (zero-extend)
                default: forwarded_data_formatted = store_data;
            endcase
        end
    end

    // ========================================
    // Load Issue Control
    // ========================================
    logic load_can_issue;
    logic [3:0] load_issue_candidate_idx;
    logic found_load_to_issue;

    always_comb begin
        load_can_issue = 0;
        load_issue_candidate_idx = 0;
        found_load_to_issue = 0;

        // Find oldest load that has address valid but not yet issued
        for (int i = 0; i < LSQ_SIZE; i++) begin
            if (lsq_entries[i].valid &&
                !lsq_entries[i].is_store &&
                lsq_entries[i].addr_valid &&
                !lsq_entries[i].issued &&
                !lsq_entries[i].completed) begin

                // Check dependencies for this load
                logic has_dep;
                logic can_fwd;
                has_dep = 0;
                can_fwd = 0;

                // Check all older stores
                for (int j = 0; j < LSQ_SIZE; j++) begin
                    if (lsq_entries[j].valid && lsq_entries[j].is_store) begin
                        if (is_older(lsq_entries[j].rob_tag, lsq_entries[i].rob_tag)) begin
                            if (!lsq_entries[j].addr_valid) begin
                                has_dep = 1;
                                break;
                            end
                            else if (lsq_entries[j].address[31:2] == lsq_entries[i].address[31:2]) begin
                                if (lsq_entries[j].data_valid) begin
                                    can_fwd = 1;
                                end
                                else begin
                                    has_dep = 1;
                                    break;
                                end
                            end
                        end
                    end
                end

                if (!has_dep) begin
                    // This load can issue (either forward or go to memory)
                    load_issue_candidate_idx = i[3:0];
                    found_load_to_issue = 1;
                    load_can_issue = !can_fwd; // Only issue to memory if not forwarding
                    break;
                end
            end
        end
    end

    assign o_load_issue_valid = load_can_issue && i_memory_ready;
    assign o_load_addr = lsq_entries[load_issue_candidate_idx].address;
    assign o_load_lsq_index = load_issue_candidate_idx;
    assign o_load_mem_op = lsq_entries[load_issue_candidate_idx].mem_op;
    assign o_load_byte_offset = lsq_entries[load_issue_candidate_idx].byte_offset;

    // ========================================
    // CDB Writeback Control
    // ========================================
    logic [3:0] cdb_writeback_idx;
    logic       found_cdb_writeback;

    always_comb begin
        cdb_writeback_idx = 0;
        found_cdb_writeback = 0;

        // Find first completed load that hasn't written back yet
        for (int i = 0; i < LSQ_SIZE; i++) begin
            if (lsq_entries[i].valid &&
                !lsq_entries[i].is_store &&
                lsq_entries[i].completed) begin
                cdb_writeback_idx = i[3:0];
                found_cdb_writeback = 1;
                break;
            end
        end
    end

    assign o_cdb_valid = found_cdb_writeback;
    assign o_cdb_prd = lsq_entries[cdb_writeback_idx].prd;
    assign o_cdb_rob_tag = lsq_entries[cdb_writeback_idx].rob_tag;
    assign o_cdb_data = lsq_entries[cdb_writeback_idx].store_data; // Reuse store_data field for load results

    // ========================================
    // Store Commit Control
    // ========================================
    logic [3:0] store_commit_idx;
    logic       found_store_to_commit;

    always_comb begin
        store_commit_idx = 0;
        found_store_to_commit = 0;

        if (i_commit_valid && i_commit_is_store) begin
            // Find LSQ entry with matching ROB tag
            for (int i = 0; i < LSQ_SIZE; i++) begin
                if (lsq_entries[i].valid &&
                    lsq_entries[i].rob_tag == i_commit_rob_tag) begin
                    store_commit_idx = i[3:0];
                    found_store_to_commit = 1;
                    break;
                end
            end
        end
    end

    assign o_store_commit_valid = found_store_to_commit;
    assign o_store_commit_addr = lsq_entries[store_commit_idx].address;
    assign o_store_commit_data = lsq_entries[store_commit_idx].store_data;
    assign o_store_commit_op = lsq_entries[store_commit_idx].mem_op;
    assign o_store_commit_byte_offset = lsq_entries[store_commit_idx].byte_offset;

    // ========================================
    // Sequential Logic
    // ========================================
    always_ff @(posedge clk) begin
        if (reset) begin
            // Reset all LSQ entries
            for (int i = 0; i < LSQ_SIZE; i++) begin
                lsq_entries[i] <= '0;
            end
        end
        else begin
            // ========================================
            // 1. BRANCH RECOVERY - Highest Priority
            // ========================================
            if (i_branch_mispredict) begin
                for (int i = 0; i < LSQ_SIZE; i++) begin
                    if (lsq_entries[i].valid) begin
                        // Invalidate entries younger than the mispredicted branch
                        if (!is_older(lsq_entries[i].rob_tag, i_branch_rob_tag) &&
                            lsq_entries[i].rob_tag != i_branch_rob_tag) begin
                            lsq_entries[i].valid <= 0;
                        end
                    end
                end
            end
            else begin
                // ========================================
                // 2. ALLOCATION
                // ========================================
                if (i_alloc && !o_full) begin
                    lsq_entries[alloc_idx].valid <= 1'b1;
                    lsq_entries[alloc_idx].is_store <= i_is_store;
                    lsq_entries[alloc_idx].rob_tag <= i_alloc_rob_tag;
                    lsq_entries[alloc_idx].mem_op <= i_mem_op;
                    lsq_entries[alloc_idx].prd <= i_prd;
                    lsq_entries[alloc_idx].addr_valid <= 1'b0;
                    lsq_entries[alloc_idx].data_valid <= 1'b0;
                    lsq_entries[alloc_idx].issued <= 1'b0;
                    lsq_entries[alloc_idx].completed <= 1'b0;
                    lsq_entries[alloc_idx].address <= 32'b0;
                    lsq_entries[alloc_idx].byte_offset <= 2'b0;
                    lsq_entries[alloc_idx].store_data <= 32'b0;
                end

                // ========================================
                // 3. ADDRESS CALCULATION & ISSUE FROM RS
                // ========================================
                if (i_issue_valid) begin
                    logic [31:0] effective_addr;
                    effective_addr = i_base_addr + i_offset;

                    lsq_entries[i_issue_lsq_index].addr_valid <= 1'b1;
                    lsq_entries[i_issue_lsq_index].address <= effective_addr;
                    lsq_entries[i_issue_lsq_index].byte_offset <= effective_addr[1:0];

                    // For stores, also capture store data
                    if (lsq_entries[i_issue_lsq_index].is_store) begin
                        lsq_entries[i_issue_lsq_index].store_data <= i_store_data;
                        lsq_entries[i_issue_lsq_index].data_valid <= 1'b1;
                    end

                    // For loads, check if we can forward immediately
                    if (!lsq_entries[i_issue_lsq_index].is_store && dep_can_forward) begin
                        // Forward data immediately
                        lsq_entries[i_issue_lsq_index].store_data <= forwarded_data_formatted;
                        lsq_entries[i_issue_lsq_index].completed <= 1'b1;
                        lsq_entries[i_issue_lsq_index].issued <= 1'b1; // Mark as issued (even though forwarded)
                    end
                end

                // ========================================
                // 4. LOAD ISSUE TO MEMORY
                // ========================================
                if (o_load_issue_valid) begin
                    lsq_entries[load_issue_candidate_idx].issued <= 1'b1;
                end

                // ========================================
                // 5. LOAD COMPLETION FROM MEMORY
                // ========================================
                if (i_load_complete_valid) begin
                    lsq_entries[i_load_complete_lsq_index].completed <= 1'b1;
                    lsq_entries[i_load_complete_lsq_index].store_data <= i_load_data;
                end

                // ========================================
                // 6. CDB WRITEBACK (Free load entries)
                // ========================================
                if (o_cdb_valid) begin
                    lsq_entries[cdb_writeback_idx].valid <= 1'b0;
                end

                // ========================================
                // 7. STORE COMMIT (Free store entries)
                // ========================================
                if (o_store_commit_valid) begin
                    lsq_entries[store_commit_idx].valid <= 1'b0;
                end
            end
        end
    end

endmodule
