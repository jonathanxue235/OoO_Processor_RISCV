`timescale 1ns / 1ps

module alu_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4,
    parameter PREG_WIDTH = 7
)(
    // Inputs from PRF (via Issue)
    input logic [DATA_WIDTH-1:0] i_op1, 
    input logic [DATA_WIDTH-1:0] i_op2,

    // Inputs from RS Issue
    input logic [DATA_WIDTH-1:0] i_imm,
    input logic [DATA_WIDTH-1:0] i_pc,
    input logic [3:0]            i_alu_op, 
    input logic                  i_valid,
    
    // Writeback Metadata
    input logic [PREG_WIDTH-1:0] i_prd,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Outputs to CDB / PRF Write Port
    output logic [DATA_WIDTH-1:0] o_result,
    output logic [PREG_WIDTH-1:0] o_prd,
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    output logic                  o_valid
);
    logic [DATA_WIDTH-1:0] result;

    // ALU Operation Codes (You must align these with your Decoder)
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_SLL   = 4'b0010;
    localparam ALU_SLT   = 4'b0011;
    localparam ALU_XOR   = 4'b0100;
    localparam ALU_SRL   = 4'b0101;
    localparam ALU_OR    = 4'b0110;
    localparam ALU_AND   = 4'b0111;
    localparam ALU_LUI   = 4'b1000; // Pass Immediate
    localparam ALU_AUIPC = 4'b1001; // PC + Immediate
    localparam ALU_SRA   = 4'b1010; // NEW: Arithmetic Shift
    localparam ALU_SLTU  = 4'b1011; // NEW: Unsigned Set Less Than

    always_comb begin
        result = '0;
        case (i_alu_op)
            ALU_ADD:   result = i_op1 + i_op2; // Handles ADD, ADDI, Load/Store Addr Gen
            ALU_SUB:   result = i_op1 - i_op2;
            ALU_SLL:   result = i_op1 << i_op2[4:0];
            ALU_SLT:   result = ($signed(i_op1) < $signed(i_op2)) ? 32'd1 : 32'd0;
            ALU_XOR:   result = i_op1 ^ i_op2;
            ALU_SRL:   result = i_op1 >> i_op2[4:0];
            ALU_OR:    result = i_op1 | i_op2;
            ALU_AND:   result = i_op1 & i_op2;
            ALU_LUI:   result = i_imm;          // LUI: Imm is already shifted by decoder
            ALU_AUIPC: result = i_pc + i_imm;   // AUIPC
            ALU_SRA:   result = $signed(i_op1) >>> i_op2[4:0]; // SRA/SRAI: Arithmetic Shift
            ALU_SLTU:  result = (i_op1 < i_op2) ? 32'd1 : 32'd0; // SLT/SLTIU: Unsigned Comparison
            default:   result = '0;
        endcase
    end

    // Pass-through Logic (1 Cycle Latency = Combinational in this context if latched downstream, 
    // but typically we drive the CDB directly combinational from EX or reg it. 
    // Here we output combinational results to be captured by CDB/PRF).
    assign o_result  = result;
    assign o_prd     = i_prd;
    assign o_rob_tag = i_rob_tag;
    assign o_valid   = i_valid;

endmodule
