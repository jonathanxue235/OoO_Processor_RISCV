`timescale 1ns / 1ps

module physical_register_file #(
    parameter DATA_WIDTH = 32,
    parameter PREG_WIDTH = 7  
)(
    input logic clk,
    input logic reset,

    // READ PORTS
    input  logic [PREG_WIDTH-1:0] alu_prs1_addr,
    input  logic [PREG_WIDTH-1:0] alu_prs2_addr,
    output logic [DATA_WIDTH-1:0] alu_prs1_data,
    output logic [DATA_WIDTH-1:0] alu_prs2_data,

    input  logic [PREG_WIDTH-1:0] br_prs1_addr,
    input  logic [PREG_WIDTH-1:0] br_prs2_addr,
    output logic [DATA_WIDTH-1:0] br_prs1_data,
    output logic [DATA_WIDTH-1:0] br_prs2_data,

    input  logic [PREG_WIDTH-1:0] lsu_prs1_addr,
    input  logic [PREG_WIDTH-1:0] lsu_prs2_addr,
    output logic [DATA_WIDTH-1:0] lsu_prs1_data,
    output logic [DATA_WIDTH-1:0] lsu_prs2_data,

    // WRITE PORTS
    // ALU Writeback
    input logic alu_wb_valid,
    input logic [PREG_WIDTH-1:0] alu_wb_dest,
    input logic [DATA_WIDTH-1:0] alu_wb_data,

    // LSU Writeback
    input logic lsu_wb_valid,
    input logic [PREG_WIDTH-1:0] lsu_wb_dest,
    input logic [DATA_WIDTH-1:0] lsu_wb_data,

    // Branch Writeback (NEW: For JAL/JALR)
    input logic br_wb_valid,
    input logic [PREG_WIDTH-1:0] br_wb_dest,
    input logic [DATA_WIDTH-1:0] br_wb_data
);

    localparam NUM_PREGS = 1 << PREG_WIDTH;

    logic [DATA_WIDTH-1:0] registers [0:NUM_PREGS-1];

    // Read Logic
    assign alu_prs1_data = (alu_prs1_addr == 0) ? '0 : registers[alu_prs1_addr];
    assign alu_prs2_data = (alu_prs2_addr == 0) ? '0 : registers[alu_prs2_addr];
    assign br_prs1_data  = (br_prs1_addr == 0)  ? '0 : registers[br_prs1_addr];
    assign br_prs2_data  = (br_prs2_addr == 0)  ? '0 : registers[br_prs2_addr];
    assign lsu_prs1_data = (lsu_prs1_addr == 0) ? '0 : registers[lsu_prs1_addr];
    assign lsu_prs2_data = (lsu_prs2_addr == 0) ? '0 : registers[lsu_prs2_addr];

    // Write Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_PREGS; i++) begin
                registers[i] <= '0;
            end
        end
        else begin
            if (alu_wb_valid && alu_wb_dest != 0)
                registers[alu_wb_dest] <= alu_wb_data;

            if (lsu_wb_valid && lsu_wb_dest != 0)
                registers[lsu_wb_dest] <= lsu_wb_data;
                
            if (br_wb_valid && br_wb_dest != 0) // NEW
                registers[br_wb_dest] <= br_wb_data;
        end
    end
endmodule