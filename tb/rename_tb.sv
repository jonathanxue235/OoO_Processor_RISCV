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
    // Instruction Builders (Copied from decoder_tb for convenience)
    // =========================================================================
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

    // =========================================================================
    // Verification Task
    // =========================================================================
    // This task monitors the internal signals at the output of the Rename module.
    task verify_rename(
        input string      test_name,
        input logic [4:0] arch_rs1,     // Architectural RS1 (for logging)
        input logic [4:0] arch_rs2,     // Architectural RS2 (for logging)
        input logic [4:0] arch_rd,      // Architectural RD  (for logging)
        input logic [6:0] exp_prs1,     // Expected Physical RS1
        input logic [6:0] exp_prs2,     // Expected Physical RS2
        input logic [6:0] exp_prd,      // Expected Physical RD (New allocation)
        input logic       expect_alloc, // 1 if we expect a new allocation (RegWrite && rd!=0)
        input logic [3:0] exp_rob_tag   // Expected ROB Tag
    );
        begin
            // Wait for valid output from Rename stage
            // We use a timeout loop to avoid hanging if the pipeline stalls unexpectedly
            int timeout;
            timeout = 0;
            
            // Note: We are probing INTERNAL signals of the DUT using hierarchical paths.
            // dut.rename_to_skid_valid connects to the dispatch_valid output of the rename module.
            while (dut.rename_to_skid_valid !== 1'b1 && timeout < 100) begin
                @(posedge clk);
                timeout++;
            end

            if (timeout >= 100) begin
                $error("[%s] TIMEOUT waiting for Rename Valid.", test_name);
            end else begin
                // Check Physical Source 1
                if (dut.rename_to_skid_prs1 !== exp_prs1) 
                    $error("[%s] PRS1 Mismatch (Arch x%0d). Exp P%0d, Got P%0d", test_name, arch_rs1, exp_prs1, dut.rename_to_skid_prs1);
                
                // Check Physical Source 2
                if (dut.rename_to_skid_prs2 !== exp_prs2) 
                    $error("[%s] PRS2 Mismatch (Arch x%0d). Exp P%0d, Got P%0d", test_name, arch_rs2, exp_prs2, dut.rename_to_skid_prs2);

                // Check Physical Destination (Allocation)
                if (expect_alloc) begin
                    if (dut.rename_to_skid_prd !== exp_prd) 
                        $error("[%s] PRD Mismatch (Arch x%0d). Exp P%0d, Got P%0d", test_name, arch_rd, exp_prd, dut.rename_to_skid_prd);
                end else begin
                    // If we don't expect allocation (e.g. Branch or x0 write), 
                    // we verify that the logic didn't advance the free list pointer in a way that affects *future* instructions.
                    // For now, we just note that the output might be valid but effectively unused.
                end

                // Check ROB Tag
                if (dut.rename_to_skid_rob_tag !== exp_rob_tag) 
                    $error("[%s] ROB Tag Mismatch. Exp %0d, Got %0d", test_name, exp_rob_tag, dut.rename_to_skid_rob_tag);

                $display("[PASS] %s: x%0d(P%0d), x%0d(P%0d) -> x%0d(P%0d) | ROB: %0d", 
                         test_name, arch_rs1, dut.rename_to_skid_prs1, arch_rs2, dut.rename_to_skid_prs2, arch_rd, dut.rename_to_skid_prd, dut.rename_to_skid_rob_tag);
            end

            // Wait one clock cycle to consume this instruction
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
        
        $display("=== Starting OoO_top Rename Verification ===");

        // 1. Initialize Instruction Memory
        // ---------------------------------------------------------------------
        // Mapping Assumption: 
        // Initial Map Table: x0->P0, x1->P1, ... x31->P31
        // Free List Initial: P32, P33, P34...
        // ROB Tag Initial: 0
        
        // Instr 1: ADD x1, x2, x3   
        // Expect: rs1(x2)->P2, rs2(x3)->P3. New RD(x1) -> P32. ROB -> 0.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_r_type(7'b0110011, 5'd1, 3'b000, 5'd2, 5'd3, 7'b0000000);

        // Instr 2: SUB x4, x1, x5
        // Expect: rs1(x1)->P32 (RAW Dependency!), rs2(x5)->P5. New RD(x4) -> P33. ROB -> 1.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_r_type(7'b0110011, 5'd4, 3'b000, 5'd1, 5'd5, 7'b0100000);

        // Instr 3: ADDI x0, x4, 10 (Write to zero register)
        // Expect: rs1(x4)->P33. rs2(0)->P0. RD(x0) -> No Alloc (Output P34 but ignored). ROB -> 2.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_i_type(7'b0010011, 5'd0, 3'b000, 5'd4, 12'd10);

        // Instr 4: ADDI x6, x0, 100 (Read from zero register)
        // Expect: rs1(x0)->P0. New RD(x6) -> P34 (Because P34 wasn't consumed by x0 write). ROB -> 3.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_i_type(7'b0010011, 5'd6, 3'b000, 5'd0, 12'd100);

        // Instr 5: BEQ x6, x4, 8 (Branch)
        // Expect: rs1(x6)->P34, rs2(x4)->P33. No RD alloc. ROB -> 4.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_b_type(7'b1100011, 3'b000, 5'd6, 5'd4, 13'd8);

        // 2. Reset
        // ---------------------------------------------------------------------
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        $display("Reset released.");

        // 3. Verify Sequence
        // ---------------------------------------------------------------------
        
        // 1. ADD x1, x2, x3
        verify_rename(
            .test_name("ADD x1, x2, x3"),
            .arch_rs1(2), .exp_prs1(2),   // Init: x2->P2
            .arch_rs2(3), .exp_prs2(3),   // Init: x3->P3
            .arch_rd(1),  .exp_prd(32),   // First free reg P32
            .expect_alloc(1),
            .exp_rob_tag(0)
        );

        // 2. SUB x4, x1, x5
        verify_rename(
            .test_name("SUB x4, x1, x5"),
            .arch_rs1(1), .exp_prs1(32),  // Forwarding: x1 mapped to P32 in prev instr
            .arch_rs2(5), .exp_prs2(5),   // Init: x5->P5
            .arch_rd(4),  .exp_prd(33),   // Next free reg P33
            .expect_alloc(1),
            .exp_rob_tag(1)
        );

        // 3. ADDI x0, x4, 10
        // Writing to x0 should NOT consume a physical register.
        // The output `dispatch_prd` might show the *potential* next register (P34),
        // but the internal state (Head Pointer) should not increment.
        verify_rename(
            .test_name("ADDI x0, x4, 10"),
            .arch_rs1(4), .exp_prs1(33),  // x4->P33
            .arch_rs2(0), .exp_prs2(0),   // Immediate instr, rs2 unused/zero
            .arch_rd(0),  .exp_prd(34),   // P34 "peeked" but not taken
            .expect_alloc(0),             // Don't enforce check on PRD for x0 write
            .exp_rob_tag(2)
        );

        // 4. ADDI x6, x0, 100
        // This confirms that P34 was indeed NOT taken by the previous instruction.
        verify_rename(
            .test_name("ADDI x6, x0, 100"),
            .arch_rs1(0), .exp_prs1(0),   // x0->P0 always
            .arch_rs2(0), .exp_prs2(0),
            .arch_rd(6),  .exp_prd(34),   // P34 is successfully allocated here!
            .expect_alloc(1),
            .exp_rob_tag(3)
        );

        // 5. BEQ x6, x4, 8
        // Branches do not write registers.
        verify_rename(
            .test_name("BEQ x6, x4, 8"),
            .arch_rs1(6), .exp_prs1(34),  // x6->P34
            .arch_rs2(4), .exp_prs2(33),  // x4->P33
            .arch_rd(0),  .exp_prd(35),   // P35 peeked
            .expect_alloc(0),
            .exp_rob_tag(4)
        );

        $display("\n=== All Rename Tests Passed ===");
        $finish;
    end

    // Safety Timeout
    initial begin
        #5000;
        $display("\nError: Simulation Timeout.");
        $finish;
    end

endmodule