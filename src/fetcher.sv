`timescale 1ns / 1ps

module fetcher #(
    parameter type T = logic [31:0]
) (
    input logic      clk,
    input logic      reset,

    input logic      take_branch,
    input T          branch_loc,

    input T          instr_from_cache,
    output T         pc_to_cache,

    output T         instr_to_decode,
    output T         pc_to_decode,

    input logic      ready,
    output logic     valid
);

    // Internal registers
    T pc_reg;                // Current Program counter (sent to ICache)
    
    // PC Pipeline to match BRAM latency (2 cycles for BRAM + 1 cycle for fetch register = 3 cycles total depth)
    T pc_pipe_1;             
    T pc_pipe_2;
    
    T fetched_instr_reg;     // Output register for instruction
    T fetched_pc_reg;        // Output register for PC
    logic valid_reg;

    // Fetch logic
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_reg <= 32'h0;
            pc_pipe_1 <= 32'h0;
            pc_pipe_2 <= 32'h0;
            fetched_instr_reg <= 32'h0;
            fetched_pc_reg <= 32'h0;
            valid_reg <= 1'b0;
        end
        else begin
            // Handle branch redirection
            if (take_branch) begin
                pc_reg <= branch_loc;
                // Flush the pipeline on a branch (invalidate downstream)
                valid_reg <= 1'b0; 
                // Optional: You might want to flush pipe registers to 0 or branch_loc for cleanliness, 
                // but valid_reg=0 handles the logic correctness.
            end
            // Normal fetch operation when downstream is ready
            else if (ready || !valid_reg) begin
                // 1. Send Address to Cache (pc_reg is connected to pc_to_cache)
                
                // 2. Shift PC down the pipeline to wait for Data arrival
                pc_pipe_1 <= pc_reg;
                pc_pipe_2 <= pc_pipe_1;
                
                // 3. Capture Data and aligned PC
                // If BRAM latency is 2 cycles, Data matching pc_pipe_2 arrives now.
                fetched_instr_reg <= instr_from_cache;
                fetched_pc_reg <= pc_pipe_2; 

                // 4. Move to next PC
                pc_reg <= pc_reg + 32'd4;
                
                valid_reg <= 1'b1;
            end
            // If downstream is not ready, we stall. 
            // All registers (pc_reg, pipes, fetched_*) hold their values automatically.
        end
    end

    // Output assignments
    assign pc_to_cache = pc_reg;
    assign instr_to_decode = fetched_instr_reg;
    assign pc_to_decode = fetched_pc_reg;
    assign valid = valid_reg;

endmodule