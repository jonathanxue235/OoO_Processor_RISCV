`timescale 1ns / 1ps

module dispatch_tb;

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
    // These match the helper functions used in decoder_tb and rename_tb
    function automatic T create_r_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [6:0] funct7);
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_i_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [11:0] imm);
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_s_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [11:0] imm);
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    function automatic T create_b_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [12:0] imm);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction
    
    function automatic T create_u_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [31:0] imm);
        return {imm[31:12], rd, opcode};
    endfunction

    function automatic T create_j_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [20:0] imm);
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction

    // =========================================================================
    // Verification Task
    // =========================================================================
    task verify_dispatch(
        input logic [8:0] expected_pc,
        input string      instr_name,
        // Expected Allocation Flags (from Dispatch Unit)
        input logic       exp_rob_alloc,
        input logic       exp_alu_alloc,
        input logic       exp_lsu_alloc,
        input logic       exp_branch_alloc,
        // Expected Payload (from Rename Stage)
        input logic [6:0] exp_prd,      // Expected Physical Destination Register
        input logic [3:0] exp_rob_tag   // Expected ROB Tag
    );
    begin
        // Wait for the instruction to propagate through Fetch->Decode->Rename->SkidBuffer->Dispatch
        // We probe the "skid_to_dispatch" signals which feed the Dispatch Unit and ROB/RS
        wait(dut.skid_to_dispatch_valid === 1'b1 && dut.skid_to_dispatch_pc === expected_pc);
        #1; // Allow combinational logic (allocation signals) to settle

        // Check Allocation Control Signals
        if (dut.dispatch_alloc_rob !== exp_rob_alloc)       $error("[%s] PC %h: ROB Alloc mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_rob_alloc, dut.dispatch_alloc_rob);
        if (dut.dispatch_alloc_alu !== exp_alu_alloc)       $error("[%s] PC %h: ALU Alloc mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_alu_alloc, dut.dispatch_alloc_alu);
        if (dut.dispatch_alloc_lsu !== exp_lsu_alloc)       $error("[%s] PC %h: LSU Alloc mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_lsu_alloc, dut.dispatch_alloc_lsu);
        if (dut.dispatch_alloc_branch !== exp_branch_alloc) $error("[%s] PC %h: Branch Alloc mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_branch_alloc, dut.dispatch_alloc_branch);

        // Check Renamed Payload (Sanity check that Rename data reached Dispatch)
        if (dut.skid_to_dispatch_rob_tag !== exp_rob_tag)   $error("[%s] PC %h: ROB Tag mismatch. Exp %d, Got %d", instr_name, expected_pc, exp_rob_tag, dut.skid_to_dispatch_rob_tag);
        if (dut.skid_to_dispatch_prd !== exp_prd)           $error("[%s] PC %h: PRD mismatch. Exp P%0d, Got P%0d", instr_name, expected_pc, exp_prd, dut.skid_to_dispatch_prd);

        $display("[PASS] %s (PC: %h) dispatched. Alloc: ROB=%b ALU=%b LSU=%b BR=%b. Tag=#%0d PRD=P%0d", 
                 instr_name, expected_pc, dut.dispatch_alloc_rob, dut.dispatch_alloc_alu, 
                 dut.dispatch_alloc_lsu, dut.dispatch_alloc_branch, dut.skid_to_dispatch_rob_tag, dut.skid_to_dispatch_prd);
        
        // Wait for clock edge to proceed to ensure we don't check the same cycle twice
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
        $dumpfile("dispatch_tb.vcd");
        $dumpvars(0, dispatch_tb);
        
        $display("=== Starting Dispatch Stage Testbench ===");

        // 1. Initialize Instruction Memory
        // Using direct hierarchical access to Xilinx BRAM model
        #1;
        
        // PC 0: ADDI x1, x0, 10
        // Type: ALU (I-Type). Writes x1.
        // Rename expectation: x1 -> P32 (First free reg). ROB Tag 0.
        // Dispatch expectation: Alloc ROB, Alloc ALU.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: LW x2, 8(x1)
        // Type: LSU (I-Type). Writes x2.
        // Rename expectation: x2 -> P33. ROB Tag 1.
        // Dispatch expectation: Alloc ROB, Alloc LSU.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_i_type(7'b0000011, 5'd2, 3'b010, 5'd1, 12'd8);

        // PC 8: SW x2, 12(x1)
        // Type: LSU (S-Type). Does NOT write rd.
        // Rename expectation: No new PREG (PRD=0). ROB Tag 2.
        // Dispatch expectation: Alloc ROB, Alloc LSU.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_s_type(7'b0100011, 3'b010, 5'd1, 5'd2, 12'd12);

        // PC 12: BEQ x1, x2, 16
        // Type: Branch (B-Type). Does NOT write rd.
        // Rename expectation: No new PREG (PRD=0). ROB Tag 3.
        // Dispatch expectation: Alloc ROB, Alloc Branch.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd2, 13'd16);

        // PC 16: LUI x3, 0x1000
        // Type: ALU (U-Type). Writes x3.
        // Rename expectation: x3 -> P34. ROB Tag 4.
        // Dispatch expectation: Alloc ROB, Alloc ALU.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_u_type(7'b0110111, 5'd3, 32'h00001000);

        // 2. Reset Sequence
        $display("Applying Reset...");
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline should fill.");

        // 3. Verification Sequence
        
        // Test 1: ADDI x1, x0, 10
        verify_dispatch(
            .expected_pc(9'h0), .instr_name("ADDI"),
            .exp_rob_alloc(1), .exp_alu_alloc(1), .exp_lsu_alloc(0), .exp_branch_alloc(0),
            .exp_prd(7'd32), .exp_rob_tag(4'd0)
        );

        // Test 2: LW x2, 8(x1)
        verify_dispatch(
            .expected_pc(9'h4), .instr_name("LW"),
            .exp_rob_alloc(1), .exp_alu_alloc(0), .exp_lsu_alloc(1), .exp_branch_alloc(0),
            .exp_prd(7'd33), .exp_rob_tag(4'd1)
        );

        // Test 3: SW x2, 12(x1)
        // Note: Store allocates in LSU RS but does not allocate a destination register (exp_prd = 0)
        verify_dispatch(
            .expected_pc(9'h8), .instr_name("SW"),
            .exp_rob_alloc(1), .exp_alu_alloc(0), .exp_lsu_alloc(1), .exp_branch_alloc(0),
            .exp_prd(7'd0), .exp_rob_tag(4'd2)
        );

        // Test 4: BEQ x1, x2, 16
        // Note: Branch RS allocation, no destination register
        verify_dispatch(
            .expected_pc(9'hC), .instr_name("BEQ"),
            .exp_rob_alloc(1), .exp_alu_alloc(0), .exp_lsu_alloc(0), .exp_branch_alloc(1),
            .exp_prd(7'd0), .exp_rob_tag(4'd3)
        );

        // Test 5: LUI x3, 0x1000
        verify_dispatch(
            .expected_pc(9'h10), .instr_name("LUI"),
            .exp_rob_alloc(1), .exp_alu_alloc(1), .exp_lsu_alloc(0), .exp_branch_alloc(0),
            .exp_prd(7'd34), .exp_rob_tag(4'd4)
        );

        $display("\n=== All Dispatch Tests Passed Successfully ===");
        $finish;
    end

    // Safety timeout
    initial begin
        #5000;
        $display("Error: Simulation Timeout.");
        $finish;
    end

endmodule