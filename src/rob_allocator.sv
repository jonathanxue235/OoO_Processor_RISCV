`timescale 1ns / 1ps

module rob_allocator #(
    parameter ROB_WIDTH = 4 // 16 ROB Entries
) (
    input logic clk,
    input logic reset,

    input logic alloc_req,       // Request a new tag
    output logic [ROB_WIDTH-1:0] rob_tag, // The assigned tag
    
    // Branch / Recovery
    input logic is_branch_dispatch,
    input logic branch_mispredict,
    input logic [ROB_WIDTH-1:0] recovery_tag // NEW: Tag of the mispredicting branch
);
    logic [ROB_WIDTH-1:0] counter;
    // NEW: Array of snapshots indexed by ROB tag
    logic [ROB_WIDTH-1:0] counter_snapshots [0:(1<<ROB_WIDTH)-1];

    assign rob_tag = counter;

    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= '0;
            // No need to reset snapshots explicitly
        end
        else begin
            if (branch_mispredict) begin
                // Restore counter from the specific branch's snapshot
                counter <= counter_snapshots[recovery_tag];
            end
            else begin
                // Increment if allocated
                if (alloc_req) begin
                    counter <= counter + 1;
                end

                // Snapshot
                if (is_branch_dispatch) begin
                    // If we just allocated a branch, the *next* instruction 
                    // needs the *next* tag. We store the state of 'counter'
                    // associated with this branch's tag.
                    if (alloc_req)
                        counter_snapshots[counter] <= counter + 1;
                    else
                        counter_snapshots[counter] <= counter;
                end
            end
        end
    end

endmodule