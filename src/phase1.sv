`timescale 1ns / 1ps

module phase1 #(
    parameter type T = logic [31:0]
)(
    input logic clk,
    input logic rst
);

  // =================================================================================
  // VARIABLES
  // =================================================================================
  
  // INSTRUCTION CACHE STAGE
  T cache_to_fetch_instr;

  // FETCH STAGE
  logic [8:0] fetch_to_cache_pc;
  logic fetch_to_skid_valid;
  T fetch_to_skid_instr;
  logic [8:0] fetch_to_skid_pc;

  // SKID BUFFER BETWEEN FETCH AND DECODE
  logic skid_to_fetch_ready;
  logic skid_to_decode_valid;
  logic [8:0] skid_to_decode_pc;
  T skid_to_decode_instr;

  // DECODE STAGE
  logic decode_to_skid_ready;
  logic decode_to_skid_valid;
  logic [8:0] decode_to_skid_pc;
  logic [4:0] decode_to_skid_rs1;
  logic [4:0] decode_to_skid_rs2;
  logic [4:0] decode_to_skid_rd;
  logic decode_to_skid_ALUsrc;
  logic decode_to_skid_Branch;
  T decode_to_skid_immediate;
  logic [1:0] decode_to_skid_ALUOp;
  logic [1:0] decode_to_skid_FUtype;
  logic decode_to_skid_Memread;
  logic decode_to_skid_Memwrite;
  logic decode_to_skid_Regwrite;

  // =================================================================================
  // MODULE INSTANTIATIONS
  // =================================================================================

  blk_mem_gen_0 instruction_memory (
    .clka(clk),
    .addra(fetch_to_cache_pc),
    .douta(cache_to_fetch_instr)
  );
  
  fetcher #(
    .T(T)
  ) fetch_inst (
    .clk(clk),
    .reset(rst),
    .take_branch(1'b0), 
    .branch_loc('0),   
    .instr_from_cache(cache_to_fetch_instr), 
    .pc_to_cache(fetch_to_cache_pc),
    .instr_to_decode(fetch_to_skid_instr),
    .pc_to_decode(fetch_to_skid_pc),
    .ready(skid_to_fetch_ready),
    .valid(fetch_to_skid_valid)
  );

  
  pipe_skid_buffer #(
    .DWIDTH(41) // 32 bits instruction + 9 bits PC
  ) skid_buffer_fetch_decode (
    .clk(clk),
    .reset(rst),
    .i_data({fetch_to_skid_instr, fetch_to_skid_pc}),
    .i_valid(fetch_to_skid_valid),
    .o_ready(skid_to_fetch_ready),
    .o_data({skid_to_decode_instr, skid_to_decode_pc}),
    .o_valid(skid_to_decode_valid),
    .i_ready(decode_to_skid_ready)
  );


  decoder #(
    .T(T)
  ) decode_inst (
    .instruction(skid_to_decode_instr),
    .i_pc(skid_to_decode_pc),
    .i_valid(skid_to_decode_valid),
    // FIX: Temporarily tied to 1'b1 because the next stage (Rename) is commented out.
    // If this is left undefined, the Decoder stalls the whole pipeline.
    .i_ready(1'b1),                                                 
    .o_ready(decode_to_skid_ready),
    .o_pc(decode_to_skid_pc),
    .o_valid(decode_to_skid_valid),
    
    .rs1(decode_to_skid_rs1),
    .rs2(decode_to_skid_rs2),
    .rd(decode_to_skid_rd),
    .ALUsrc(decode_to_skid_ALUsrc),
    .Branch(decode_to_skid_Branch),
    .immediate(decode_to_skid_immediate),
    .ALUOp(decode_to_skid_ALUOp),
    .FUtype(decode_to_skid_FUtype),
    .Memread(decode_to_skid_Memread),
    .Memwrite(decode_to_skid_Memwrite),
    .Regwrite(decode_to_skid_Regwrite)
  );

  // ... (Downstream buffers and Rename stage commented out) ...

endmodule