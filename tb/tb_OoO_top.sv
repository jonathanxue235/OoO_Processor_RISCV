`timescale 1ns / 1ps

module tb_OoO_top;

    // =================================================================================
    // PARAMETERS & SIGNALS
    // =================================================================================
    parameter type T = logic [31:0];

    logic clk;
    logic rst;

    // =================================================================================
    // MODULE INSTANTIATION
    // =================================================================================
    OoO_top #(
        .T(T)
    ) uut (
        .clk(clk),
        .rst(rst)
    );

    // =================================================================================
    // CLOCK GENERATION
    // =================================================================================
    // Generate a 100MHz clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // =================================================================================
    // TEST SEQUENCE
    // =================================================================================
    initial begin
        // 1. Initialize Inputs
        rst = 1;
        $display("Starting Simulation...");
        $display("Applying Reset...");

        // 2. Hold Reset for 10 clock cycles
        repeat (10) @(posedge clk);
        
        // 3. Release Reset
        rst = 0;
        $display("Reset Released. Processor starting...");

        // 4. Run Simulation for a fixed duration (e.g., 50 cycles)
        repeat (50) @(posedge clk);

        // 5. Finish Simulation
        $display("Simulation Finished.");
        $finish;
    end

    // =================================================================================
    // MONITORING
    // =================================================================================
    // Monitor key signals to verify instruction flow
    // We use hierarchical references (uut.*) to see internal signals since the top module has no outputs.
    initial begin
        $display("---------------------------------------------------------------------------------------------------------");
        $display("Time | PC (Fetch) | Valid | Instr (Fetch) | PC (Decode) | Instr (Decode) | RS1 | RS2 | RD | ALUOp");
        $display("---------------------------------------------------------------------------------------------------------");
        
        // Use $monitor to print whenever these signals change
        // Note: bit slicing might be needed if signals are too wide for display, but here they fit.
        $monitor("%4t | %h        | %b     | %h      | %h        | %h       | %2d  | %2d  | %2d | %b", 
            $time, 
            uut.fetch_to_cache_pc,        // PC sent to memory
            uut.fetch_to_skid_valid,      // Valid signal from fetcher
            uut.cache_to_fetch_instr,     // Instruction coming back from memory
            uut.decode_to_skid_pc,        // PC at decode stage
            uut.skid_to_decode_instr,     // Instruction entering decoder
            uut.decode_to_skid_rs1,       // Decoded RS1
            uut.decode_to_skid_rs2,       // Decoded RS2
            uut.decode_to_skid_rd,        // Decoded RD
            uut.decode_to_skid_ALUOp      // Decoded ALU Op
        );
    end

endmodule