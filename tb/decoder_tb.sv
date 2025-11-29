`timescale 1ns / 1ps

module decoder_tb;

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    parameter type T = logic [31:0];

    // Inputs
    T instruction;
    logic [8:0] i_pc;
    logic i_valid;
    logic i_ready;

    // Outputs
    logic o_ready;
    logic [8:0] o_pc;
    logic o_valid;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic ALUsrc;
    logic Branch;
    T immediate;
    logic [1:0] ALUOp;
    logic [1:0] FUtype;
    logic Memread;
    logic Memwrite;
    logic Regwrite;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    decoder #(
        .T(T)
    ) dut (
        .instruction(instruction),
        .i_pc(i_pc),
        .i_valid(i_valid),
        .i_ready(i_ready),
        .o_ready(o_ready),
        .o_pc(o_pc),
        .o_valid(o_valid),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .ALUsrc(ALUsrc),
        .Branch(Branch),
        .immediate(immediate),
        .ALUOp(ALUOp),
        .FUtype(FUtype),
        .Memread(Memread),
        .Memwrite(Memwrite),
        .Regwrite(Regwrite)
    );

    // -------------------------------------------------------------------------
    // Test Procedure
    // -------------------------------------------------------------------------
    initial begin
        $display("=== Starting Decoder Module Testbench ===");
        $dumpfile("decoder_tb.vcd");
        $dumpvars(0, decoder_tb);

        // Initialize control signals
        i_pc = 9'h100;
        i_valid = 1'b1;
        i_ready = 1'b1;

        // --- Test 1: R-type Instruction (ADD x5, x6, x7) ---
        $display("[Test 1] R-type: ADD x5, x6, x7");
        instruction = 32'b0000000_00111_00110_000_00101_0110011;
        #10;

        assert(rs1 == 5'd6) else $error("R-type: rs1 should be 6, got %d", rs1);
        assert(rs2 == 5'd7) else $error("R-type: rs2 should be 7, got %d", rs2);
        assert(rd == 5'd5) else $error("R-type: rd should be 5, got %d", rd);
        assert(ALUsrc == 1'b0) else $error("R-type: ALUsrc should be 0");
        assert(Branch == 1'b0) else $error("R-type: Branch should be 0");
        assert(ALUOp == 2'b10) else $error("R-type: ALUOp should be 2'b10");
        assert(FUtype == 2'b00) else $error("R-type: FUtype should be 0 (ALU)");
        assert(Regwrite == 1'b1) else $error("R-type: Regwrite should be 1");
        assert(Memread == 1'b0) else $error("R-type: Memread should be 0");
        assert(Memwrite == 1'b0) else $error("R-type: Memwrite should be 0");

        // --- Test 2: I-type Instruction (ADDI x5, x6, 100) ---
        $display("[Test 2] I-type: ADDI x5, x6, 100");
        instruction = 32'b000001100100_00110_000_00101_0010011;
        #10;

        assert(rs1 == 5'd6) else $error("I-type: rs1 should be 6, got %d", rs1);
        assert(rd == 5'd5) else $error("I-type: rd should be 5, got %d", rd);
        assert(immediate == 32'd100) else $error("I-type: immediate should be 100, got %d", immediate);
        assert(ALUsrc == 1'b1) else $error("I-type: ALUsrc should be 1");
        assert(Branch == 1'b0) else $error("I-type: Branch should be 0");
        assert(ALUOp == 2'b10) else $error("I-type: ALUOp should be 2'b10");
        assert(FUtype == 2'b00) else $error("I-type: FUtype should be 0 (ALU)");
        assert(Regwrite == 1'b1) else $error("I-type: Regwrite should be 1");

        // --- Test 3: Load Instruction (LW x5, 20(x6)) ---
        $display("[Test 3] Load: LW x5, 20(x6)");
        instruction = 32'b000000010100_00110_010_00101_0000011;
        #10;

        assert(rs1 == 5'd6) else $error("Load: rs1 should be 6, got %d", rs1);
        assert(rd == 5'd5) else $error("Load: rd should be 5, got %d", rd);
        assert(immediate == 32'd20) else $error("Load: immediate should be 20, got %d", immediate);
        assert(ALUsrc == 1'b1) else $error("Load: ALUsrc should be 1");
        assert(ALUOp == 2'b00) else $error("Load: ALUOp should be 2'b00");
        assert(FUtype == 2'b10) else $error("Load: FUtype should be 2 (LSU)");
        assert(Memread == 1'b1) else $error("Load: Memread should be 1");
        assert(Regwrite == 1'b1) else $error("Load: Regwrite should be 1");
        assert(Memwrite == 1'b0) else $error("Load: Memwrite should be 0");

        // --- Test 4: Store Instruction (SW x7, 24(x6)) ---
        $display("[Test 4] Store: SW x7, 24(x6)");
        instruction = 32'b0000000_00111_00110_010_11000_0100011;
        #10;

        assert(rs1 == 5'd6) else $error("Store: rs1 should be 6, got %d", rs1);
        assert(rs2 == 5'd7) else $error("Store: rs2 should be 7, got %d", rs2);
        assert(immediate == 32'd24) else $error("Store: immediate should be 24, got %d", immediate);
        assert(ALUsrc == 1'b1) else $error("Store: ALUsrc should be 1");
        assert(ALUOp == 2'b00) else $error("Store: ALUOp should be 2'b00");
        assert(FUtype == 2'b10) else $error("Store: FUtype should be 2 (LSU)");
        assert(Memwrite == 1'b1) else $error("Store: Memwrite should be 1");
        assert(Memread == 1'b0) else $error("Store: Memread should be 0");
        assert(Regwrite == 1'b0) else $error("Store: Regwrite should be 0");

        // --- Test 5: Branch Instruction (BEQ x5, x6, 8) ---
        $display("[Test 5] Branch: BEQ x5, x6, 8");
        instruction = 32'b0000000_00110_00101_000_01000_1100011;
        #10;

        assert(rs1 == 5'd5) else $error("Branch: rs1 should be 5, got %d", rs1);
        assert(rs2 == 5'd6) else $error("Branch: rs2 should be 6, got %d", rs2);
        assert(immediate == 32'd8) else $error("Branch: immediate should be 8, got %d", immediate);
        assert(ALUsrc == 1'b0) else $error("Branch: ALUsrc should be 0");
        assert(Branch == 1'b1) else $error("Branch: Branch should be 1");
        assert(ALUOp == 2'b01) else $error("Branch: ALUOp should be 2'b01");
        assert(FUtype == 2'b01) else $error("Branch: FUtype should be 1 (Branch unit)");
        assert(Regwrite == 1'b0) else $error("Branch: Regwrite should be 0");

        // --- Test 6: LUI Instruction (LUI x5, 0x12345) ---
        $display("[Test 6] U-type: LUI x5, 0x12345");
        instruction = 32'b00010010001101000101_00101_0110111;
        #10;

        assert(rd == 5'd5) else $error("LUI: rd should be 5, got %d", rd);
        assert(immediate == 32'h12345000) else $error("LUI: immediate should be 0x12345000, got %h", immediate);
        assert(ALUsrc == 1'b1) else $error("LUI: ALUsrc should be 1");
        assert(ALUOp == 2'b11) else $error("LUI: ALUOp should be 2'b11");
        assert(FUtype == 2'b00) else $error("LUI: FUtype should be 0 (ALU)");
        assert(Regwrite == 1'b1) else $error("LUI: Regwrite should be 1");

        // --- Test 7: JAL Instruction (JAL x1, 20) ---
        $display("[Test 7] J-type: JAL x1, 20");
        instruction = 32'b0_0000000101_0_00000000_00001_1101111;
        #10;

        assert(rd == 5'd1) else $error("JAL: rd should be 1, got %d", rd);
        assert(immediate == 32'd20) else $error("JAL: immediate should be 20, got %d", immediate);
        assert(Branch == 1'b1) else $error("JAL: Branch should be 1");
        assert(FUtype == 2'b01) else $error("JAL: FUtype should be 1 (Branch unit)");
        assert(Regwrite == 1'b1) else $error("JAL: Regwrite should be 1");

        // --- Test 8: Control Signal Passthrough ---
        $display("[Test 8] Control Signal Passthrough");
        i_pc = 9'h1AA;
        i_valid = 1'b0;
        i_ready = 1'b0;
        instruction = 32'h0; // NOP
        #10;

        assert(o_pc == 9'h1AA) else $error("Passthrough: o_pc should match i_pc");
        assert(o_valid == 1'b0) else $error("Passthrough: o_valid should match i_valid");
        assert(o_ready == 1'b0) else $error("Passthrough: o_ready should match i_ready");

        i_valid = 1'b1;
        i_ready = 1'b1;
        #10;

        assert(o_valid == 1'b1) else $error("Passthrough: o_valid should be 1");
        assert(o_ready == 1'b1) else $error("Passthrough: o_ready should be 1");

        // --- Test 9: Negative Immediate (I-type with negative value) ---
        $display("[Test 9] Negative Immediate: ADDI x5, x6, -10");
        instruction = 32'b111111110110_00110_000_00101_0010011;
        #10;

        assert(immediate == 32'hFFFFFFF6) else $error("Negative immediate incorrect, got %h", immediate);

        // --- End Simulation ---
        $display("=== All Tests Completed Successfully ===");
        #10;
        $finish;
    end

endmodule
