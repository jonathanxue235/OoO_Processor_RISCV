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
    input logic [3:0]            i_alu_op, 
    input logic                  i_valid,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,
    input logic [PREG_WIDTH-1:0] i_prd,
    
    // Prediction Info (NEW)
    input logic                  i_pred_taken,
    input logic [DATA_WIDTH-1:0] i_pred_target,

    // Outputs
    output logic                  o_valid,
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    output logic [PREG_WIDTH-1:0] o_prd,
    output logic [DATA_WIDTH-1:0] o_result, // JAL/JALR Link Address

    // Branch Specific Outputs
    output logic                  o_taken,      // Actual Outcome
    output logic [DATA_WIDTH-1:0] o_target_addr,// Recovery Target
    output logic                  o_mispredict  // Misprediction Flag
);
    logic condition_met;
    logic is_jal, is_jalr;
    logic [2:0] funct3;

    assign is_jal  = (i_alu_op == 4'b1000);
    assign is_jalr = (i_alu_op == 4'b1001);
    assign funct3  = i_alu_op[2:0];

    // 1. Calculate Condition
    always_comb begin
        if (is_jal || is_jalr) begin
            condition_met = 1'b1;
        end else begin
            case (funct3)
                3'b000: condition_met = (i_op1 == i_op2); // BEQ
                3'b001: condition_met = (i_op1 != i_op2); // BNE
                3'b100: condition_met = ($signed(i_op1) < $signed(i_op2)); // BLT
                3'b101: condition_met = ($signed(i_op1) >= $signed(i_op2)); // BGE
                3'b110: condition_met = (i_op1 < i_op2); // BLTU
                3'b111: condition_met = (i_op1 >= i_op2); // BGEU
                default: condition_met = 1'b0;
            endcase
        end
    end

    // 2. Calculate Actual Target
    logic [DATA_WIDTH-1:0] calculated_target;
    always_comb begin
        if (is_jalr) calculated_target = (i_op1 + i_imm) & ~32'b1;
        else         calculated_target = i_pc + i_imm;
    end

    assign o_taken = condition_met;

    // 3. Misprediction Logic
    // Mispredict if:
    //  - Predicted Taken != Actual Taken
    //  - OR (Both Taken BUT Predicted Target != Actual Target)
    assign o_mispredict = i_valid && (
        (o_taken != i_pred_taken) || 
        (o_taken && (calculated_target != i_pred_target))
    );

    // 4. Recovery Target (The Correct Next PC)
    // If we mispredicted, where *should* we have gone?
    // If Actual Taken -> Go to calculated_target.
    // If Actual NT    -> Go to PC + 4.
    assign o_target_addr = o_taken ? calculated_target : (i_pc + 32'd4);

    // 5. Result (Link Address)
    assign o_result = i_pc + 32'd4;

    assign o_valid   = i_valid;
    assign o_rob_tag = i_rob_tag;
    assign o_prd     = i_prd;

endmodule