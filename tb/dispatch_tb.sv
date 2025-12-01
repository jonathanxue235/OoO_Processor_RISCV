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
    function automatic T create_r_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [6:0] funct7);
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_i_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [11:0] imm);
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_b_type(input logic [6:0] opcode, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [12:0] imm);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction
    
    // =========================================================================
    // Verification Task
    // =========================================================================
    task verify_dispatch_routing(
        input logic [8:0] expected_pc,
        input string      instr_type, // "ALU", "BRANCH", "LSU"
        input logic [3:0] exp_rob_tag
    );
        begin
            // Wait for valid signal at the Dispatch -> RS interface
            // We monitor the specific alloc signal based on expected type to ensure routing is correct
            
            // Timeout counter
            int timeout;
            timeout = 0;
            
            // Wait loop
            while (dut.skid_to_dispatch_pc !== expected_pc || dut.skid_to_dispatch_valid !== 1'b1) begin
                @(posedge clk);
                timeout++;
                if (timeout > 100) begin
                    $error("Timeout waiting for PC %h at dispatch stage", expected_pc);
                    break;
                end
            end
            
            #1; // Allow combinational logic (Dispatch routing) to settle
            
            // Check Routing Logic
            if (instr_type == "ALU") begin
                if (dut.dispatch_alloc_alu !== 1'b1) $error("[FAIL] PC %h (ALU) did not assert dispatch_alloc_alu", expected_pc);
                if (dut.dispatch_alloc_branch !== 1'b0) $error("[FAIL] PC %h (ALU) incorrectly asserted dispatch_alloc_branch", expected_pc);
                if (dut.dispatch_alloc_lsu !== 1'b0) $error("[FAIL] PC %h (ALU) incorrectly asserted dispatch_alloc_lsu", expected_pc);
                
                // Verify Payload inside ALU RS Interface
                if (dut.rs_alu_inst.i_rob_tag !== exp_rob_tag) $error("[FAIL] PC %h ALU RS ROB Tag mismatch. Exp %d, Got %d", expected_pc, exp_rob_tag, dut.rs_alu_inst.i_rob_tag);
            end 
            else if (instr_type == "BRANCH") begin
                if (dut.dispatch_alloc_branch !== 1'b1) $error("[FAIL] PC %h (BRANCH) did not assert dispatch_alloc_branch", expected_pc);
                if (dut.dispatch_alloc_alu !== 1'b0) $error("[FAIL] PC %h (BRANCH) incorrectly asserted dispatch_alloc_alu", expected_pc);
                
                // Verify Payload inside Branch RS Interface
                if (dut.rs_branch_inst.i_rob_tag !== exp_rob_tag) $error("[FAIL] PC %h Branch RS ROB Tag mismatch. Exp %d, Got %d", expected_pc, exp_rob_tag, dut.rs_branch_inst.i_rob_tag);
            end
            else if (instr_type == "LSU") begin
                if (dut.dispatch_alloc_lsu !== 1'b1) $error("[FAIL] PC %h (LSU) did not assert dispatch_alloc_lsu", expected_pc);
                
                // Verify Payload inside LSU RS Interface
                if (dut.rs_lsu_inst.i_rob_tag !== exp_rob_tag) $error("[FAIL] PC %h LSU RS ROB Tag mismatch. Exp %d, Got %d", expected_pc, exp_rob_tag, dut.rs_lsu_inst.i_rob_tag);
            end

            // Check ROB Allocation (Should happen for ALL types)
            if (dut.dispatch_alloc_rob !== 1'b1) $error("[FAIL] PC %h did not assert dispatch_alloc_rob", expected_pc);

            $display("[PASS] Dispatch Routing Verified for %s (PC: %h) -> ROB Tag %d", instr_type, expected_pc, exp_rob_tag);
            
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

        // ---------------------------------------------------------------------
        // 1. Initialize Instruction Memory with Mixed Instructions
        // ---------------------------------------------------------------------
        #1;
        
        // PC 0: ADDI x1, x0, 10  (ALU)
        // Expected: ALU RS, ROB Tag 0
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: LW x2, 0(x1)     (LSU)
        // Expected: LSU RS, ROB Tag 1
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_i_type(7'b0000011, 5'd2, 3'b010, 5'd1, 12'd0);

        // PC 8: BEQ x1, x2, 8    (BRANCH)
        // Expected: Branch RS, ROB Tag 2
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd2, 13'd8);

        // PC 12: ADD x3, x1, x2  (ALU)
        // Expected: ALU RS, ROB Tag 3
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);

        // ---------------------------------------------------------------------
        // 2. Reset Sequence
        // ---------------------------------------------------------------------
        $display("Applying Reset...");
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline filling...");

        // ---------------------------------------------------------------------
        // 3. Verification Sequence
        // ---------------------------------------------------------------------
        
        // Check PC 0 (ALU)
        verify_dispatch_routing(9'h0, "ALU", 4'd0);

        // Check PC 4 (LSU)
        verify_dispatch_routing(9'h4, "LSU", 4'd1);

        // Check PC 8 (BRANCH)
        verify_dispatch_routing(9'h8, "BRANCH", 4'd2);

        // Check PC 12 (ALU)
        verify_dispatch_routing(9'hC, "ALU", 4'd3);

        // ---------------------------------------------------------------------
        // 4. Checking Internal RS State (Did the data stick?)
        // ---------------------------------------------------------------------
        // Wait a cycle for the last write to happen
        @(posedge clk); 
        
        // Inspect ALU RS Entry 0 (Should hold the ADDI instruction from PC 0)
        // Note: Depending on issue speed, it might have been issued already. 
        // But since we didn't hook up execution units yet, the valid bit might still be high 
        // OR it cleared immediately if issue logic is combinational and i_eu_ready=1.
        // In our current RS design, issue happens immediately if ready.
        
        $display("\n--- Final Checks ---");
        $display("ROB Head Ptr (DUT): %d", dut.rob_inst.head_ptr);
        $display("ROB Tail Count (DUT): %d", dut.rob_inst.count);
        
        if (dut.rob_inst.count !== 5'd4) 
            $error("[FAIL] ROB Count should be 4 (4 instructions dispatched). Got %d", dut.rob_inst.count);
        else
            $display("[PASS] ROB correctly tracked 4 instructions.");

        $finish;
    end

    // Safety timeout
    initial begin
        #5000;
        $display("Error: Simulation Timeout.");
        $finish;
    end

endmodule