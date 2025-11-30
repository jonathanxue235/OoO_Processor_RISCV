`timescale 1ns / 1ps

module decoder_tb;

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

    function automatic T create_u_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [31:0] imm);
        return {imm[31:12], rd, opcode};
    endfunction

    function automatic T create_j_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [20:0] imm);
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction

    // =========================================================================
    // Verification Task
    // =========================================================================
    task verify_decode(
        input logic [8:0] expected_pc,
        input string      instr_name,
        input logic [4:0] exp_rs1,
        input logic [4:0] exp_rs2,
        input logic [4:0] exp_rd,
        input T           exp_imm,
        input logic       exp_alusrc,
        input logic       exp_branch,
        input logic [1:0] exp_aluop,
        input logic [1:0] exp_futype, // 00:ALU, 01:Branch, 10:LSU
        input logic       exp_memread,
        input logic       exp_memwrite,
        input logic       exp_regwrite
    );
        begin
            // Wait for the instruction to appear at the output of the decode stage
            wait(dut.decode_to_skid_valid === 1'b1 && dut.decode_to_skid_pc === expected_pc);
            #1; // Allow signals to settle

            if (dut.decode_to_skid_rs1 !== exp_rs1) $error("[%s] PC %h: rs1 mismatch. Exp %d, Got %d", instr_name, expected_pc, exp_rs1, dut.decode_to_skid_rs1);
            if (dut.decode_to_skid_rs2 !== exp_rs2) $error("[%s] PC %h: rs2 mismatch. Exp %d, Got %d", instr_name, expected_pc, exp_rs2, dut.decode_to_skid_rs2);
            if (dut.decode_to_skid_rd  !== exp_rd)  $error("[%s] PC %h: rd mismatch. Exp %d, Got %d", instr_name, expected_pc, exp_rd, dut.decode_to_skid_rd);
            if (dut.decode_to_skid_immediate !== exp_imm) $error("[%s] PC %h: Imm mismatch. Exp %h, Got %h", instr_name, expected_pc, exp_imm, dut.decode_to_skid_immediate);
            
            if (dut.decode_to_skid_ALUsrc !== exp_alusrc) $error("[%s] PC %h: ALUsrc mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_alusrc, dut.decode_to_skid_ALUsrc);
            if (dut.decode_to_skid_Branch !== exp_branch) $error("[%s] PC %h: Branch mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_branch, dut.decode_to_skid_Branch);
            if (dut.decode_to_skid_ALUOp  !== exp_aluop)  $error("[%s] PC %h: ALUOp mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_aluop, dut.decode_to_skid_ALUOp);
            if (dut.decode_to_skid_FUtype !== exp_futype) $error("[%s] PC %h: FUtype mismatch. Exp %b, Got %b", instr_name, expected_pc, exp_futype, dut.decode_to_skid_FUtype);
            
            if (dut.decode_to_skid_Memread  !== exp_memread)  $error("[%s] PC %h: Memread mismatch", instr_name, expected_pc);
            if (dut.decode_to_skid_Memwrite !== exp_memwrite) $error("[%s] PC %h: Memwrite mismatch", instr_name, expected_pc);
            if (dut.decode_to_skid_Regwrite !== exp_regwrite) $error("[%s] PC %h: Regwrite mismatch", instr_name, expected_pc);

            $display("[PASS] %s (PC: %h) decoded successfully.", instr_name, expected_pc);
            
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
        $dumpfile("OoO_top_tb.vcd");
        $dumpvars(0, OoO_top_tb);
        
        $display("=== Starting OoO_top Testbench (Up to Decode) ===");

        // 1. Force the READY signal entering the Decoder.
        //    Since downstream logic (rename) is commented out, we must simulate it being ready.
        //    This signal connects to decoder port .i_ready()
        force dut.skid_to_decode_ready = 1'b1;

        // 2. Initialize Instruction Memory
        //    Using hierarchical path to Xilinx BRAM instance
        #1;
        // PC 0: ADD x1, x2, x3
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[0] = 
            create_r_type(7'b0110011, 5'd1, 3'b000, 5'd2, 5'd3, 7'b0000000);
        
        // PC 4: ADDI x4, x5, 100
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[1] = 
            create_i_type(7'b0010011, 5'd4, 3'b000, 5'd5, 12'd100);

        // PC 8: LW x6, 8(x7)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[2] = 
            create_i_type(7'b0000011, 5'd6, 3'b010, 5'd7, 12'd8);

        // PC 12: SW x8, 12(x9)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[3] = 
            create_s_type(7'b0100011, 3'b010, 5'd9, 5'd8, 12'd12);

        // PC 16: BEQ x10, x11, 16
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[4] = 
            create_b_type(7'b1100011, 3'b000, 5'd10, 5'd11, 13'd16);

        // PC 20: LUI x12, 0x12345
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[5] = 
            create_u_type(7'b0110111, 5'd12, 32'h12345000);

        // PC 24: AUIPC x13, 0x1000
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[6] = 
            create_u_type(7'b0010111, 5'd13, 32'h01000000);

        // PC 28: JAL x14, 32
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[7] = 
            create_j_type(7'b1101111, 5'd14, 21'd32);

        // PC 32: JALR x15, 8(x16)
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[8] = 
            create_i_type(7'b1100111, 5'd15, 3'b000, 5'd16, 12'd8);


        // 3. Reset Sequence
        $display("Applying Reset...");
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released. Pipeline should fill.");

        // 4. Verification Sequence
        // Note: Expected values derived from decoder.sv logic
        
        // ADD x1, x2, x3
        verify_decode(
            .expected_pc(9'h0), .instr_name("ADD"),
            .exp_rs1(5'd2), .exp_rs2(5'd3), .exp_rd(5'd1), .exp_imm(32'd0), 
            .exp_alusrc(0), .exp_branch(0), .exp_aluop(2'b10), .exp_futype(2'b00), // ALU
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        // ADDI x4, x5, 100
        verify_decode(
            .expected_pc(9'h4), .instr_name("ADDI"),
            .exp_rs1(5'd5), .exp_rs2(5'd0), .exp_rd(5'd4), .exp_imm(32'd100), 
            .exp_alusrc(1), .exp_branch(0), .exp_aluop(2'b10), .exp_futype(2'b00), // ALU
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        // LW x6, 8(x7)
        verify_decode(
            .expected_pc(9'h8), .instr_name("LW"),
            .exp_rs1(5'd7), .exp_rs2(5'd0), .exp_rd(5'd6), .exp_imm(32'd8), 
            .exp_alusrc(1), .exp_branch(0), .exp_aluop(2'b00), .exp_futype(2'b10), // LSU
            .exp_memread(1), .exp_memwrite(0), .exp_regwrite(1)
        );

        // SW x8, 12(x9)
        verify_decode(
            .expected_pc(9'hC), .instr_name("SW"),
            .exp_rs1(5'd9), .exp_rs2(5'd8), .exp_rd(5'd0), .exp_imm(32'd12), 
            .exp_alusrc(1), .exp_branch(0), .exp_aluop(2'b00), .exp_futype(2'b10), // LSU
            .exp_memread(0), .exp_memwrite(1), .exp_regwrite(0)
        );

        // BEQ x10, x11, 16
        verify_decode(
            .expected_pc(9'h10), .instr_name("BEQ"),
            .exp_rs1(5'd10), .exp_rs2(5'd11), .exp_rd(5'd0), .exp_imm(32'd16), 
            .exp_alusrc(0), .exp_branch(1), .exp_aluop(2'b01), .exp_futype(2'b01), // Branch
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(0)
        );

        // LUI x12, 0x12345
        verify_decode(
            .expected_pc(9'h14), .instr_name("LUI"),
            .exp_rs1(5'd0), .exp_rs2(5'd0), .exp_rd(5'd12), .exp_imm(32'h12345000), 
            .exp_alusrc(1), .exp_branch(0), .exp_aluop(2'b11), .exp_futype(2'b00), // ALU
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        // AUIPC x13, 0x1000
        verify_decode(
            .expected_pc(9'h18), .instr_name("AUIPC"),
            .exp_rs1(5'd0), .exp_rs2(5'd0), .exp_rd(5'd13), .exp_imm(32'h01000000), 
            .exp_alusrc(1), .exp_branch(0), .exp_aluop(2'b00), .exp_futype(2'b00), // ALU
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        // JAL x14, 32
        verify_decode(
            .expected_pc(9'h1C), .instr_name("JAL"),
            .exp_rs1(5'd0), .exp_rs2(5'd0), .exp_rd(5'd14), .exp_imm(32'd32), 
            .exp_alusrc(1), .exp_branch(1), .exp_aluop(2'b00), .exp_futype(2'b01), // Branch
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        // JALR x15, 8(x16)
        verify_decode(
            .expected_pc(9'h20), .instr_name("JALR"),
            .exp_rs1(5'd16), .exp_rs2(5'd0), .exp_rd(5'd15), .exp_imm(32'd8), 
            .exp_alusrc(1), .exp_branch(1), .exp_aluop(2'b00), .exp_futype(2'b01), // Branch
            .exp_memread(0), .exp_memwrite(0), .exp_regwrite(1)
        );

        $display("\n=== All Tests Passed Successfully ===");
        $finish;
    end

    // Safety timeout
    initial begin
        #5000;
        $display("Error: Simulation Timeout.");
        $finish;
    end

endmodule