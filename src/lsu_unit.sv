`timescale 1ns / 1ps

module lsu_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4,
    parameter PREG_WIDTH = 7,
    parameter MEM_DEPTH  = 1024 
)(
    input logic clk,
    input logic reset,

    // Inputs
    input logic [DATA_WIDTH-1:0] i_base_addr, 
    input logic [DATA_WIDTH-1:0] i_offset,    
    input logic [DATA_WIDTH-1:0] i_store_data, 
    input logic                  i_memwrite,
    input logic                  i_valid,
    input logic                  i_stall, 
    input logic [3:0]            i_alu_op,    
    output logic                 o_ready, 
    
    // Writeback Metadata
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Recovery
    input logic branch_mispredict, 
    input logic [ROB_WIDTH-1:0] branch_rob_tag, 

    // Commit Interface
    input logic commit_valid,
    input logic [ROB_WIDTH-1:0] commit_tag,

    // Outputs
    output logic [DATA_WIDTH-1:0] o_data,
    output logic [PREG_WIDTH-1:0] o_prd,
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    output logic                  o_valid
);
    // ------------------------------------------
    // 1. Flush Helper Logic
    // ------------------------------------------
    logic incoming_is_younger;
    logic [ROB_WIDTH-1:0] diff_incoming;
    
    always_comb begin
        diff_incoming = i_rob_tag - branch_rob_tag;
        if (diff_incoming != 0 && diff_incoming < (1 << (ROB_WIDTH-1)))
            incoming_is_younger = 1'b1;
        else
            incoming_is_younger = 1'b0;
    end

    logic effective_valid;
    assign effective_valid = i_valid && !(branch_mispredict && incoming_is_younger);

    // ------------------------------------------
    // 2. Address Generation
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] memory_addr;
    assign memory_addr = i_base_addr + i_offset;
    
    logic [1:0] byte_offset;
    assign byte_offset = memory_addr[1:0];

    // ------------------------------------------
    // 3. Store Buffer
    // ------------------------------------------
    typedef struct packed {
        logic valid;
        logic [ROB_WIDTH-1:0] rob_tag;
        logic [DATA_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic [2:0] funct3;
    } sq_entry_t;

    sq_entry_t sq [0:7];
    logic sq_full;
    
    always_comb begin
        sq_full = 1'b1;
        for (int i=0; i<8; i++) begin
            if (!sq[i].valid) sq_full = 1'b0;
        end
    end

    assign o_ready = !i_stall && (!i_memwrite || !sq_full);

    // ------------------------------------------
    // 4. Data Memory & Commit Logic
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] dmem [0:MEM_DEPTH-1];
    logic [DATA_WIDTH-1:0] ram_out_raw; 

    initial begin
        for(int i=0; i<MEM_DEPTH; i++) dmem[i] = 32'b0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for(int i=0; i<8; i++) sq[i].valid <= 0;
            ram_out_raw <= 0;
        end else begin
            // A. Store Allocation
            if (effective_valid && !i_stall && i_memwrite && !sq_full) begin
                for (int i=0; i<8; i++) begin
                    if (!sq[i].valid) begin
                        sq[i] <= '{1'b1, i_rob_tag, memory_addr, i_store_data, i_alu_op[2:0]};
                        break;
                    end
                end
            end

            // B. Load Execution (Read Memory)
            if (effective_valid && !i_stall && !i_memwrite) begin
                ram_out_raw <= dmem[memory_addr[11:2]];
            end

            // C. Commit & Flush
            for (int i=0; i<8; i++) begin
                if (sq[i].valid) begin
                    logic [ROB_WIDTH-1:0] diff_sq;
                    diff_sq = sq[i].rob_tag - branch_rob_tag;
                    
                    if (branch_mispredict && diff_sq != 0 && diff_sq < (1 << (ROB_WIDTH-1))) begin
                        sq[i].valid <= 0;
                    end
                    else if (commit_valid && sq[i].rob_tag == commit_tag) begin
                        sq[i].valid <= 0;
                        case (sq[i].funct3) 
                            3'b000: dmem[sq[i].addr[11:2]][8*sq[i].addr[1:0] +: 8] <= sq[i].data[7:0];
                            3'b001: dmem[sq[i].addr[11:2]][16*sq[i].addr[1] +: 16] <= sq[i].data[15:0];
                            default: dmem[sq[i].addr[11:2]] <= sq[i].data;
                        endcase
                    end
                end
            end
        end
    end

    // ------------------------------------------
    // 5. Pipeline Logic (Loads AND Stores)
    // ------------------------------------------
    logic                  stg1_valid;
    logic [PREG_WIDTH-1:0] stg1_prd;
    logic [ROB_WIDTH-1:0]  stg1_rob_tag;
    logic [2:0]            stg1_funct3;
    logic [1:0]            stg1_offset;
    logic [DATA_WIDTH-1:0] stg1_addr; 

    logic                  stg2_valid;
    logic [PREG_WIDTH-1:0] stg2_prd;
    logic [ROB_WIDTH-1:0]  stg2_rob_tag;
    logic [2:0]            stg2_funct3;
    logic [1:0]            stg2_offset;
    logic [DATA_WIDTH-1:0] stg2_data_raw; // From RAM
    logic [DATA_WIDTH-1:0] stg2_addr;

    always_ff @(posedge clk) begin
        if (reset) begin
            stg1_valid <= 0; stg2_valid <= 0;
            stg1_prd <= '0; stg1_rob_tag <= '0;
            stg2_prd <= '0; stg2_rob_tag <= '0;
            stg2_data_raw <= '0;
        end else begin
            if (!i_stall) begin
                // CHANGED: Allow both Loads and Stores into pipeline to gen ACK
                // But only if Store buffer wasn't full (accepted)
                logic accepted;
                accepted = effective_valid && (!i_memwrite || !sq_full);

                stg1_valid   <= accepted; 
                stg1_prd     <= i_prd;
                stg1_rob_tag <= i_rob_tag;
                stg1_funct3  <= i_alu_op[2:0];
                stg1_offset  <= byte_offset;
                stg1_addr    <= memory_addr;

                stg2_valid    <= stg1_valid;
                stg2_prd      <= stg1_prd;
                stg2_rob_tag  <= stg1_rob_tag;
                stg2_funct3   <= stg1_funct3;
                stg2_offset   <= stg1_offset;
                stg2_data_raw <= ram_out_raw;
                stg2_addr     <= stg1_addr;
            end

            // Pipeline Flush
            if (branch_mispredict) begin
                logic [ROB_WIDTH-1:0] diff1, diff2;
                diff1 = stg1_rob_tag - branch_rob_tag;
                if (stg1_valid && diff1 != 0 && diff1 < (1 << (ROB_WIDTH-1))) stg1_valid <= 0;
                
                diff2 = stg2_rob_tag - branch_rob_tag;
                if (stg2_valid && diff2 != 0 && diff2 < (1 << (ROB_WIDTH-1))) stg2_valid <= 0;
            end
        end
    end

    // ------------------------------------------
    // 6. Byte-Granularity Forwarding & Output Formatting
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] final_data_selected;

    always_comb begin
        final_data_selected = stg2_data_raw; 

        // Byte-level forwarding logic
        for (int b = 0; b < 4; b++) begin
            logic [ROB_WIDTH-1:0] min_age_diff;
            min_age_diff = '1; 
            
            for (int i = 0; i < 8; i++) begin
                if (sq[i].valid) begin
                    if (sq[i].addr[31:2] == stg2_addr[31:2]) begin
                        logic writes_byte;
                        writes_byte = 0;
                        case (sq[i].funct3)
                            3'b000: writes_byte = (sq[i].addr[1:0] == b[1:0]); // SB
                            3'b001: writes_byte = (sq[i].addr[1] == b[1]);     // SH
                            default: writes_byte = 1;                          // SW
                        endcase
                        
                        if (writes_byte) begin
                            logic [ROB_WIDTH-1:0] diff;
                            diff = stg2_rob_tag - sq[i].rob_tag;
                            
                            if (diff != 0 && diff < (1 << (ROB_WIDTH-1))) begin
                                if (diff < min_age_diff) begin
                                    min_age_diff = diff;
                                    case (sq[i].funct3)
                                        3'b000: final_data_selected[8*b +: 8] = sq[i].data[7:0];
                                        3'b001: final_data_selected[8*b +: 8] = sq[i].data[8*(b%2) +: 8];
                                        default: final_data_selected[8*b +: 8] = sq[i].data[8*b +: 8];
                                    endcase
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    logic [DATA_WIDTH-1:0] formatted_data;
    always_comb begin
        logic [7:0] b;
        logic [15:0] h;
        b = final_data_selected[8*stg2_offset +: 8];
        h = final_data_selected[16*stg2_offset[1] +: 16];
        
        case (stg2_funct3)
            3'b000: formatted_data = {{24{b[7]}}, b}; // LB
            3'b001: formatted_data = {{16{h[15]}}, h}; // LH
            3'b010: formatted_data = final_data_selected; // LW
            3'b100: formatted_data = {24'b0, b}; // LBU
            3'b101: formatted_data = {16'b0, h}; // LHU
            default: formatted_data = final_data_selected;
        endcase
    end

    assign o_valid   = stg2_valid;
    assign o_data    = formatted_data;
    assign o_prd     = stg2_prd;
    assign o_rob_tag = stg2_rob_tag;

endmodule