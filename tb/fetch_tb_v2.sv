`timescale 1ns / 1ps

module fetch_tb;

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    parameter type T = logic [31:0];
    
    // Inputs
    logic clk;
    logic reset;
    logic take_branch;
    T branch_loc;
    T instr_from_cache;
    logic ready;

    // Outputs
    T pc_to_cache;
    T instr_to_decode;
    T pc_to_decode;
    logic valid;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Mock Instruction Memory (Simulating Cache)
    // -------------------------------------------------------------------------
    logic [31:0] imem [0:255]; // Small memory (256 words)

    // Fill memory with identifiable data based on address
    initial begin
        for (int i = 0; i < 256; i++) begin
            // Instruction data = 0xAA + Address (for easy visual debugging)
            imem[i] = 32'hAA000000 | (i * 4);
        end
    end

    // Combinational read logic (Fast cache model)
    assign instr_from_cache = imem[pc_to_cache[9:2]];

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // -------------------------------------------------------------------------
    // Test Procedure
    // -------------------------------------------------------------------------
    initial begin
        // Variable declarations must be at the top of the block
        T locked_pc;
        T locked_instr;

        $display("=== Starting Fetch Module Testbench ===");
        $dumpfile("fetch_tb.vcd");
        $dumpvars(0, fetch_tb);

        // --- 1. Initialization & Reset ---
        $display("[Test 1] Reset Behavior");
        reset = 1;
        ready = 1;
        take_branch = 0;
        branch_loc = 0;
        
        repeat(2) @(posedge clk); 
        #1; // Check values just after clock edge

        // Check Reset State
        assert(pc_to_cache == 0) else $error("Reset failed: pc_to_cache != 0");
        assert(valid == 0) else $error("Reset failed: valid != 0");
        
        reset = 0; // Release reset

        // --- 2. Sequential Fetching ---
        $display("[Test 2] Sequential Fetching");
        
        // Wait 3 cycles to let pipeline fill
        repeat(3) @(posedge clk);
        #1;

        // At this point, PC should be advancing
        assert(pc_to_cache == 32'hC)     else $error("Seq Fetch: Expected PC 0xC, got %h", pc_to_cache);
        assert(pc_to_decode == 32'h8)    else $error("Seq Fetch: Expected Decode PC 0x8, got %h", pc_to_decode);
        assert(instr_to_decode == imem[2]) else $error("Seq Fetch: Instruction mismatch");
        assert(valid == 1)               else $error("Seq Fetch: Valid should be 1");

        // --- 3. Branching ---
        $display("[Test 3] Branch Operation");
        
        @(posedge clk);
        #1; // Delay assignment to ensure it happens after clock edge
        // Trigger branch to 0x40
        take_branch = 1;
        branch_loc = 32'h40;
        
        @(posedge clk);
        // Important: Wait #1 before dropping take_branch to satisfy hold time
        // otherwise DUT might sample 0 at this very clock edge (race condition).
        #1; 
        take_branch = 0; 

        // Immediate check: pc_to_cache should be 0x40
        assert(pc_to_cache == 32'h40) else $error("Branch: PC did not update to 0x40");
        
        // Important: Your DUT logic sets valid_reg <= 0 on branch
        assert(valid == 0) else $error("Branch: Valid bit did not drop to 0 (pipeline flush)");

        // Wait one more cycle for valid to return
        @(posedge clk);
        #1;
        assert(valid == 1) else $error("Branch: Valid bit did not recover");
        assert(pc_to_decode == 32'h40) else $error("Branch: Decode PC incorrect");
        assert(instr_to_decode == imem[16]) else $error("Branch: Instruction at 0x40 mismatch");

        // --- 4. Backpressure / Stall ---
        $display("[Test 4] Stall / Backpressure");
        
        // Let it run for a moment
        @(posedge clk);
        #1;
        
        // Capture state before stall
        locked_pc = pc_to_decode;
        locked_instr = instr_to_decode;
        
        // Apply Stall
        ready = 0;
        
        repeat(3) @(posedge clk);
        #1;
        
        // Outputs should NOT have changed during these 3 cycles
        assert(pc_to_decode == locked_pc) else $error("Stall: PC changed while ready=0");
        assert(instr_to_decode == locked_instr) else $error("Stall: Instr changed while ready=0");
        
        // Release Stall
        ready = 1;
        @(posedge clk);
        #1;
        
        // PC should have advanced now
        assert(pc_to_decode != locked_pc) else $error("Stall: PC did not advance after ready=1");

        // --- End Simulation ---
        $display("=== All Tests Completed ===");
        #20;
        $finish;
    end

endmodule