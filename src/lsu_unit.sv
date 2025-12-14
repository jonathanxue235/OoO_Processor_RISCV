`timescale 1ns / 1ps

module lsu_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4,
    parameter PREG_WIDTH = 7,
    parameter MEM_DEPTH  = 1024 // Size of Data Memory
)(
    input logic clk,
    input logic reset,

    // Inputs
    input logic [DATA_WIDTH-1:0] i_base_addr, // rs1
    input logic [DATA_WIDTH-1:0] i_offset,    // immediate
    input logic [DATA_WIDTH-1:0] i_store_data, // rs2
    input logic                  i_memwrite,
    input logic                  i_valid,
    input logic                  i_stall, 
    input logic [3:0]            i_alu_op,    // Contains funct3 for size
    output logic                 o_ready, 
    
    // Writeback Metadata
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Outputs
    output logic [DATA_WIDTH-1:0] o_data,
    output logic [PREG_WIDTH-1:0] o_prd,
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    output logic                  o_valid
);
    // ------------------------------------------
    // 1. Address Generation
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] memory_addr;
    assign memory_addr = i_base_addr + i_offset;
    
    logic [1:0] byte_offset;
    assign byte_offset = memory_addr[1:0];

    // ------------------------------------------
    // 2. Data Memory (BRAM Model)
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] dmem [0:MEM_DEPTH-1];
    logic [DATA_WIDTH-1:0] ram_out_raw; 

    // Initialize memory to Zero to prevent garbage loads
    initial begin
        for(int i=0; i<MEM_DEPTH; i++) dmem[i] = 32'b0; 
    end

    // Synchronous Read / Write 
    always_ff @(posedge clk) begin
        if (i_valid && !i_stall) begin
            if (i_memwrite) begin
                // Store with granularity support
                case (i_alu_op[2:0]) // funct3
                    3'b000: // SB (Store Byte)
                        dmem[memory_addr[11:2]][8*byte_offset +: 8] <= i_store_data[7:0];
                    3'b001: // SH (Store Half)
                        dmem[memory_addr[11:2]][16*byte_offset[1] +: 16] <= i_store_data[15:0];
                    default: // SW (Store Word)
                        dmem[memory_addr[11:2]] <= i_store_data;
                endcase
            end else begin
                // Load - read full word
                ram_out_raw <= dmem[memory_addr[11:2]];
            end
        end
    end

    // ------------------------------------------
    // 3. Pipeline Logic
    // ------------------------------------------
    // Ready if not stalled
    assign o_ready = !i_stall;

    // Pipeline Registers
    logic                  stg1_valid;
    logic [PREG_WIDTH-1:0] stg1_prd;
    logic [ROB_WIDTH-1:0]  stg1_rob_tag;
    logic [2:0]            stg1_funct3;
    logic [1:0]            stg1_offset;

    logic                  stg2_valid;
    logic [PREG_WIDTH-1:0] stg2_prd;
    logic [ROB_WIDTH-1:0]  stg2_rob_tag;
    logic [2:0]            stg2_funct3;
    logic [1:0]            stg2_offset;
    logic [DATA_WIDTH-1:0] stg2_data_raw; // Latch for memory output

    always_ff @(posedge clk) begin
        if (reset) begin
            stg1_valid <= 0;
            stg2_valid <= 0;
            stg1_prd <= '0; stg1_rob_tag <= '0;
            stg2_prd <= '0; stg2_rob_tag <= '0;
            stg2_data_raw <= '0;
        end else if (!i_stall) begin
            // Stage 1: Latch Control Inputs
            stg1_valid   <= i_valid;
            stg1_prd     <= i_prd;
            stg1_rob_tag <= i_rob_tag;
            stg1_funct3  <= i_alu_op[2:0];
            stg1_offset  <= byte_offset;

            // Stage 2: Latch Stage 1 Control AND Memory Data
            stg2_valid    <= stg1_valid;
            stg2_prd      <= stg1_prd;
            stg2_rob_tag  <= stg1_rob_tag;
            stg2_funct3   <= stg1_funct3;
            stg2_offset   <= stg1_offset;
            
            // CRITICAL FIX: Capture the RAM output into the pipeline
            // ram_out_raw corresponds to the address issued in the previous cycle (stg1)
            stg2_data_raw <= ram_out_raw; 
        end
    end

    // ------------------------------------------
    // 4. Output Formatting (Load Extension)
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] formatted_data;
    
    always_comb begin
        logic [7:0] b;
        logic [15:0] h;
        
        // Use the latched data (stg2_data_raw) instead of the changing ram_out_raw
        b = stg2_data_raw[8*stg2_offset +: 8];
        h = stg2_data_raw[16*stg2_offset[1] +: 16];
        
        // Sign/Zero Extension based on funct3
        case (stg2_funct3)
            3'b000: formatted_data = {{24{b[7]}}, b}; // LB
            3'b001: formatted_data = {{16{h[15]}}, h}; // LH
            3'b010: formatted_data = stg2_data_raw;    // LW
            3'b100: formatted_data = {24'b0, b};       // LBU
            3'b101: formatted_data = {16'b0, h};       // LHU
            default: formatted_data = stg2_data_raw;
        endcase
    end

    // Output assignments
    assign o_valid   = stg2_valid;
    assign o_data    = formatted_data;
    assign o_prd     = stg2_prd;
    assign o_rob_tag = stg2_rob_tag;

endmodule
