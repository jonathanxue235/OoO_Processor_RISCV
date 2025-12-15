`timescale 1ns / 1ps

module fetcher #(
    parameter type T = logic [31:0]
) (
    input logic      clk,
    input logic      reset,
    
    // Recovery Interface
    input logic      take_branch, // Mispredict recovery signal
    input T          branch_loc,  // Correct PC from recovery
    
    // Cache Interface
    input T          instr_from_cache,
    output T         pc_to_cache,
    
    // Decode Interface
    output T         instr_to_decode,
    output T         pc_to_decode,
    output logic     pred_taken_to_decode,  // NEW
    output T         pred_target_to_decode, // NEW
    
    input logic      ready,
    output logic     valid,

    // Predictor Update Interface (from ROB)
    input logic      update_en,
    input T          update_pc,
    input logic      update_taken,
    input T          update_target
);

    // Internal registers
    T pc_reg;
    T next_pc; // Combinational next PC

    // Branch Predictor Signals
    logic pred_taken;
    T     pred_target;

    // Pipeline
    T pc_pipe_1, pc_pipe_2;
    logic valid_pipe_1, valid_pipe_2;
    logic pred_taken_pipe_1, pred_taken_pipe_2;
    T pred_target_pipe_1, pred_target_pipe_2;

    // Output Registers
    T fetched_instr_reg;
    T fetched_pc_reg;
    logic valid_reg;
    logic pred_taken_reg;
    T     pred_target_reg;

    // ------------------------------------------------
    // Branch Predictor Instantiation
    // ------------------------------------------------
    branch_predictor #(
        .PC_WIDTH(32),
        .BTB_SIZE(8)
    ) u_bp (
        .clk(clk),
        .reset(reset),
        .fetch_pc(pc_reg),
        .pred_taken(pred_taken),
        .pred_target(pred_target),
        .update_valid(update_en),
        .update_pc(update_pc),
        .update_taken(update_taken),
        .update_target(update_target)
    );

    // ------------------------------------------------
    // Next PC Logic
    // ------------------------------------------------
    always_comb begin
        if (take_branch) begin
            next_pc = branch_loc; // Recovery has highest priority
        end else if (pred_taken) begin
            next_pc = pred_target; // Predictor redirection
        end else begin
            next_pc = pc_reg + 32'd4; // Default Fallthrough
        end
    end

    // ------------------------------------------------
    // Fetch Pipeline
    // ------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            pc_reg <= 32'h0;
            pc_pipe_1 <= '0; pc_pipe_2 <= '0;
            valid_pipe_1 <= 0; valid_pipe_2 <= 0;
            pred_taken_pipe_1 <= 0; pred_taken_pipe_2 <= 0;
            pred_target_pipe_1 <= '0; pred_target_pipe_2 <= '0;
            
            fetched_instr_reg <= '0;
            fetched_pc_reg <= '0;
            valid_reg <= 0;
            pred_taken_reg <= 0;
            pred_target_reg <= '0;
        end
        else begin
            if (take_branch) begin
                pc_reg <= branch_loc;
                // Flush pipeline on recovery
                valid_pipe_1 <= 0;
                valid_pipe_2 <= 0;
                valid_reg <= 0;
            end
            else if (ready || !valid_reg) begin
                // Update PC
                pc_reg <= next_pc;

                // Pipe Stage 1
                pc_pipe_1 <= pc_reg;
                pred_taken_pipe_1 <= pred_taken;
                pred_target_pipe_1 <= pred_target;
                valid_pipe_1 <= 1'b1;

                // Pipe Stage 2
                pc_pipe_2 <= pc_pipe_1;
                pred_taken_pipe_2 <= pred_taken_pipe_1;
                pred_target_pipe_2 <= pred_target_pipe_1;
                valid_pipe_2 <= valid_pipe_1;

                // Output Stage
                fetched_instr_reg <= instr_from_cache;
                fetched_pc_reg <= pc_pipe_2;
                valid_reg <= valid_pipe_2;
                pred_taken_reg <= pred_taken_pipe_2;
                pred_target_reg <= pred_target_pipe_2;
            end
        end
    end

    // Output assignments
    assign pc_to_cache = pc_reg;
    assign instr_to_decode = fetched_instr_reg;
    assign pc_to_decode = fetched_pc_reg;
    assign valid = valid_reg;
    assign pred_taken_to_decode = pred_taken_reg;
    assign pred_target_to_decode = pred_target_reg;

endmodule