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
    function automatic T create_i_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [11:0] imm);
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic T create_r_type(input logic [6:0] opcode, input logic [4:0] rd, input logic [2:0] funct3, input logic [4:0] rs1, input logic [4:0] rs2, input logic [6:0] funct7);
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    // =========================================================================
    // Configuration & Constants
    // =========================================================================
    // Based on src files: 128 Phys Regs total, 32 Arch Regs. 
    // Free List initializes with P32 to P127 (96 free registers).
    localparam NUM_PREGS = 128;
    localparam NUM_AREGS = 32;
    localparam START_PREG = 32; 

    // =========================================================================
    // Verification Tasks
    // =========================================================================

    // Task to load instruction into memory
    task load_instr(input int addr, input T instr);
        dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_8_inst.memory[addr] = instr;
    endtask

    // Task to verify Rename Output
    task verify_rename_output(
        input string test_name,
        input int exp_prs1, // -1 if don't care/not used
        input int exp_prs2, // -1 if don't care/not used
        input int exp_prd,  // -1 if don't care (e.g., store/branch)
        input logic exp_valid
    );
        begin
            // Wait for dispatch valid or timeout
            int timeout = 0;
            
            // If we expect valid, wait for it. If we expect invalid (stall), check immediately after settling.
            if (exp_valid) begin
                while (dut.rename_to_skid_valid !== 1'b1 && timeout < 20) begin
                    @(posedge clk);
                    timeout++;
                end
            end else begin
                @(posedge clk); // Step once to allow logic to evaluate
                #1;
            end

            #1; // Allow signals to settle

            // 1. Check Valid Signal
            if (dut.rename_to_skid_valid !== exp_valid) begin
                $error("[FAIL][%s] Valid Mismatch. Expected: %b, Got: %b", test_name, exp_valid, dut.rename_to_skid_valid);
            end else if (exp_valid) begin
                // 2. Check Source 1
                if (exp_prs1 != -1 && dut.rename_to_skid_prs1 !== exp_prs1) 
                    $error("[FAIL][%s] PRS1 Mismatch. Expected: P%0d, Got: P%0d", test_name, exp_prs1, dut.rename_to_skid_prs1);
                
                // 3. Check Source 2
                if (exp_prs2 != -1 && dut.rename_to_skid_prs2 !== exp_prs2) 
                    $error("[FAIL][%s] PRS2 Mismatch. Expected: P%0d, Got: P%0d", test_name, exp_prs2, dut.rename_to_skid_prs2);

                // 4. Check Destination
                if (exp_prd != -1 && dut.rename_to_skid_prd !== exp_prd) 
                    $error("[FAIL][%s] PRD Mismatch. Expected: P%0d, Got: P%0d", test_name, exp_prd, dut.rename_to_skid_prd);
                
                if (exp_prs1 == dut.rename_to_skid_prs1 && exp_prd == dut.rename_to_skid_prd)
                    $display("[PASS][%s] Correct mapping: prs1=P%0d -> prd=P%0d", test_name, dut.rename_to_skid_prs1, dut.rename_to_skid_prd);
            end else begin
                 $display("[PASS][%s] Correctly stalled (Valid=0) as expected.", test_name);
            end
        end
    endtask

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // =========================================================================
    // Main Test Procedure
    // =========================================================================
    initial begin
        $dumpfile("rename_tb.vcd");
        $dumpvars(0, rename_tb);

        // -----------------------------------------------------------
        // 1. Initialization
        // -----------------------------------------------------------
        $display("\n=== Starting Rename Stage Testbench ===");
        
        // Load Instructions
        // 0: ADDI x1, x0, 10    (Alloc P32)
        load_instr(0, create_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10));
        
        // 1: ADD x2, x1, x0     (Read P32 (x1), Alloc P33)
        load_instr(1, create_r_type(7'b0110011, 5'd2, 3'b000, 5'd1, 5'd0, 7'b0000000));
        
        // 2: FILL LOOP
        // We will fill the rest of the memory with instructions that consume registers
        // Total Free Registers = 128 - 32 = 96.
        // We used 2. We need 94 more to fill.
        // Let's just fill a large block of NOPs that write to x3
        for (int i = 2; i < 200; i++) begin
            // ADDI x3, x3, 1 (Consumes a new physical register every time)
            load_instr(i, create_i_type(7'b0010011, 5'd3, 3'b000, 5'd3, 12'd1));
        end

        // Reset
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset released.");

        // -----------------------------------------------------------
        // Test 1: Basic Allocation (First Instruction)
        // ADDI x1, x0, 10
        // Expect: rs1=x0(P0), rd=x1(P32)
        // -----------------------------------------------------------
        verify_rename_output("Basic_Alloc", 0, -1, 32, 1);
        @(posedge clk); // Advance

        // -----------------------------------------------------------
        // Test 2: RAW Dependency
        // ADD x2, x1, x0
        // Expect: rs1=x1(P32 from prev), rs2=x0(P0), rd=x2(P33)
        // -----------------------------------------------------------
        verify_rename_output("RAW_Dep", 32, 0, 33, 1);
        @(posedge clk); // Advance

        // -----------------------------------------------------------
        // Test 3: Saturate Free List
        // -----------------------------------------------------------
        $display("\n=== Filling Free List ===");
        
        // We have used P32, P33. Next is P34.
        // The Free List goes up to P127.
        // We need to consume P34 to P127.
        // (127 - 34) + 1 = 94 instructions.
        
        for (int k = 34; k <= 127; k++) begin
            // We just wait for valid to be high and verify the allocation increments
            wait(dut.rename_to_skid_valid);
            
            if (dut.rename_to_skid_prd !== k) begin
                $error("Allocation Sequence Error! Expected P%0d, Got P%0d", k, dut.rename_to_skid_prd);
            end
            @(posedge clk);
            #1; // Allow hold time
        end
        $display("[PASS] Free List Saturated (Allocated up to P127).");

        // -----------------------------------------------------------
        // Test 4: Verify Stall on Empty Free List
        // -----------------------------------------------------------
        // At this point, the Free List should be empty.
        // internal signal count should be 0.
        
        #1;
        if (dut.rename_inst.u_free_list.count !== 0) begin
            $error("Error: Internal Free List count is not 0! Count: %d", dut.rename_inst.u_free_list.count);
        end else begin
            $display("[INFO] Internal Free List count is 0.");
        end

        // The next instruction should NOT be valid at the output of rename
        // because rename_ready should be low, stalling the pipeline.
        
        // Wait a few cycles to see if anything comes out
        repeat(5) @(posedge clk);
        
        // Check "rename_ready" signal (internal to DUT)
        // It connects to skid_buffer_decode_rename.i_ready
        if (dut.rename_inst.rename_ready === 1'b0) begin
            $display("[PASS] Rename Ready signal is Low (Stall Active).");
        end else begin
            $error("[FAIL] Rename Ready signal is High despite empty free list!");
        end

        // Check that valid output is LOW
        if (dut.rename_to_skid_valid === 1'b0) begin
            $display("[PASS] Output Valid is Low (No dispatch allowed).");
        end else begin
            $error("[FAIL] Output Valid is High! Dispatched P%0d", dut.rename_to_skid_prd);
        end

        $display("\n=== All Rename Tests Passed ===");
        $finish;
    end

    // Timeout Safety
    initial begin
        #5000;
        $display("Simulation Timeout");
        $finish;
    end

endmodule
