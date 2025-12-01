`timescale 1ns / 1ps

module dispatch (
    // Inputs from Rename (via Skid Buffer) - Control Only
    input logic i_valid,
    input logic [1:0] i_futype, // 00: ALU, 01: Branch, 10: LSU

    // Backpressure Inputs (from ROB and RSs)
    input logic rob_full,
    input logic alu_rs_full,
    input logic branch_rs_full,
    input logic lsu_rs_full,

    // Outputs
    output logic o_ready,        // Stall signal to Rename stage
    
    output logic rob_alloc,      // Allocate an entry in ROB
    output logic alu_rs_alloc,   // Allocate entry in ALU RS
    output logic branch_rs_alloc,// Allocate entry in Branch RS
    output logic lsu_rs_alloc    // Allocate entry in LSU RS
);

    // 1. Decode Target RS
    logic target_alu, target_branch, target_lsu;
    
    assign target_alu    = (i_futype == 2'b00);
    assign target_branch = (i_futype == 2'b01);
    assign target_lsu    = (i_futype == 2'b10);

    // 2. Stall Logic
    // Stall if ROB is full OR the specific RS we need is full
    logic dispatch_stall;
    assign dispatch_stall = rob_full || 
                            (target_alu && alu_rs_full) ||
                            (target_branch && branch_rs_full) ||
                            (target_lsu && lsu_rs_full);

    // Ready if not stalled
    assign o_ready = !dispatch_stall;

    // 3. Allocation Signals
    // Only allocate if input is valid AND we are not stalling
    assign rob_alloc       = i_valid && !dispatch_stall;
    assign alu_rs_alloc    = i_valid && !dispatch_stall && target_alu;
    assign branch_rs_alloc = i_valid && !dispatch_stall && target_branch;
    assign lsu_rs_alloc    = i_valid && !dispatch_stall && target_lsu;

endmodule