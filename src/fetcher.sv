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
    T pc_reg;                
    
    // PC Pipeline
    T pc_pipe_1;
    T pc_pipe_2;
    
    // Valid Pipeline (MATCHES PC_PIPE DEPTH)
    logic valid_pipe_1;
    logic valid_pipe_2;

    T fetched_instr_reg;     
    T fetched_pc_reg;
    logic valid_reg;

    // Fetch logic
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_reg <= 32'h0;
            pc_pipe_1 <= 32'h0;
            pc_pipe_2 <= 32'h0;
            fetched_instr_reg <= 32'h0;
            fetched_pc_reg <= 32'h0;
            
            // RESET PIPELINES
            valid_pipe_1 <= 1'b0;
            valid_pipe_2 <= 1'b0;
            valid_reg <= 1'b0;
        end
        else begin
            // Handle branch redirection
            if (take_branch) begin
                pc_reg <= branch_loc;
                
                // FLUSH THE VALID PIPELINE
                // This ensures "garbage" or old instructions currently in the BRAM 
                // pipeline are marked invalid when they finally emerge.
                valid_pipe_1 <= 1'b0;
                valid_pipe_2 <= 1'b0;
                valid_reg    <= 1'b0; 
            end
            // Normal fetch operation when downstream is ready
            else if (ready || !valid_reg) begin
                // 1. Shift PC down the pipeline
                pc_pipe_1 <= pc_reg;
                pc_pipe_2 <= pc_pipe_1;
                
                // 2. Shift VALID signal down the pipeline
                // We are issuing a new request, so we push '1' into the start of the pipe.
                valid_pipe_1 <= 1'b1;
                valid_pipe_2 <= valid_pipe_1;
                
                // 3. Capture Data and Valid Signal
                fetched_instr_reg <= instr_from_cache;
                fetched_pc_reg <= pc_pipe_2; 
                valid_reg      <= valid_pipe_2; // Only becomes 1 when the pipe fills

                // 4. Move to next PC
                pc_reg <= pc_reg + 32'd4;
            end
            // If downstream is not ready, we stall (hold all register values)
        end
    end

    // Output assignments
    assign pc_to_cache = pc_reg;
    assign instr_to_decode = fetched_instr_reg;
    assign pc_to_decode = fetched_pc_reg;
    assign valid = valid_reg;

endmodule