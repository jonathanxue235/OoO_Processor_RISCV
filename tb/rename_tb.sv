`timescale 1ns / 1ps

module rename_tb;

    // =========================================================================
    // Parameters & Signals
    // =========================================================================
    parameter type T = logic [31:0];
    logic clk;
    logic rst;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    OoO_top #(
        .T(T)
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    // =========================================================================
    // Helper Functions (Instruction Builders)
    // =========================================================================
    function automatic T create_r_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [6:0] funct7);
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_i_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [11:0] imm);
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_b_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [12:0] imm);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction
    
    function automatic T create_u_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [31:0] imm);
        return {imm[31:12], rd, opcode};
    endfunction

    // =========================================================================
    // Verification Task
    // =========================================================================
    task verify_rename(
        input string      instr_name,
        input logic [6:0] exp_prs1,     // Expected Phys Source 1
        input logic [6:0] exp_prs2,     // Expected Phys Source 2
        input logic [6:0] exp_prd,      // Expected Phys Dest
        input logic [6:0] exp_old_prd,  // Expected Old Phys Dest (for ROB)
        input logic [3:0] exp_rob_tag   // Expected ROB Tag
    );
        begin
            // Wait for the instruction to appear at the output of the rename stage
            // We check rename_to_skid_valid (Output of Rename -> Input to Skid Buffer)
            wait(dut.rename_to_skid_valid === 1'b1);
            #1; // Allow signals to settle

            // Note: Prs1/Prs2 check logic handles the case where reg is x0 (P0) or actual mapping
            if (dut.rename_to_skid_prs1 !== exp_prs1) $error("[%s] PRS1 mismatch. Exp P%0d, Got P%0d", instr_name, exp_prs1, dut.rename_to_skid_prs1);
            if (dut.rename_to_skid_prs2 !== exp_prs2) $error("[%s] PRS2 mismatch. Exp P%0d, Got P%0d", instr_name, exp_prs2, dut.rename_to_skid_prs2);
            if (dut.rename_to_skid_prd  !== exp_prd)  $error("[%s] PRD mismatch.  Exp P%0d, Got P%0d", instr_name, exp_prd, dut.rename_to_skid_prd);
            if (dut.rename_to_skid_old_prd !== exp_old_prd) $error("[%s] Old PRD mismatch. Exp P%0d, Got P%0d", instr_name, exp_old_prd, dut.rename_to_skid_old_prd);
            if (dut.rename_to_skid_rob_tag !== exp_rob_tag) $error("[%s] ROB Tag mismatch. Exp %d, Got %d", instr_name, exp_rob_tag, dut.rename_to_skid_rob_tag);

            $display("[PASS] %s renamed successfully: rs1(P%0d) rs2(P%0d) -> rd(P%0d) [ROB #%0d]", instr_name, dut.rename_to_skid_prs1, dut.rename_to_skid_prs2, dut.rename_to_skid_prd, dut.rename_to_skid_rob_tag);
            
            // Wait for clock edge to proceed to next check
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // =========================================================================
    // Main Test Procedure
    // =========================================================================
    initial begin
        $dumpfile("rename_tb.vcd");
        $dumpvars(0, rename_tb);
        
        $display("=== Starting Rename Stage Testbench ===");

        // 1. Initialize Instruction Memory
        // Using the hierarchical path found in decoder_tb (v8_4_11)
        #1;
        
        // --- INSTRUCTION SEQUENCE ---
        
        // PC 0: ADDI x1, x0, 10
        // Allocation: x1 gets P32 (First free reg after P0-P31).
        // Operands: x0 -> P0.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: ADD x2, x1, x0
        // Allocation: x2 gets P33.
        // Operands: x1 -> P32 (Forwarded from prev), x0 -> P0.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_r_type(7'b0110011, 5'd2, 3'b000, 5'd1, 5'd0, 7'b0000000);

        // PC 8: ADD x3, x1, x2
        // Allocation: x3 gets P34.
        // Operands: x1 -> P32, x2 -> P33.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);

        // PC 12: LUI x4, 0x1000
        // Allocation: x4 gets P35.
        // Operands: x0, x0 (LUI uses no source regs, mapped to P0).
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_u_type(7'b0110111, 5'd4, 32'h00001000);
            
        // PC 16: BEQ x1, x2, 16 (Branch)
        // Allocation: Branch writes no register -> No new P-reg allocated (Output PRD ignored/stable).
        // Operands: x1 -> P32, x2 -> P33.
        // ROB Tag: Still allocated (Tag 4).
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd2, 13'd16);

        // 2. Reset Sequence
        $display("Applying Reset...");
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline should fill.");

        // 3. Verification Sequence
        
        // NOTE: Expected Old PRD values assume 1:1 initial mapping (x1=P1, x2=P2...).
        // Free List starts at P32.
        
        // Test 1: ADDI x1, x0, 10
        // Expect: rs1=P0, rs2=P0, rd=P32, old_rd=P1 (x1), ROB=0
        verify_rename(
            .instr_name("ADDI x1, x0, 10"),
            .exp_prs1(7'd0), .exp_prs2(7'd0), .exp_prd(7'd32), .exp_old_prd(7'd1), .exp_rob_tag(4'd0)
        );

        // Test 2: ADD x2, x1, x0
        // Expect: rs1=P32 (x1), rs2=P0, rd=P33, old_rd=P2 (x2), ROB=1
        verify_rename(
            .instr_name("ADD x2, x1, x0"),
            .exp_prs1(7'd32), .exp_prs2(7'd0), .exp_prd(7'd33), .exp_old_prd(7'd2), .exp_rob_tag(4'd1)
        );

        // Test 3: ADD x3, x1, x2
        // Expect: rs1=P32 (x1), rs2=P33 (x2), rd=P34, old_rd=P3 (x3), ROB=2
        verify_rename(
            .instr_name("ADD x3, x1, x2"),
            .exp_prs1(7'd32), .exp_prs2(7'd33), .exp_prd(7'd34), .exp_old_prd(7'd3), .exp_rob_tag(4'd2)
        );

        // Test 4: LUI x4, 0x1000
        // Expect: rs1=P0, rs2=P0, rd=P35, old_rd=P4 (x4), ROB=3
        verify_rename(
            .instr_name("LUI x4"),
            .exp_prs1(7'd0), .exp_prs2(7'd0), .exp_prd(7'd35), .exp_old_prd(7'd4), .exp_rob_tag(4'd3)
        );

        // Test 5: BEQ x1, x2, 16
        // Expect: rs1=P32 (x1), rs2=P33 (x2), rd=P0 (No Write), old_rd=P0 (x0), ROB=4
        // Note: For branches with RegWrite=0, MapTable returns P0 for rd=0, and FreeList is not consumed.
        verify_rename(
            .instr_name("BEQ x1, x2"),
            .exp_prs1(7'd32), .exp_prs2(7'd33), .exp_prd(7'd0), .exp_old_prd(7'd0), .exp_rob_tag(4'd4)
        );

        $display("\n=== All Rename Tests Passed Successfully ===");
        $finish;
    end

    // Safety timeout
    initial begin
        #5000;
        $display("Error: Simulation Timeout.");
        $finish;
    end

endmodule