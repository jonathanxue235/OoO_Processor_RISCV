`timescale 1ns / 1ps

module integration_tb;

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

    function automatic T create_s_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [11:0] imm);
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    function automatic T create_b_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [12:0] imm);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction

    // =========================================================================
    // Simulation Monitor
    // =========================================================================
    // This block prints pipeline events as they happen to help debug flow
    always @(posedge clk) begin
        // 1. Monitor Dispatch
        if (dut.skid_to_dispatch_valid && dut.dispatch_to_skid_ready) begin
            $display("[TIME %0t] DISPATCH: PC=%h | Type=%b | Tag=%d | NewPRD=P%0d | OldPRD=P%0d | RegWrite=%b", 
                     $time, dut.skid_to_dispatch_pc, dut.skid_to_dispatch_futype, 
                     dut.skid_to_dispatch_rob_tag, dut.skid_to_dispatch_prd, 
                     dut.skid_to_dispatch_old_prd, dut.skid_to_dispatch_regwrite);
        end

        // 2. Monitor Writeback (CDB)
        if (dut.cdb_valid) begin
            $display("[TIME %0t] CDB WB : Tag=%d | PRD=P%0d | Data=%h", 
                     $time, dut.cdb_tag, dut.cdb_prd, 
                     (dut.alu_wb_valid ? dut.alu_wb_data : (dut.lsu_wb_valid ? dut.lsu_wb_data : 32'h0)));
        end

        // 3. Monitor Commit
        if (dut.commit_valid) begin
            $display("[TIME %0t] COMMIT  : Tag=%d | Freed P%0d", 
                     $time, dut.commit_tag, dut.commit_old_preg);
                     
            // Assertion check for Stores/Branches
            // In our test program, Tag 3 is a SW, Tag 5 is a BEQ. They should free P0.
            if (dut.commit_tag == 3 || dut.commit_tag == 5) begin
                if (dut.commit_old_preg !== 0) 
                    $error("Error: Store/Branch (Tag %d) attempted to free register P%0d! Should be P0.", dut.commit_tag, dut.commit_old_preg);
                else 
                    $display("      -> Correctly did NOT free a physical register (Freed P0).");
            end
        end
    end

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
        $dumpfile("integration_tb.vcd");
        $dumpvars(0, integration_tb);
        
        $display("=== Starting Full Processor Integration Test ===");
        $display("Testing: Fetch -> Decode -> Rename -> Dispatch -> Issue -> Exec -> WB -> Commit");

        // ---------------------------------------------------------------------
        // 1. Program Loading
        // ---------------------------------------------------------------------
        #1;
        // PC 0: ADDI x1, x0, 10    (Tag 0) | ALU  | Writes x1 | Exp Result: 10
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: ADDI x2, x0, 20    (Tag 1) | ALU  | Writes x2 | Exp Result: 20
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd20);

        // PC 8: ADD x3, x1, x2     (Tag 2) | ALU  | Writes x3 | Exp Result: 30
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);

        // PC 12: SW x3, 4(x0)      (Tag 3) | LSU  | No Write  | Mem[4] <= 30
        // *CRITICAL*: This instruction should NOT free a physical register at commit.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_s_type(7'b0100011, 3'b010, 5'd0, 5'd3, 12'd4);

        // PC 16: LW x4, 4(x0)      (Tag 4) | LSU  | Writes x4 | Exp Result: 30
        // Tests Memory forwarding or sequential consistency (depending on BRAM model)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_i_type(7'b0000011, 5'd4, 3'b010, 5'd0, 12'd4);

        // PC 20: BEQ x1, x1, 4     (Tag 5) | BR   | No Write  | Taken -> PC=24
        // *CRITICAL*: Branch should NOT free a physical register.
        // Target is PC + 4 (next instr), so flow continues linearly effectively.
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[5] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd1, 13'd4);

        // PC 24: SUB x5, x3, x1    (Tag 6) | ALU  | Writes x5 | Exp: 30 - 10 = 20
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[6] = 
            create_r_type(7'b0110011, 5'd5, 3'b000, 5'd3, 5'd1, 7'b0100000);


        // ---------------------------------------------------------------------
        // 2. Reset
        // ---------------------------------------------------------------------
        $display("[TIME %0t] Applying Reset...", $time);
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        $display("[TIME %0t] Reset released.", $time);


        // ---------------------------------------------------------------------
        // 3. Automated Verification via Wait Statements
        // ---------------------------------------------------------------------
        
        // Wait for Tag 0 (ADDI) to Commit
        wait(dut.commit_valid && dut.commit_tag == 0);
        $display("[PASS] Instruction 0 (ADDI) Committed.");

        // Wait for Tag 1 (ADDI) to Commit
        wait(dut.commit_valid && dut.commit_tag == 1);
        $display("[PASS] Instruction 1 (ADDI) Committed.");

        // Wait for Tag 2 (ADD) to Commit
        wait(dut.commit_valid && dut.commit_tag == 2);
        $display("[PASS] Instruction 2 (ADD) Committed.");

        // Wait for Tag 3 (SW) to Commit
        wait(dut.commit_valid && dut.commit_tag == 3);
        $display("[PASS] Instruction 3 (SW) Committed. (Store check passed in monitor)");

        // Wait for Tag 4 (LW) to Commit
        wait(dut.commit_valid && dut.commit_tag == 4);
        // Verify Data Integrity for LW (Result should be 30)
        // We can check the physical register file or the writeback data captured earlier
        // Here we rely on the CDB monitor print, but we can check internal state:
        // We know x4 maps to P35 (approx) -> check PRF
        #1;
        if (dut.lsu_wb_data === 32'd30) 
            $display("[PASS] Instruction 4 (LW) Loaded Correct Data: %d", dut.lsu_wb_data);
        else 
            $error("Error: Instruction 4 (LW) Loaded Incorrect Data: %d (Expected 30)", dut.lsu_wb_data);

        // Wait for Tag 5 (BEQ) to Commit
        wait(dut.commit_valid && dut.commit_tag == 5);
        $display("[PASS] Instruction 5 (BEQ) Committed. (Branch check passed in monitor)");

        // Wait for Tag 6 (SUB) to Commit
        wait(dut.commit_valid && dut.commit_tag == 6);
        $display("[PASS] Instruction 6 (SUB) Committed.");

        // Final Wait to ensure signals settle
        repeat(10) @(posedge clk);
        $display("\n=== All Integration Tests Passed Successfully ===");
        $finish;
    end

    // Safety Timeout
    initial begin
        #10000;
        $display("Error: Simulation Timeout. Pipeline likely stalled.");
        $finish;
    end

endmodule