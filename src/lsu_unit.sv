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
    
    // NEW: Store Data and Control
    input logic [DATA_WIDTH-1:0] i_store_data, // rs2
    input logic                  i_memwrite,

    input logic                  i_valid,
    
    // Writeback Metadata
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Outputs (Delayed by 2 cycles)
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

    // ------------------------------------------
    // 2. Data Memory (BRAM Model)
    // ------------------------------------------
    logic [DATA_WIDTH-1:0] dmem [0:MEM_DEPTH-1];
    logic [DATA_WIDTH-1:0] ram_out;

    // Initialize memory for testing (optional)
    initial begin
        for(int i=0; i<MEM_DEPTH; i++) dmem[i] = i*4; // Dummy data
    end

    // Synchronous Read / Write (Cycle 1 -> Cycle 2)
    always_ff @(posedge clk) begin
        // Word aligned access
        if (i_valid) begin
            if (i_memwrite) begin
                 // Store
                 dmem[memory_addr[11:2]] <= i_store_data;
            end else begin
                 // Load
                 ram_out <= dmem[memory_addr[11:2]];
            end
        end
    end

    // ------------------------------------------
    // 3. Pipeline Logic (To match 2-cycle latency)
    // ------------------------------------------
    // We need to carry the metadata (prd, rob_tag) along with the memory access
    
    // Pipeline Stage 1
    logic                  stg1_valid;
    logic [PREG_WIDTH-1:0] stg1_prd;
    logic [ROB_WIDTH-1:0]  stg1_rob_tag;

    // Pipeline Stage 2
    logic                  stg2_valid;
    logic [PREG_WIDTH-1:0] stg2_prd;
    logic [ROB_WIDTH-1:0]  stg2_rob_tag;
    logic [DATA_WIDTH-1:0] stg2_data;

    always_ff @(posedge clk) begin
        if (reset) begin
            stg1_valid <= 0;
            stg2_valid <= 0;
            stg1_prd <= '0; stg1_rob_tag <= '0;
            stg2_prd <= '0; stg2_rob_tag <= '0;
            stg2_data <= '0;
        end else begin
            // Stage 1 (Address Gen / RAM Request) -> Latch Metadata
            stg1_valid   <= i_valid;
            stg1_prd     <= i_prd;
            stg1_rob_tag <= i_rob_tag;

            // Stage 2 (RAM Output Available) -> Latch Data & Metadata
            stg2_valid   <= stg1_valid;
            stg2_prd     <= stg1_prd;
            stg2_rob_tag <= stg1_rob_tag;
            stg2_data    <= ram_out; // Capture RAM output
        end
    end

    // Output assignments
    assign o_valid   = stg2_valid;
    assign o_data    = stg2_data;
    assign o_prd     = stg2_prd;
    assign o_rob_tag = stg2_rob_tag;

endmodule