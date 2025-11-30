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
        input logic [8:0] expected_pc,  // Robustness: Wait for specific PC
        input string      instr_name,
        input logic [6:0] exp_prs1,     // Expected Phys Source 1
        input logic [6:0] exp_prs2,     // Expected Phys Source 2
        input logic [6:0] exp_prd,      // Expected Phys Dest
        input logic [6:0] exp_old_prd,  // Expected Old Phys Dest (for ROB)
        input logic [3:0] exp_rob_tag   // Expected ROB Tag
    );
        begin
            // CHANGE: Use 'dut.skid_to_rename_pc' because the rename stage doesn't output a PC; 
            // it uses the PC coming from the previous skid buffer.
            wait(dut.rename_to_skid_valid === 1'b1 && dut.rename_to_skid_pc === expected_pc);
            #1; // Allow signals to settle

            // Check Signals
            // Use 'dut.skid_to_rename_pc' for error reporting as well
            if (dut.rename_to_skid_prs1 !== exp_prs1) $error("[%s] PC%h PRS1 mismatch. Exp P%0d, Got P%0d", instr_name, dut.skid_to_rename_pc, exp_prs1, dut.rename_to_skid_prs1);
            if (dut.rename_to_skid_prs2 !== exp_prs2) $error("[%s] PC%h PRS2 mismatch. Exp P%0d, Got P%0d", instr_name, dut.skid_to_rename_pc, exp_prs2, dut.rename_to_skid_prs2);
            if (dut.rename_to_skid_prd  !== exp_prd)  $error("[%s] PC%h PRD mismatch.  Exp P%0d, Got P%0d", instr_name, dut.skid_to_rename_pc, exp_prd, dut.rename_to_skid_prd);
            if (dut.rename_to_skid_old_prd !== exp_old_prd) $error("[%s] PC%h Old PRD mismatch. Exp P%0d, Got P%0d", instr_name, dut.skid_to_rename_pc, exp_old_prd, dut.rename_to_skid_old_prd);
            if (dut.rename_to_skid_rob_tag !== exp_rob_tag) $error("[%s] PC%h ROB Tag mismatch. Exp %d, Got %d", instr_name, dut.skid_to_rename_pc, exp_rob_tag, dut.rename_to_skid_rob_tag);

            $display("[PASS] %s (PC: %h) renamed successfully: rs1(P%0d) rs2(P%0d) -> rd(P%0d) [ROB #%0d]", instr_name, dut.skid_to_rename_pc, dut.rename_to_skid_prs1, dut.rename_to_skid_prs2, dut.rename_to_skid_prd, dut.rename_to_skid_rob_tag);
            
            // Wait for clock edge to proceed to ensure we don't re-check the same PC
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
        #1;
        
        // PC 0: ADDI x1, x0, 10
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: ADD x2, x1, x0
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_r_type(7'b0110011, 5'd2, 3'b000, 5'd1, 5'd0, 7'b0000000);

        // PC 8: ADD x3, x1, x2
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);

        // PC 12: LUI x4, 0x1000
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_u_type(7'b0110111, 5'd4, 32'h00001000);
            
        // PC 16: BEQ x1, x2, 16
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd2, 13'd16);

        // 2. Reset Sequence
        $display("Applying Reset...");
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline should fill.");

        // 3. Verification Sequence
        // Note: We now pass the expected PC for synchronization.
        
        // Test 1: ADDI x1, x0, 10 (PC 0)
        verify_rename(
            .expected_pc(9'h0),
            .instr_name("ADDI x1, x0, 10"),
            .exp_prs1(7'd0), .exp_prs2(7'd0), .exp_prd(7'd32), .exp_old_prd(7'd1), .exp_rob_tag(4'd0)
        );

        // Test 2: ADD x2, x1, x0 (PC 4)
        verify_rename(
            .expected_pc(9'h4),
            .instr_name("ADD x2, x1, x0"),
            .exp_prs1(7'd32), .exp_prs2(7'd0), .exp_prd(7'd33), .exp_old_prd(7'd2), .exp_rob_tag(4'd1)
        );

        // Test 3: ADD x3, x1, x2 (PC 8)
        verify_rename(
            .expected_pc(9'h8),
            .instr_name("ADD x3, x1, x2"),
            .exp_prs1(7'd32), .exp_prs2(7'd33), .exp_prd(7'd34), .exp_old_prd(7'd3), .exp_rob_tag(4'd2)
        );

        // Test 4: LUI x4, 0x1000 (PC 12 / 0xC)
        verify_rename(
            .expected_pc(9'hC),
            .instr_name("LUI x4"),
            .exp_prs1(7'd0), .exp_prs2(7'd0), .exp_prd(7'd35), .exp_old_prd(7'd4), .exp_rob_tag(4'd3)
        );

        // Test 5: BEQ x1, x2, 16 (PC 16 / 0x10)
        verify_rename(
            .expected_pc(9'h10),
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