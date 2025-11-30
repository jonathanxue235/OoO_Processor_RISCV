`timescale 1ns / 1ps

module rename #(
    parameter AREG_WIDTH = 5,
    parameter PREG_WIDTH = 7,
    parameter ROB_WIDTH = 4
) (
    input logic clk,
    input logic reset,

    // ------------------------------------
    // Interface from Decode Stage
    // ------------------------------------
    input logic decode_valid,
    input logic [AREG_WIDTH-1:0] decode_rs1,
    input logic [AREG_WIDTH-1:0] decode_rs2,
    input logic [AREG_WIDTH-1:0] decode_rd,
    input logic decode_is_branch,
    input logic decode_reg_write,
    // (Pass-through signals like immediate, opcode, etc. would go here)
    
    // ------------------------------------
    // Interface to Dispatch / Issue
    // ------------------------------------
    output logic dispatch_valid,
    output logic [PREG_WIDTH-1:0] dispatch_prs1, // Phys Source 1
    output logic [PREG_WIDTH-1:0] dispatch_prs2, // Phys Source 2
    output logic [PREG_WIDTH-1:0] dispatch_prd,  // Phys Dest (New)
    output logic [PREG_WIDTH-1:0] dispatch_old_prd, // Old Phys Dest (For ROB)
    output logic [ROB_WIDTH-1:0] dispatch_rob_tag,
    
    // Stall Signal (Backpressure to Decode)
    output logic rename_ready,

    // ------------------------------------
    // Interface from ROB (Commit)
    // ------------------------------------
    input logic commit_en,
    input logic [PREG_WIDTH-1:0] commit_old_preg, // Register to free

    // ------------------------------------
    // Branch Recovery
    // ------------------------------------
    input logic branch_mispredict
);

    // Internal Signals
    logic free_list_valid;
    logic [PREG_WIDTH-1:0] new_preg;
    logic reg_write_en;
    
    
    // We write to a register if the instruction is valid and rd != 0
    assign reg_write_en = decode_valid && (decode_rd != 0);

    logic actual_reg_write;
    assign actual_reg_write = decode_valid && decode_reg_write && (decode_rd != 0); 

    // ------------------------------------
    // Stall Logic
    // ------------------------------------
    // We are ready if the free list has registers available.
    // If not, we must stall the decode stage.
    assign rename_ready = free_list_valid || !actual_reg_write;
    
    // Dispatch is valid if Decode is valid AND we aren't stalling
    assign dispatch_valid = decode_valid && free_list_valid && !branch_mispredict;

    // ------------------------------------
    // Submodules
    // ------------------------------------

    free_list #(
        .PREG_WIDTH(PREG_WIDTH)
    ) u_free_list (
        .clk(clk),
        .reset(reset),
        .alloc_req(dispatch_valid && reg_write_en),
        .alloc_preg(new_preg),
        .alloc_valid(free_list_valid && actual_reg_write),
        .commit_en(commit_en),
        .commit_old_preg(commit_old_preg),
        .is_branch_dispatch(dispatch_valid && decode_is_branch),
        .branch_mispredict(branch_mispredict)
    );

    map_table #(
        .AREG_WIDTH(AREG_WIDTH),
        .PREG_WIDTH(PREG_WIDTH)
    ) u_map_table (
        .clk(clk),
        .reset(reset),
        .rs1(decode_rs1),
        .rs2(decode_rs2),
        .rd(decode_rd),
        .reg_write(dispatch_valid && actual_reg_write),
        .new_preg(new_preg),
        .is_branch_dispatch(dispatch_valid && decode_is_branch),
        .branch_mispredict(branch_mispredict),
        .prs1(dispatch_prs1),
        .prs2(dispatch_prs2),
        .old_p_dest(dispatch_old_prd)
    );

    rob_allocator #(
        .ROB_WIDTH(ROB_WIDTH)
    ) u_rob_allocator (
        .clk(clk),
        .reset(reset),
        .alloc_req(dispatch_valid), // Allocate tag for every valid instruction
        .rob_tag(dispatch_rob_tag),
        .is_branch_dispatch(dispatch_valid && decode_is_branch),
        .branch_mispredict(branch_mispredict)
    );

    // Pass through new allocation to dispatch
    assign dispatch_prd = new_preg;

endmodule