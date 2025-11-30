module OoO_top #(
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

  // SKID BUFFER BETWEEN DECODE AND RENAME
  logic skid_to_rename_ready;
  logic skid_to_rename_valid;
  logic [8:0] skid_to_rename_pc;
  logic [4:0] skid_to_rename_rs1;
  logic [4:0] skid_to_rename_rs2;
  logic [4:0] skid_to_rename_rd;
  logic skid_to_rename_ALUsrc;
  logic skid_to_rename_Branch;
  T skid_to_rename_immediate;
  logic [1:0] skid_to_rename_ALUOp;
  logic [1:0] skid_to_rename_FUtype;
  logic skid_to_rename_Memread;
  logic skid_to_rename_Memwrite;
  logic skid_to_rename_Regwrite;

  // RENAME STAGE
  logic rename_to_skid_ready;
  logic rename_to_skid_valid;
  logic [6:0] rename_to_skid_prs1; // Phys Source 1
  logic [6:0] rename_to_skid_prs2; // Phys Source 2
  logic [6:0] rename_to_skid_prd;  // Phys Dest (New)
  logic [6:0] rename_to_skid_old_prd; // Old Phys Dest (For ROB)
  logic [3:0] rename_to_skid_rob_tag;



  // logic dispatch_valid;
  // logic [6:0] dispatch_prs1; // Phys Source 1
  // logic [6:0] dispatch_prs2; // Phys Source 2
  // logic [6:0] dispatch_prd;  // Phys Dest (New)
  // logic [6:0] dispatch_old_prd; // Old Phys Dest (For ROB)
  // logic [3:0] dispatch_rob_tag;
  // logic rename_ready;



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
    .clk(clk),                                                      // in
    .reset(rst),                                                    // in
    .take_branch(1'b0), // No branch handling in this top module    // in
    .branch_loc('0),    // No branch handling in this top module    // in
    .instr_from_cache(cache_to_fetch_instr),                        // in 
    .pc_to_cache(fetch_to_cache_pc),                                // out
    .instr_to_decode(fetch_to_skid_instr),                          // out
    .pc_to_decode(fetch_to_skid_pc),                                // out
    .ready(skid_to_fetch_ready),                                    // in
    .valid(fetch_to_skid_valid)                                     // out
  );

  
  pipe_skid_buffer #(
    .DWIDTH(41) // 32 bits instruction + 9 bits PC
  ) skid_buffer_fetch_decode (
    .clk(clk),                                                      // in
    .reset(rst),                                                    // in
    .i_data({fetch_to_skid_instr, fetch_to_skid_pc}),               // in
    .i_valid(fetch_to_skid_valid),                                  // in
    .o_ready(skid_to_fetch_ready),                                  // out
    .o_data({skid_to_decode_instr, skid_to_decode_pc}),             // out
    .o_valid(skid_to_decode_valid),                                 // out
    .i_ready(decode_to_skid_ready)                                  // in
  );


  decoder #(
    .T(T)
  ) decode_inst (
    .instruction(skid_to_decode_instr),                             // in
    .i_pc(skid_to_decode_pc),                                       // in
    .i_valid(skid_to_decode_valid),                                 // in
    .i_ready(skid_to_decode_ready),                                 // in
    .o_ready(decode_to_skid_ready),                                 // out
    .o_pc(decode_to_skid_pc),                                       // out
    .o_valid(decode_to_skid_valid),                                 // out
    .rs1(decode_to_skid_rs1),                                       // out
    .rs2(decode_to_skid_rs2),                                       // out
    .rd(decode_to_skid_rd),                                         // out
    .ALUsrc(decode_to_skid_ALUsrc),                                 // out
    .Branch(decode_to_skid_Branch),                                 // out
    .immediate(decode_to_skid_immediate),                           // out
    .ALUOp(decode_to_skid_ALUOp),                                   // out
    .FUtype(decode_to_skid_FUtype),                                 // out
    .Memread(decode_to_skid_Memread),                               // out
    .Memwrite(decode_to_skid_Memwrite),                             // out
    .Regwrite(decode_to_skid_Regwrite)                              // out
  );

  pipe_skid_buffer #(
    .DWIDTH(65) // Adjusted width for decode to rename signals
  ) skid_buffer_decode_rename (
    .clk(clk),                                                      // in
    .reset(rst),                                                    // in
    .i_data({decode_to_skid_pc, decode_to_skid_rs1, 
             decode_to_skid_rs2, decode_to_skid_rd,
             decode_to_skid_ALUsrc, decode_to_skid_Branch, 
             decode_to_skid_immediate, decode_to_skid_ALUOp, 
             decode_to_skid_FUtype, decode_to_skid_Memread,
             decode_to_skid_Memwrite, decode_to_skid_Regwrite}),    // in
    .i_valid(decode_to_skid_valid),                                 // in
    .o_ready(decode_to_skid_ready),                                 // out
    .o_data({skid_to_rename_pc, skid_to_rename_rs1, 
             skid_to_rename_rs2, skid_to_rename_rd,
             skid_to_rename_ALUsrc, skid_to_rename_Branch, 
             skid_to_rename_immediate, skid_to_rename_ALUOp, 
             skid_to_rename_FUtype, skid_to_rename_Memread,
             skid_to_rename_Memwrite, skid_to_rename_Regwrite}),    // out
    .o_valid(skid_to_rename_valid),                                 // out
    .i_ready(rename_to_skid_ready)                                  // in
  );
  
  rename rename_inst (
    .clk(clk),                                                      // in
    .reset(rst),                                                    // in
    .decode_valid(skid_to_rename_valid),                            // in
    .decode_rs1(skid_to_rename_rs1),                                // in
    .decode_rs2(skid_to_rename_rs2),                                // in
    .decode_rd(skid_to_rename_rd),                                  // in
    .decode_is_branch(skid_to_rename_FUtype == 2'b01),              // in
    .dispatch_valid(rename_to_skid_valid),                          // out
    .dispatch_prs1(rename_to_skid_prs1),                            // out - Phys Source 1
    .dispatch_prs2(rename_to_skid_prs2),                            // out - Phys Source 2
    .dispatch_prd(rename_to_skid_prd),                              // out - Phys Dest (New)
    .dispatch_old_prd(rename_to_skid_old_prd),                      // out - Old Phys Dest (For ROB)
    .dispatch_rob_tag(rename_to_skid_rob_tag),                      // out
    .rename_ready(rename_to_skid_ready),                            // out
    .commit_en(1'b0),                                               // in - No commit handling in this top module
    .commit_old_preg(),                                             // in - No commit handling in this top module
    .branch_mispredict(1'b0)                                        // in - No branch handling in this top module
  );

  



endmodule