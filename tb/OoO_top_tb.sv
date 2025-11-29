`timescale 1ns / 1ps

module OoO_top_tb;

    // =========================================================================
    // Parameters & Signals
    // =========================================================================
    parameter type T = logic [31:0];

    // Clock and Reset
    logic clk;
    logic rst;
    logic [8:0] locked_decode_pc;
    T locked_decode_instr;

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
    // Helper function to create RISC-V instructions
    // =========================================================================
    function automatic T create_r_type(
        input logic [6:0] opcode,
        input logic [4:0] rd,
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [6:0] funct7
    );
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_i_type(
        input logic [6:0] opcode,
        input logic [4:0] rd,
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [11:0] imm
    );
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_s_type(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [11:0] imm
    );
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    function automatic T create_b_type(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [12:0] imm
    );
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction

    function automatic T create_u_type(
        input logic [6:0] opcode,
        input logic [4:0] rd,
        input logic [31:0] imm
    );
        return {imm[31:12], rd, opcode};
    endfunction

    function automatic T create_j_type(
        input logic [6:0] opcode,
        input logic [4:0] rd,
        input logic [20:0] imm
    );
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction

    // =========================================================================
    // Load Instructions into Instruction Memory
    // =========================================================================
    // Note: Since we're using Xilinx BRAM (blk_mem_gen_0), we need to access
    // it through the hierarchical path for initialization
    initial begin
        // Wait a bit for memory to be instantiated
        #1;

        // ADD x1, x2, x3 (R-type: x1 = x2 + x3)
        dut.instruction_memory.memory[0] = create_r_type(
            7'b0110011,  // opcode: R-type
            5'd1,        // rd = x1
            3'b000,      // funct3 = ADD
            5'd2,        // rs1 = x2
            5'd3,        // rs2 = x3
            7'b0000000   // funct7 = ADD
        );

        // ADDI x4, x5, 100 (I-type: x4 = x5 + 100)
        dut.instruction_memory.memory[1] = create_i_type(
            7'b0010011,  // opcode: I-type ALU
            5'd4,        // rd = x4
            3'b000,      // funct3 = ADDI
            5'd5,        // rs1 = x5
            12'd100      // imm = 100
        );

        // LW x6, 8(x7) (I-type Load: x6 = MEM[x7 + 8])
        dut.instruction_memory.memory[2] = create_i_type(
            7'b0000011,  // opcode: Load
            5'd6,        // rd = x6
            3'b010,      // funct3 = LW
            5'd7,        // rs1 = x7
            12'd8        // imm = 8
        );

        // SW x8, 12(x9) (S-type: MEM[x9 + 12] = x8)
        dut.instruction_memory.memory[3] = create_s_type(
            7'b0100011,  // opcode: Store
            3'b010,      // funct3 = SW
            5'd9,        // rs1 = x9
            5'd8,        // rs2 = x8
            12'd12       // imm = 12
        );

        // BEQ x10, x11, 16 (B-type: if x10 == x11, PC += 16)
        dut.instruction_memory.memory[4] = create_b_type(
            7'b1100011,  // opcode: Branch
            3'b000,      // funct3 = BEQ
            5'd10,       // rs1 = x10
            5'd11,       // rs2 = x11
            13'd16       // imm = 16
        );

        // LUI x12, 0x12345 (U-type: x12 = 0x12345000)
        dut.instruction_memory.memory[5] = create_u_type(
            7'b0110111,  // opcode: LUI
            5'd12,       // rd = x12
            32'h12345000 // imm = 0x12345
        );

        // AUIPC x13, 0x1000 (U-type: x13 = PC + 0x1000000)
        dut.instruction_memory.memory[6] = create_u_type(
            7'b0010111,  // opcode: AUIPC
            5'd13,       // rd = x13
            32'h01000000 // imm = 0x1000
        );

        // JAL x14, 32 (J-type: x14 = PC + 4, PC += 32)
        dut.instruction_memory.memory[7] = create_j_type(
            7'b1101111,  // opcode: JAL
            5'd14,       // rd = x14
            21'd32       // imm = 32
        );

        // JALR x15, 8(x16) (I-type: x15 = PC + 4, PC = x16 + 8)
        dut.instruction_memory.memory[8] = create_i_type(
            7'b1100111,  // opcode: JALR
            5'd15,       // rd = x15
            3'b000,      // funct3 = JALR
            5'd16,       // rs1 = x16
            12'd8        // imm = 8
        );

        // SUB x17, x18, x19 (R-type: x17 = x18 - x19)
        dut.instruction_memory.memory[9] = create_r_type(
            7'b0110011,  // opcode: R-type
            5'd17,       // rd = x17
            3'b000,      // funct3 = ADD/SUB
            5'd18,       // rs1 = x18
            5'd19,       // rs2 = x19
            7'b0100000   // funct7 = SUB
        );
    end

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period (100 MHz)
    end

    // =========================================================================
    // Test Procedure
    // =========================================================================
    initial begin
        $display("=== Starting OoO_top Testbench (Fetch -> Decode) ===");
        $dumpfile("OoO_top_tb.vcd");
        $dumpvars(0, OoO_top_tb);

        // --- Test 1: Reset Behavior ---
        $display("\n[Test 1] Reset Behavior");
        rst = 1;
        repeat(3) @(posedge clk);
        #1;

        assert(dut.fetch_to_cache_pc == 0)
            else $error("Reset: PC should be 0, got %h", dut.fetch_to_cache_pc);
        assert(dut.fetch_to_skid_valid == 0)
            else $error("Reset: Fetch valid should be 0");
        assert(dut.skid_to_decode_valid == 0)
            else $error("Reset: Skid valid should be 0");
        assert(dut.decode_to_skid_valid == 0)
            else $error("Reset: Decode valid should be 0");

        $display("  ✓ Reset successful - all valid signals low, PC at 0");

        rst = 0; // Release reset

        // --- Test 2: Pipeline Filling ---
        $display("\n[Test 2] Pipeline Filling");

        // Wait for pipeline to fill (BRAM has 1 cycle latency + skid buffer)
        repeat(4) @(posedge clk);
        #1;

        assert(dut.skid_to_decode_valid == 1)
            else $error("Pipeline Fill: Skid valid should be 1");
        assert(dut.decode_to_skid_valid == 1)
            else $error("Pipeline Fill: Decode valid should be 1");

        $display("  ✓ Pipeline filled - valid signals propagated");

        // --- Test 3: Decode ADD Instruction (R-type) ---
        $display("\n[Test 3] Decode ADD x1, x2, x3 (R-type)");

        // Wait until instruction 0 reaches decode stage
        wait(dut.skid_to_decode_pc == 9'h0 && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rs1 == 5'd2)
            else $error("ADD: rs1 should be 2, got %d", dut.decode_to_skid_rs1);
        assert(dut.decode_to_skid_rs2 == 5'd3)
            else $error("ADD: rs2 should be 3, got %d", dut.decode_to_skid_rs2);
        assert(dut.decode_to_skid_rd == 5'd1)
            else $error("ADD: rd should be 1, got %d", dut.decode_to_skid_rd);
        assert(dut.decode_to_skid_ALUsrc == 1'b0)
            else $error("ADD: ALUsrc should be 0 (use rs2)");
        assert(dut.decode_to_skid_Branch == 1'b0)
            else $error("ADD: Branch should be 0");
        assert(dut.decode_to_skid_ALUOp == 2'b10)
            else $error("ADD: ALUOp should be 10, got %b", dut.decode_to_skid_ALUOp);
        assert(dut.decode_to_skid_FUtype == 2'b00)
            else $error("ADD: FUtype should be 00 (ALU), got %b", dut.decode_to_skid_FUtype);
        assert(dut.decode_to_skid_Regwrite == 1'b1)
            else $error("ADD: Regwrite should be 1");
        assert(dut.decode_to_skid_Memread == 1'b0)
            else $error("ADD: Memread should be 0");
        assert(dut.decode_to_skid_Memwrite == 1'b0)
            else $error("ADD: Memwrite should be 0");

        $display("  ✓ ADD decoded correctly: rs1=%d, rs2=%d, rd=%d, FU=ALU",
                 dut.decode_to_skid_rs1, dut.decode_to_skid_rs2, dut.decode_to_skid_rd);

        // --- Test 4: Decode ADDI Instruction (I-type ALU) ---
        $display("\n[Test 4] Decode ADDI x4, x5, 100 (I-type)");

        wait(dut.skid_to_decode_pc == 9'h4 && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rs1 == 5'd5)
            else $error("ADDI: rs1 should be 5, got %d", dut.decode_to_skid_rs1);
        assert(dut.decode_to_skid_rd == 5'd4)
            else $error("ADDI: rd should be 4, got %d", dut.decode_to_skid_rd);
        assert(dut.decode_to_skid_ALUsrc == 1'b1)
            else $error("ADDI: ALUsrc should be 1 (use immediate)");
        assert(dut.decode_to_skid_immediate == 32'd100)
            else $error("ADDI: immediate should be 100, got %d", dut.decode_to_skid_immediate);
        assert(dut.decode_to_skid_ALUOp == 2'b10)
            else $error("ADDI: ALUOp should be 10");
        assert(dut.decode_to_skid_FUtype == 2'b00)
            else $error("ADDI: FUtype should be 00 (ALU)");
        assert(dut.decode_to_skid_Regwrite == 1'b1)
            else $error("ADDI: Regwrite should be 1");

        $display("  ✓ ADDI decoded correctly: rs1=%d, rd=%d, imm=%d",
                 dut.decode_to_skid_rs1, dut.decode_to_skid_rd, dut.decode_to_skid_immediate);

        // --- Test 5: Decode LW Instruction (Load) ---
        $display("\n[Test 5] Decode LW x6, 8(x7) (Load)");

        wait(dut.skid_to_decode_pc == 9'h8 && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rs1 == 5'd7)
            else $error("LW: rs1 should be 7, got %d", dut.decode_to_skid_rs1);
        assert(dut.decode_to_skid_rd == 5'd6)
            else $error("LW: rd should be 6, got %d", dut.decode_to_skid_rd);
        assert(dut.decode_to_skid_immediate == 32'd8)
            else $error("LW: immediate should be 8, got %d", dut.decode_to_skid_immediate);
        assert(dut.decode_to_skid_ALUsrc == 1'b1)
            else $error("LW: ALUsrc should be 1");
        assert(dut.decode_to_skid_FUtype == 2'b10)
            else $error("LW: FUtype should be 10 (LSU), got %b", dut.decode_to_skid_FUtype);
        assert(dut.decode_to_skid_Memread == 1'b1)
            else $error("LW: Memread should be 1");
        assert(dut.decode_to_skid_Memwrite == 1'b0)
            else $error("LW: Memwrite should be 0");
        assert(dut.decode_to_skid_Regwrite == 1'b1)
            else $error("LW: Regwrite should be 1");

        $display("  ✓ LW decoded correctly: rs1=%d, rd=%d, imm=%d, FU=LSU, Memread=1",
                 dut.decode_to_skid_rs1, dut.decode_to_skid_rd, dut.decode_to_skid_immediate);

        // --- Test 6: Decode SW Instruction (Store) ---
        $display("\n[Test 6] Decode SW x8, 12(x9) (Store)");

        wait(dut.skid_to_decode_pc == 9'hC && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rs1 == 5'd9)
            else $error("SW: rs1 should be 9, got %d", dut.decode_to_skid_rs1);
        assert(dut.decode_to_skid_rs2 == 5'd8)
            else $error("SW: rs2 should be 8, got %d", dut.decode_to_skid_rs2);
        assert(dut.decode_to_skid_immediate == 32'd12)
            else $error("SW: immediate should be 12, got %d", dut.decode_to_skid_immediate);
        assert(dut.decode_to_skid_FUtype == 2'b10)
            else $error("SW: FUtype should be 10 (LSU)");
        assert(dut.decode_to_skid_Memread == 1'b0)
            else $error("SW: Memread should be 0");
        assert(dut.decode_to_skid_Memwrite == 1'b1)
            else $error("SW: Memwrite should be 1");
        assert(dut.decode_to_skid_Regwrite == 1'b0)
            else $error("SW: Regwrite should be 0");

        $display("  ✓ SW decoded correctly: rs1=%d, rs2=%d, imm=%d, FU=LSU, Memwrite=1",
                 dut.decode_to_skid_rs1, dut.decode_to_skid_rs2, dut.decode_to_skid_immediate);

        // --- Test 7: Decode BEQ Instruction (Branch) ---
        $display("\n[Test 7] Decode BEQ x10, x11, 16 (Branch)");

        wait(dut.skid_to_decode_pc == 9'h10 && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rs1 == 5'd10)
            else $error("BEQ: rs1 should be 10, got %d", dut.decode_to_skid_rs1);
        assert(dut.decode_to_skid_rs2 == 5'd11)
            else $error("BEQ: rs2 should be 11, got %d", dut.decode_to_skid_rs2);
        assert(dut.decode_to_skid_immediate == 32'd16)
            else $error("BEQ: immediate should be 16, got %d", $signed(dut.decode_to_skid_immediate));
        assert(dut.decode_to_skid_Branch == 1'b1)
            else $error("BEQ: Branch should be 1");
        assert(dut.decode_to_skid_FUtype == 2'b01)
            else $error("BEQ: FUtype should be 01 (Branch), got %b", dut.decode_to_skid_FUtype);
        assert(dut.decode_to_skid_Regwrite == 1'b0)
            else $error("BEQ: Regwrite should be 0");

        $display("  ✓ BEQ decoded correctly: rs1=%d, rs2=%d, imm=%d, FU=Branch",
                 dut.decode_to_skid_rs1, dut.decode_to_skid_rs2, dut.decode_to_skid_immediate);

        // --- Test 8: Decode LUI Instruction (U-type) ---
        $display("\n[Test 8] Decode LUI x12, 0x12345 (U-type)");

        wait(dut.skid_to_decode_pc == 9'h14 && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rd == 5'd12)
            else $error("LUI: rd should be 12, got %d", dut.decode_to_skid_rd);
        assert(dut.decode_to_skid_immediate == 32'h12345000)
            else $error("LUI: immediate should be 0x12345000, got %h", dut.decode_to_skid_immediate);
        assert(dut.decode_to_skid_ALUsrc == 1'b1)
            else $error("LUI: ALUsrc should be 1");
        assert(dut.decode_to_skid_Regwrite == 1'b1)
            else $error("LUI: Regwrite should be 1");

        $display("  ✓ LUI decoded correctly: rd=%d, imm=0x%h",
                 dut.decode_to_skid_rd, dut.decode_to_skid_immediate);

        // --- Test 9: Decode JAL Instruction (J-type) ---
        $display("\n[Test 9] Decode JAL x14, 32 (J-type)");

        wait(dut.skid_to_decode_pc == 9'h1C && dut.decode_to_skid_valid == 1);
        @(posedge clk);
        #1;

        assert(dut.decode_to_skid_rd == 5'd14)
            else $error("JAL: rd should be 14, got %d", dut.decode_to_skid_rd);
        assert(dut.decode_to_skid_immediate == 32'd32)
            else $error("JAL: immediate should be 32, got %d", $signed(dut.decode_to_skid_immediate));
        assert(dut.decode_to_skid_Branch == 1'b1)
            else $error("JAL: Branch should be 1");
        assert(dut.decode_to_skid_FUtype == 2'b01)
            else $error("JAL: FUtype should be 01 (Branch)");
        assert(dut.decode_to_skid_Regwrite == 1'b1)
            else $error("JAL: Regwrite should be 1");

        $display("  ✓ JAL decoded correctly: rd=%d, imm=%d, Branch=1, Regwrite=1",
                 dut.decode_to_skid_rd, dut.decode_to_skid_immediate);

        // --- Test 10: Skid Buffer Backpressure ---
        $display("\n[Test 10] Skid Buffer Backpressure Test");

        // Capture current state
        

        @(posedge clk);
        #1;
        locked_decode_pc = dut.skid_to_decode_pc;
        locked_decode_instr = dut.skid_to_decode_instr;

        // Simulate decode stage not ready (backpressure)
        force dut.decode_to_skid_ready = 1'b0;

        repeat(3) @(posedge clk);
        #1;

        // Skid buffer should hold the same data
        assert(dut.skid_to_decode_pc == locked_decode_pc)
            else $error("Backpressure: PC changed during stall (expected %h, got %h)",
                       locked_decode_pc, dut.skid_to_decode_pc);
        assert(dut.skid_to_decode_instr == locked_decode_instr)
            else $error("Backpressure: Instruction changed during stall");

        // Release backpressure
        release dut.decode_to_skid_ready;

        @(posedge clk);
        #1;

        // Pipeline should advance
        assert(dut.skid_to_decode_pc != locked_decode_pc)
            else $error("Backpressure: PC did not advance after releasing stall");

        $display("  ✓ Skid buffer correctly handled backpressure");

        // --- End Simulation ---
        $display("\n=== All Tests Completed Successfully ===");
        repeat(5) @(posedge clk);
        $finish;
    end

    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #10000; // 10 microseconds timeout
        $error("TIMEOUT: Simulation ran too long!");
        $finish;
    end

endmodule
