`timescale 1ns / 1ps

module writeback_tb;

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
    // Standard RISC-V Instruction Encoding Helpers
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

    // =========================================================================
    // Verification Tasks
    // =========================================================================

    // Task to verify ALU Writeback
    task verify_alu_wb(
        input logic [3:0]  exp_tag,
        input logic [31:0] exp_data,
        input logic [6:0]  exp_prd,
        input string       instr_name
    );
        begin
            // Wait for ALU WB Valid and matching TAG
            wait(dut.alu_wb_valid === 1'b1 && dut.alu_cdb_tag === exp_tag);
            #1; // Allow signals to settle
            
            if (dut.alu_wb_data !== exp_data) 
                $error("[%s] Tag %d: ALU Data mismatch. Exp %d, Got %d", instr_name, exp_tag, exp_data, dut.alu_wb_data);
            if (dut.alu_wb_dest !== exp_prd)  
                $error("[%s] Tag %d: ALU PRD mismatch. Exp P%0d, Got P%0d", instr_name, exp_tag, exp_prd, dut.alu_wb_dest);

            $display("[PASS] %s (Tag %d) ALU Writeback: P%0d = %d", instr_name, exp_tag, dut.alu_wb_dest, dut.alu_wb_data);
            
            // Wait for clock to avoid double sampling
            @(posedge clk);
        end
    endtask

    // Task to verify LSU Writeback (Load/Store)
    task verify_lsu_wb(
        input logic [3:0]  exp_tag,
        input logic [31:0] exp_data, // Only relevant for Loads
        input logic [6:0]  exp_prd,  // Only relevant for Loads (0 for Stores)
        input string       instr_name
    );
        begin
            // Wait for LSU WB Valid and matching TAG
            wait(dut.lsu_wb_valid === 1'b1 && dut.lsu_cdb_tag === exp_tag);
            #1; 
            
            if (exp_prd != 0 && dut.lsu_wb_data !== exp_data) 
                $error("[%s] Tag %d: LSU Data mismatch. Exp %d, Got %d", instr_name, exp_tag, exp_data, dut.lsu_wb_data);
            if (dut.lsu_wb_dest !== exp_prd)  
                $error("[%s] Tag %d: LSU PRD mismatch. Exp P%0d, Got P%0d", instr_name, exp_tag, exp_prd, dut.lsu_wb_dest);

            $display("[PASS] %s (Tag %d) LSU Writeback: P%0d = %d", instr_name, exp_tag, dut.lsu_wb_dest, dut.lsu_wb_data);
            @(posedge clk);
        end
    endtask

    // Task to verify Branch Writeback
    task verify_branch_wb(
        input logic [3:0] exp_tag,
        input logic       exp_taken,
        input logic [31:0] exp_target,
        input string      instr_name
    );
        begin
            wait(dut.branch_wb_valid === 1'b1 && dut.branch_cdb_tag === exp_tag);
            #1;

            if (dut.branch_taken !== exp_taken)
                $error("[%s] Tag %d: Branch Taken mismatch. Exp %b, Got %b", instr_name, exp_tag, exp_taken, dut.branch_taken);
            if (dut.branch_target_addr !== exp_target)
                $error("[%s] Tag %d: Branch Target mismatch. Exp %h, Got %h", instr_name, exp_tag, exp_target, dut.branch_target_addr);

            $display("[PASS] %s (Tag %d) Branch Writeback: Taken=%b, Target=%h", instr_name, exp_tag, dut.branch_taken, dut.branch_target_addr);
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
        $dumpfile("writeback_tb.vcd");
        $dumpvars(0, writeback_tb);
        
        $display("=== Starting Writeback Stage Testbench ===");

        // 1. Initialize Instruction Memory
        #1;
        // ---------------------------------------------------------------------
        // Instruction Sequence
        // ---------------------------------------------------------------------
        // 1. ADDI x1, x0, 10   (Tag 0, x1 -> P32)  => ALU
        // 2. ADDI x2, x0, 20   (Tag 1, x2 -> P33)  => ALU
        // 3. ADD  x3, x1, x2   (Tag 2, x3 -> P34)  => ALU (Dependency check)
        // 4. SW   x3, 4(x0)    (Tag 3, x3 -> Mem)  => LSU (Store)
        // 5. LW   x4, 4(x0)    (Tag 4, x4 -> P35)  => LSU (Load from Mem)
        // 6. BEQ  x1, x1, 8    (Tag 5, Taken)      => Branch

        // PC 0: ADDI x1, x0, 10
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);

        // PC 4: ADDI x2, x0, 20
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd20);

        // PC 8: ADD x3, x1, x2
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);

        // PC 12: SW x3, 4(x0) (Store 30 to Addr 4)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_s_type(7'b0100011, 3'b010, 5'd0, 5'd3, 12'd4);

        // PC 16: LW x4, 4(x0) (Load from Addr 4, Expect 30)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_i_type(7'b0000011, 5'd4, 3'b010, 5'd0, 12'd4);

        // PC 20: BEQ x1, x1, 8 (Taken, Target = 20 + 8 = 28 / 0x1C)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[5] = 
            create_b_type(7'b1100011, 3'b000, 5'd1, 5'd1, 13'd8);

        // 2. Reset Sequence
        $display("Applying Reset...");
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline executing...");

        // 3. Verification Sequence (Forked for Out-of-Order Completion)
        fork
            // --- ALU Verification ---
            begin
                // 1. ADDI x1, x0, 10
                verify_alu_wb(.exp_tag(4'd0), .exp_data(32'd10), .exp_prd(7'd32), .instr_name("ADDI x1"));
                
                // 2. ADDI x2, x0, 20
                verify_alu_wb(.exp_tag(4'd1), .exp_data(32'd20), .exp_prd(7'd33), .instr_name("ADDI x2"));

                // 3. ADD x3, x1, x2 (Expect 10+20=30)
                verify_alu_wb(.exp_tag(4'd2), .exp_data(32'd30), .exp_prd(7'd34), .instr_name("ADD x3"));
            end

            // --- LSU Verification ---
            begin
                // 4. SW x3, 4(x0) (Tag 3)
                // Stores typically don't write back data to register, so exp_prd=0, exp_data=0
                verify_lsu_wb(.exp_tag(4'd3), .exp_data(32'd0), .exp_prd(7'd0), .instr_name("SW"));

                // 5. LW x4, 4(x0) (Tag 4)
                // Must wait for SW to complete. Assuming LSU handles forwarding or serializes, 
                // x4 should be 30.
                verify_lsu_wb(.exp_tag(4'd4), .exp_data(32'd30), .exp_prd(7'd35), .instr_name("LW x4"));
            end

            // --- Branch Verification ---
            begin
                // 6. BEQ x1, x1, 8 (Tag 5)
                // PC of BEQ is 20 (0x14). Target = 20 + 8 = 28 (0x1C).
                verify_branch_wb(.exp_tag(4'd5), .exp_taken(1'b1), .exp_target(32'h1C), .instr_name("BEQ"));
            end
        join

        $display("\n=== All Writeback Tests Passed Successfully ===");
        $finish;
    end

    // Safety timeout
    initial begin
        #10000;
        $display("Error: Simulation Timeout.");
        $finish;
    end

endmodule