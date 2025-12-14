`timescale 1ns / 1ps

module branch_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4
)(
    input logic [DATA_WIDTH-1:0] i_op1,
    input logic [DATA_WIDTH-1:0] i_op2,
    input logic [DATA_WIDTH-1:0] i_pc,
    input logic [DATA_WIDTH-1:0] i_imm,
    input logic [3:0]            i_alu_op, // CHANGED: Replaced funct3 with alu_op
    input logic                  i_valid,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Outputs
    output logic                  o_valid,      
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    
    // Branch Specific Outputs
    output logic                  o_taken,      
    output logic [DATA_WIDTH-1:0] o_target_addr,
    output logic                  o_mispredict,
    output logic [DATA_WIDTH-1:0] o_result      // NEW: Link Address (PC+4)
);
    logic condition_met;
    
    // Operation Codes
    localparam ALU_JAL   = 4'b1100;
    localparam ALU_JALR  = 4'b1101;

    // Branch Condition Logic
    always_comb begin
        case (i_alu_op[2:0]) // Lower 3 bits match funct3 for branches
            3'b000: condition_met = (i_op1 == i_op2); // BEQ
            3'b001: condition_met = (i_op1 != i_op2); // BNE
            3'b100: condition_met = ($signed(i_op1) < $signed(i_op2)); // BLT
            3'b101: condition_met = ($signed(i_op1) >= $signed(i_op2)); // BGE
            3'b110: condition_met = (i_op1 < i_op2); // BLTU
            3'b111: condition_met = (i_op1 >= i_op2); // BGEU
            default: condition_met = 1'b0;
        endcase
    end

    // Compute Outputs
    always_comb begin
        if (i_alu_op == ALU_JAL) begin
            o_taken       = 1'b1;
            o_target_addr = i_pc + i_imm;
            o_mispredict  = i_valid; // Jumps always redirect if not predicted (assume static NT)
        end 
        else if (i_alu_op == ALU_JALR) begin
            o_taken       = 1'b1;
            o_target_addr = (i_op1 + i_imm) & ~32'd1;
            o_mispredict  = i_valid;
        end
        else begin // Conditional Branch
            o_taken       = condition_met;
            o_target_addr = i_pc + i_imm;
            // Static Not-Taken: Mispredict if taken
            o_mispredict  = i_valid && condition_met;
        end
    end

    // Result for JAL/JALR (Link Register)
    assign o_result  = i_pc + 32'd4; 

    assign o_valid   = i_valid;
    assign o_rob_tag = i_rob_tag;

endmodule