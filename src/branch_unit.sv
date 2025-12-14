`timescale 1ns / 1ps

module branch_unit #(
    parameter DATA_WIDTH = 32,
    parameter ROB_WIDTH  = 4
)(
    input logic [DATA_WIDTH-1:0] i_op1,
    input logic [DATA_WIDTH-1:0] i_op2,
    input logic [DATA_WIDTH-1:0] i_pc,
    input logic [DATA_WIDTH-1:0] i_imm,
    input logic [2:0]            i_funct3, // Requires updated Decoder/RS
    input logic                  i_valid,
    input logic [ROB_WIDTH-1:0]  i_rob_tag,

    // Outputs
    output logic                  o_valid,      // Operation Complete
    output logic [ROB_WIDTH-1:0]  o_rob_tag,
    
    // Branch Specific Outputs
    output logic                  o_taken,      // Computed Outcome
    output logic [DATA_WIDTH-1:0] o_target_addr,// Computed Target
    output logic                  o_mispredict  // Misprediction Flag
);

    logic condition_met;

    // Branch Condition Logic
    always_comb begin
        case (i_funct3)
            3'b000: condition_met = (i_op1 == i_op2);                   // BEQ
            3'b001: condition_met = (i_op1 != i_op2);                   // BNE
            3'b100: condition_met = ($signed(i_op1) < $signed(i_op2));  // BLT
            3'b101: condition_met = ($signed(i_op1) >= $signed(i_op2)); // BGE
            3'b110: condition_met = (i_op1 < i_op2);                    // BLTU
            3'b111: condition_met = (i_op1 >= i_op2);                   // BGEU
            default: condition_met = 1'b0;
        endcase
    end

    // Compute Outputs
    assign o_taken       = condition_met;
    assign o_target_addr = i_pc + i_imm;
    
    // Misprediction Logic (Simplified for Phase 3)
    // In a real OoO, we compare 'o_taken' against the prediction made at fetch.
    // For now, assume static Not-Taken. If taken, it's a mispredict.
    assign o_mispredict  = i_valid && condition_met; 

    assign o_valid   = i_valid;
    assign o_rob_tag = i_rob_tag;

endmodule