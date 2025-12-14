`timescale 1ns / 1ps

module branch_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4,
    parameter PREG_WIDTH = 7
)(
    input logic [DATA_WIDTH-1:0] i_op1,
    input logic [DATA_WIDTH-1:0] i_op2,
    input logic [DATA_WIDTH-1:0] i_pc,
    input logic [DATA_WIDTH-1:0] i_imm,
    input logic [3:0]            i_alu_op, // 4-bit to distinguish JAL/JALR from branches
    input logic                  i_valid,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,
    input logic [PREG_WIDTH-1:0] i_prd,

    // Outputs
    output logic                  o_valid,      // Operation Complete
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    output logic [PREG_WIDTH-1:0] o_prd,
    output logic [DATA_WIDTH-1:0] o_result,     // Result data (PC+4 for JAL/JALR)

    // Branch Specific Outputs
    output logic                  o_taken,      // Computed Outcome
    output logic [DATA_WIDTH-1:0] o_target_addr,// Computed Target
    output logic                  o_mispredict  // Misprediction Flag
);

    logic condition_met;
    logic is_jal, is_jalr;
    logic [2:0] funct3;

    // Decode ALU operation
    // JAL:  i_alu_op = 4'b1000
    // JALR: i_alu_op = 4'b1001
    // Conditional branches: i_alu_op = {1'b0, funct3}
    assign is_jal  = (i_alu_op == 4'b1000);
    assign is_jalr = (i_alu_op == 4'b1001);
    assign funct3  = i_alu_op[2:0];

    // Branch Condition Logic (for conditional branches)
    always_comb begin
        if (is_jal || is_jalr) begin
            condition_met = 1'b1; // JAL/JALR are always taken
        end else begin
            case (funct3)
                3'b000: condition_met = (i_op1 == i_op2);                   // BEQ
                3'b001: condition_met = (i_op1 != i_op2);                   // BNE
                3'b100: condition_met = ($signed(i_op1) < $signed(i_op2));  // BLT
                3'b101: condition_met = ($signed(i_op1) >= $signed(i_op2)); // BGE
                3'b110: condition_met = (i_op1 < i_op2);                    // BLTU
                3'b111: condition_met = (i_op1 >= i_op2);                   // BGEU
                default: condition_met = 1'b0;
            endcase
        end
    end

    // Target Address Computation
    logic [DATA_WIDTH-1:0] target_addr;
    always_comb begin
        if (is_jalr) begin
            // JALR: target = (rs1 + imm) & ~1
            target_addr = (i_op1 + i_imm) & ~32'b1;
        end else begin
            // JAL and conditional branches: target = PC + imm
            target_addr = i_pc + i_imm;
        end
    end

    // Compute Outputs
    assign o_taken       = condition_met;
    assign o_target_addr = target_addr;

    // Result for JAL/JALR: PC + 4 (link address)
    assign o_result = i_pc + 32'd4;

    // Misprediction Logic (Simplified for Phase 3)
    // In a real OoO, we compare 'o_taken' against the prediction made at fetch.
    // For now, assume static Not-Taken. If taken, it's a mispredict.
    // JAL/JALR are unconditional jumps and should NOT cause mispredicts in this model
    // since they are always correctly predicted as taken.
    assign o_mispredict  = i_valid && condition_met && !is_jal && !is_jalr;

    assign o_valid   = i_valid;
    assign o_rob_tag = i_rob_tag;
    assign o_prd     = i_prd;

endmodule