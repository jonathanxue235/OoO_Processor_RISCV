`timescale 1ns / 1ps

module rob_allocator #(
    parameter ROB_WIDTH = 5 
) (
    input logic clk,
    input logic reset,
    input logic alloc_req,       
    output logic [ROB_WIDTH-1:0] rob_tag, 
    input logic is_branch_dispatch,
    input logic branch_mispredict
);
    logic [ROB_WIDTH-1:0] counter;
    logic [ROB_WIDTH-1:0] counter_shadow;

    assign rob_tag = counter;

    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= '0;
            counter_shadow <= '0;
        end
        else begin
            if (branch_mispredict) begin
                // FLUSH LOGIC FIXED: Restore counter from shadow (checkpoint)
                counter <= counter_shadow; 
            end
            else begin
                // Increment if allocated
                if (alloc_req) begin
                    counter <= counter + 1;
                end

                // Snapshot
                if (is_branch_dispatch) begin
                    if (alloc_req)
                        counter_shadow <= counter + 1;
                    else
                        counter_shadow <= counter;
                end
            end
        end
    end
endmodule