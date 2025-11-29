`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench for Fetch Module
// Tests sequential fetching, branching, and backpressure handling
//////////////////////////////////////////////////////////////////////////////////

module fetch_tb;

    // Parameters
    parameter CLK_PERIOD = 10;  // 10ns clock period (100MHz)
    parameter type T = logic [31:0];

    // Testbench signals
    logic clk;
    logic reset;
    logic take_branch;
    T branch_loc;
    T instr_from_cache;
    T pc_to_cache;
    T instr_to_decode;
    T pc_to_decode;
    logic ready;
    logic valid;

    // Instruction memory (simulating BRAM icache)
    logic [31:0] imem [0:511];  // 512 x 32-bit instruction memory
    logic [31:0] imem_data;

    // Test tracking
    integer test_num;
    integer errors;

    //////////////////////////////////////////////////////////////////////////
    // DUT Instantiation
    //////////////////////////////////////////////////////////////////////////
    fetch #(
        .T(T)
    ) dut (
        .clk(clk),
        .reset(reset),
        .take_branch(take_branch),
        .branch_loc(branch_loc),
        .instr_from_cache(instr_from_cache),
        .pc_to_cache(pc_to_cache),
        .instr_to_decode(instr_to_decode),
        .pc_to_decode(pc_to_decode),
        .ready(ready),
        .valid(valid)
    );

    //////////////////////////////////////////////////////////////////////////
    // Clock Generation
    //////////////////////////////////////////////////////////////////////////
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //////////////////////////////////////////////////////////////////////////
    // Instruction Memory Model (BRAM with 1-cycle latency)
    //////////////////////////////////////////////////////////////////////////
    initial begin
        // Initialize instruction memory with test program
        // NOP = 0x00000013 (ADDI x0, x0, 0)
        for (int i = 0; i < 512; i++) begin
            imem[i] = 32'h00000013;  // Default to NOP
        end

        // Load test program
        imem[0]  = 32'h00000013;  // 0x000: NOP
        imem[1]  = 32'h00100093;  // 0x004: ADDI x1, x0, 1
        imem[2]  = 32'h00200113;  // 0x008: ADDI x2, x0, 2
        imem[3]  = 32'h003081B3;  // 0x00C: ADD x3, x1, x2
        imem[4]  = 32'h40208233;  // 0x010: SUB x4, x1, x2
        imem[5]  = 32'h002092B3;  // 0x014: SLL x5, x1, x2
        imem[6]  = 32'h0020A333;  // 0x018: SLT x6, x1, x2
        imem[7]  = 32'h0020C3B3;  // 0x01C: XOR x7, x1, x2
        imem[8]  = 32'h0020D433;  // 0x020: SRL x8, x1, x2
        imem[9]  = 32'h0020E4B3;  // 0x024: OR x9, x1, x2
        imem[10] = 32'h0020F533;  // 0x028: AND x10, x1, x2
        imem[11] = 32'h00A00593;  // 0x02C: ADDI x11, x0, 10
        imem[12] = 32'hFE0006EF;  // 0x030: JAL x13, -32
        imem[13] = 32'h00C00613;  // 0x034: ADDI x12, x0, 12

        // Branch target at 0x100
        imem[64] = 32'h06400693;  // 0x100: ADDI x13, x0, 100
        imem[65] = 32'h06500713;  // 0x104: ADDI x14, x0, 101
    end

    // BRAM read logic (1 cycle latency)
    always_ff @(posedge clk) begin
        imem_data <= imem[pc_to_cache[10:2]];  // Word-aligned addressing
    end

    assign instr_from_cache = imem_data;

    //////////////////////////////////////////////////////////////////////////
    // Test Stimulus
    //////////////////////////////////////////////////////////////////////////
    initial begin
        // Initialize signals
        reset = 1;
        take_branch = 0;
        branch_loc = 0;
        ready = 1;
        test_num = 0;
        errors = 0;

        // Dump waveforms
        $dumpfile("fetch_tb.vcd");
        $dumpvars(0, fetch_tb);

        // Print header
        $display("\n");
        $display("========================================");
        $display("  Fetch Module Testbench");
        $display("========================================");
        $display("\n");

        // Release reset
        #(CLK_PERIOD * 2);
        reset = 0;
        #(CLK_PERIOD);

        //////////////////////////////////////////////////////////////////////////
        // Test 1: Sequential Fetching
        //////////////////////////////////////////////////////////////////////////
        test_num = 1;
        $display("[Test %0d] Sequential Fetching", test_num);
        ready = 1;

        // Wait for pipeline to fill (1 cycle latency)
        #(CLK_PERIOD * 2);

        // Check first few fetches
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            #1;  // Small delay for signals to settle

            if (valid) begin
                $display("  Cycle %0d: PC=0x%08h, Instr=0x%08h", i, pc_to_decode, instr_to_decode);

                // Verify PC
                if (pc_to_decode !== (i * 4)) begin
                    $display("  ERROR: Expected PC=0x%08h, got 0x%08h", i*4, pc_to_decode);
                    errors++;
                end

                // Verify instruction
                if (instr_to_decode !== imem[i]) begin
                    $display("  ERROR: Expected Instr=0x%08h, got 0x%08h", imem[i], instr_to_decode);
                    errors++;
                end
            end else begin
                $display("  ERROR: Valid should be high during sequential fetch");
                errors++;
            end
        end

        $display("  Test 1 Complete\n");

        //////////////////////////////////////////////////////////////////////////
        // Test 2: Branch Handling
        //////////////////////////////////////////////////////////////////////////
        test_num = 2;
        $display("[Test %0d] Branch Handling", test_num);

        // Trigger branch to address 0x100
        @(posedge clk);
        take_branch = 1;
        branch_loc = 32'h00000100;

        @(posedge clk);
        take_branch = 0;

        // Wait for new fetch
        #(CLK_PERIOD * 2);
        @(posedge clk);
        #1;

        // Check that PC was redirected
        if (pc_to_decode !== 32'h00000100) begin
            $display("  ERROR: Branch target PC incorrect. Expected 0x100, got 0x%08h", pc_to_decode);
            errors++;
        end else begin
            $display("  Branch successful: PC=0x%08h, Instr=0x%08h", pc_to_decode, instr_to_decode);
        end

        // Check next sequential fetch after branch
        @(posedge clk);
        #1;
        if (pc_to_decode !== 32'h00000104) begin
            $display("  ERROR: PC after branch incorrect. Expected 0x104, got 0x%08h", pc_to_decode);
            errors++;
        end else begin
            $display("  Next fetch after branch: PC=0x%08h, Instr=0x%08h", pc_to_decode, instr_to_decode);
        end

        $display("  Test 2 Complete\n");

        //////////////////////////////////////////////////////////////////////////
        // Test 3: Backpressure (Ready = 0)
        //////////////////////////////////////////////////////////////////////////
        test_num = 3;
        $display("[Test %0d] Backpressure Handling", test_num);

        // Reset to start
        reset = 1;
        #(CLK_PERIOD * 2);
        reset = 0;
        ready = 1;

        // Let a few instructions fetch
        #(CLK_PERIOD * 3);

        // Save current state
        @(posedge clk);
        #1;
        T saved_pc = pc_to_decode;
        T saved_instr = instr_to_decode;
        logic saved_valid = valid;

        $display("  Before stall: PC=0x%08h, Instr=0x%08h, Valid=%b", saved_pc, saved_instr, saved_valid);

        // Apply backpressure
        ready = 0;

        // Check that PC and instruction remain stable for 3 cycles
        for (int i = 0; i < 3; i++) begin
            @(posedge clk);
            #1;

            if (pc_to_decode !== saved_pc) begin
                $display("  ERROR: PC changed during stall. Expected 0x%08h, got 0x%08h", saved_pc, pc_to_decode);
                errors++;
            end

            if (instr_to_decode !== saved_instr) begin
                $display("  ERROR: Instruction changed during stall");
                errors++;
            end

            if (valid !== saved_valid) begin
                $display("  ERROR: Valid changed during stall");
                errors++;
            end

            $display("  Stall cycle %0d: PC=0x%08h, Instr=0x%08h, Valid=%b", i+1, pc_to_decode, instr_to_decode, valid);
        end

        // Release backpressure
        ready = 1;
        @(posedge clk);
        #1;

        // Check that PC advances
        if (pc_to_decode === saved_pc) begin
            $display("  ERROR: PC did not advance after backpressure released");
            errors++;
        end else begin
            $display("  After stall: PC=0x%08h, Instr=0x%08h", pc_to_decode, instr_to_decode);
        end

        $display("  Test 3 Complete\n");

        //////////////////////////////////////////////////////////////////////////
        // Test 4: Reset Behavior
        //////////////////////////////////////////////////////////////////////////
        test_num = 4;
        $display("[Test %0d] Reset Behavior", test_num);

        // Apply reset
        reset = 1;
        #(CLK_PERIOD * 2);
        @(posedge clk);
        #1;

        // Check that valid is low during reset
        if (valid !== 0) begin
            $display("  ERROR: Valid should be 0 during reset");
            errors++;
        end

        // Release reset
        reset = 0;
        ready = 1;

        // Wait for first fetch
        #(CLK_PERIOD * 2);
        @(posedge clk);
        #1;

        // Check that PC starts from 0
        if (pc_to_decode !== 32'h00000000) begin
            $display("  ERROR: PC should start at 0x00000000 after reset, got 0x%08h", pc_to_decode);
            errors++;
        end else begin
            $display("  Reset successful: PC=0x%08h", pc_to_decode);
        end

        $display("  Test 4 Complete\n");

        //////////////////////////////////////////////////////////////////////////
        // Test Summary
        //////////////////////////////////////////////////////////////////////////
        #(CLK_PERIOD * 5);

        $display("========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Errors: %0d", errors);

        if (errors == 0) begin
            $display("  STATUS: PASSED");
        end else begin
            $display("  STATUS: FAILED");
        end
        $display("========================================\n");

        $finish;
    end

    //////////////////////////////////////////////////////////////////////////
    // Timeout watchdog
    //////////////////////////////////////////////////////////////////////////
    initial begin
        #(CLK_PERIOD * 1000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
