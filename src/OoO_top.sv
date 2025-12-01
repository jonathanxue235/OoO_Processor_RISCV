`timescale 1ns / 1ps

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
  logic [3:0] decode_to_skid_ALUOp; // 4-bit
  logic [1:0] decode_to_skid_FUtype;
  logic decode_to_skid_Memread;
  logic decode_to_skid_Memwrite;
  logic decode_to_skid_Regwrite;

  // SKID BUFFER BETWEEN DECODE AND RENAME
  logic skid_to_decode_ready;
  logic skid_to_rename_valid;
  logic [8:0] skid_to_rename_pc;
  logic [4:0] skid_to_rename_rs1;
  logic [4:0] skid_to_rename_rs2;
  logic [4:0] skid_to_rename_rd;
  logic skid_to_rename_ALUsrc;
  logic skid_to_rename_Branch;
  T skid_to_rename_immediate;
  logic [3:0] skid_to_rename_ALUOp; // 4-bit
  logic [1:0] skid_to_rename_FUtype;
  logic skid_to_rename_Memread;
  logic skid_to_rename_Memwrite;
  logic skid_to_rename_Regwrite;

  // RENAME STAGE
  logic rename_to_skid_ready;
  logic rename_to_skid_valid;
  logic [8:0] rename_to_skid_pc;
  logic [6:0] rename_to_skid_prs1; // Phys Source 1
  logic [6:0] rename_to_skid_prs2; // Phys Source 2
  logic [6:0] rename_to_skid_prd;  // Phys Dest (New)
  logic [6:0] rename_to_skid_old_prd; // Old Phys Dest (For ROB)
  logic [3:0] rename_to_skid_rob_tag;
  logic [1:0] rename_to_skid_futype;
  logic [3:0] rename_to_skid_alu_op; // 4-bit
  T           rename_to_skid_immediate;
  logic       rename_to_skid_branch;
  logic       rename_to_skid_alusrc;
  logic       rename_to_skid_memwrite; // NEW: MemWrite pass-through

  // SKID BUFFER BETWEEN RENAME AND DISPATCH
  logic skid_to_rename_ready;
  logic skid_to_dispatch_valid;
  logic [8:0] skid_to_dispatch_pc;
  logic [6:0] skid_to_dispatch_prs1; // Phys Source 1
  logic [6:0] skid_to_dispatch_prs2; // Phys Source 2
  logic [6:0] skid_to_dispatch_prd; // Phys Dest (New)
  logic [6:0] skid_to_dispatch_old_prd; // Old Phys Dest (For ROB)
  logic [3:0] skid_to_dispatch_rob_tag;
  logic [1:0] skid_to_dispatch_futype;
  logic [3:0] skid_to_dispatch_alu_op; // 4-bit
  T           skid_to_dispatch_immediate;
  logic       skid_to_dispatch_branch;
  logic       skid_to_dispatch_alusrc;
  logic       skid_to_dispatch_memwrite; // NEW: MemWrite from Skid

  // PHYSICAL REGISTER FILE READ DATA 
  logic [31:0] alu_op_a, alu_op_b;
  logic [31:0] br_op_a,  br_op_b;
  logic [31:0] lsu_op_a, lsu_op_b;

  // DISPATCH STAGE & ROB & RS WIRES
  logic dispatch_to_skid_ready; // Backpressure from ROB and RS
  logic rob_full;
  logic alu_rs_full;
  logic branch_rs_full;
  logic lsu_rs_full;
  
  // Allocation Signals from Dispatch Controller
  logic dispatch_alloc_rob;
  logic dispatch_alloc_alu;
  logic dispatch_alloc_branch;
  logic dispatch_alloc_lsu;
  
  // Commit Signals from ROB
  logic commit_valid;
  logic [6:0] commit_old_preg;
  logic [3:0] commit_tag;

  // =================================================================================
  // ISSUE & WRITEBACK SIGNALS
  // =================================================================================
  
  // --- ALU ---
  // Issue (RS -> EU)
  logic alu_issue_valid;
  logic [6:0] alu_issue_prs1, alu_issue_prs2, alu_issue_prd;
  logic [3:0] alu_issue_rob_tag;
  logic [31:0] alu_issue_imm;
  logic [3:0]  alu_issue_op;
  logic [31:0] alu_issue_pc;
  logic        alu_issue_alusrc;
  
  // Writeback (EU -> PRF/ROB)
  logic        alu_wb_valid;
  logic [31:0] alu_wb_data;
  logic [6:0]  alu_wb_dest;
  logic [3:0]  alu_cdb_tag;

  // --- Branch ---
  // Issue (RS -> EU)
  logic branch_issue_valid;
  logic [6:0] branch_issue_prs1, branch_issue_prs2, branch_issue_prd;
  logic [3:0] branch_issue_rob_tag;
  logic [31:0] branch_issue_imm;
  logic [3:0]  branch_issue_op; // Mapped to funct3
  logic [31:0] branch_issue_pc;
  
  // Writeback / Completion (EU -> ROB)
  logic       branch_wb_valid;
  logic [3:0] branch_cdb_tag;
  logic       branch_taken;
  logic [31:0] branch_target_addr;
  logic       branch_mispredict;

  // --- LSU ---
  // Issue (RS -> EU)
  logic lsu_issue_valid;
  logic [6:0] lsu_issue_prs1, lsu_issue_prs2, lsu_issue_prd;
  logic [3:0] lsu_issue_rob_tag;
  logic [31:0] lsu_issue_imm;
  logic [3:0]  lsu_issue_op;
  logic [31:0] lsu_issue_pc;
  logic        lsu_issue_memwrite; // NEW: Output from RS to LSU
  
  // Writeback (EU -> PRF/ROB)
  logic        lsu_wb_valid;
  logic [31:0] lsu_wb_data;
  logic [6:0]  lsu_wb_dest;
  logic [3:0]  lsu_cdb_tag;

  // --- Common Data Bus (CDB) Arbiter Signals ---
  logic       cdb_valid;
  logic [3:0] cdb_tag;
  logic [6:0] cdb_prd; // For RS Wakeup

  // =================================================================================
  // BUSY TABLE (SCOREBOARD) LOGIC
  // =================================================================================
  // Tracks the readiness of every physical register.
  // 1 = Ready (Data available in PRF)
  // 0 = Busy (Waiting for Writer)
  logic [127:0] phys_reg_busy;

  always_ff @(posedge clk) begin
      if (rst) begin
          phys_reg_busy <= '1; // All registers ready on reset
      end else begin
          // 1. ALLOCATION (Mark Busy)
          if (skid_to_dispatch_valid && dispatch_to_skid_ready) begin
               if (skid_to_dispatch_prd != 0) // Never mark P0 busy
                   phys_reg_busy[skid_to_dispatch_prd] <= 1'b0;
          end

          // 2. WRITEBACK (Mark Ready)
          if (cdb_valid && cdb_prd != 0) begin
               phys_reg_busy[cdb_prd] <= 1'b1;
          end
      end
  end

  // =================================================================================
  // MODULE INSTANTIATIONS
  // =================================================================================

  // 1. Instruction Memory
  blk_mem_gen_0 instruction_memory (
    .clka(clk),
    .addra({2'b00, fetch_to_cache_pc[8:2]}),
    .douta(cache_to_fetch_instr)
  );

  // 2. Fetcher
  fetcher #(
    .T(T)
  ) fetch_inst (
    .clk(clk),                                      
    .reset(rst),                            
    .take_branch(1'b0),
    .branch_loc(32'b0),    
    .instr_from_cache(cache_to_fetch_instr),       
    .pc_to_cache(fetch_to_cache_pc),    
    .instr_to_decode(fetch_to_skid_instr),         
    .pc_to_decode(fetch_to_skid_pc[31:0]),
    .ready(skid_to_fetch_ready),     
    .valid(fetch_to_skid_valid)                    
  );

  // 3. Skid Buffer: Fetch -> Decode
  pipe_skid_buffer #(
    .DWIDTH(41) 
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

  // 4. Decoder
  decoder #(
    .T(T)
  ) decode_inst (
    .instruction(skid_to_decode_instr),             
    .i_pc(skid_to_decode_pc),                       
    .i_valid(skid_to_decode_valid),                 
    .i_ready(skid_to_decode_ready),            
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

  // 5. Skid Buffer: Decode -> Rename
  // DWIDTH 67
  pipe_skid_buffer #(
    .DWIDTH(67) 
  ) skid_buffer_decode_rename (
    .clk(clk),                                      
    .reset(rst),                         
    .i_data({decode_to_skid_pc, decode_to_skid_rs1, 
             decode_to_skid_rs2, decode_to_skid_rd,
             decode_to_skid_ALUsrc, decode_to_skid_Branch, 
             decode_to_skid_immediate, decode_to_skid_ALUOp,
             decode_to_skid_FUtype, decode_to_skid_Memread,
             decode_to_skid_Memwrite, decode_to_skid_Regwrite}), 
    .i_valid(decode_to_skid_valid),           
    .o_ready(skid_to_decode_ready),                  
    .o_data({skid_to_rename_pc, skid_to_rename_rs1, 
             skid_to_rename_rs2, skid_to_rename_rd,
             skid_to_rename_ALUsrc, skid_to_rename_Branch, 
             skid_to_rename_immediate, skid_to_rename_ALUOp,
             skid_to_rename_FUtype, skid_to_rename_Memread,
             skid_to_rename_Memwrite, skid_to_rename_Regwrite}), 
    .o_valid(skid_to_rename_valid),                  
    .i_ready(rename_to_skid_ready)                  
  );

  // 6. Rename
  rename rename_inst (
    .clk(clk),                                      
    .reset(rst),                                    
    .decode_valid(skid_to_rename_valid),  
    .decode_rs1(skid_to_rename_rs1),  
    .decode_rs2(skid_to_rename_rs2),                
    .decode_rd(skid_to_rename_rd),                  
    .decode_is_branch(skid_to_rename_FUtype == 2'b01), 
    .decode_reg_write(skid_to_rename_Regwrite),     
    .i_ready(skid_to_rename_ready),        
    
    // Outputs
    .dispatch_valid(rename_to_skid_valid),  
    .dispatch_prs1(rename_to_skid_prs1),            
    .dispatch_prs2(rename_to_skid_prs2),            
    .dispatch_prd(rename_to_skid_prd),              
    .dispatch_old_prd(rename_to_skid_old_prd),      
    .dispatch_rob_tag(rename_to_skid_rob_tag),    
    .rename_ready(rename_to_skid_ready),            
    
    // Commit Inputs
    .commit_en(commit_valid),                       
    .commit_old_preg(commit_old_preg),              
    
    // Branch Recovery
    .branch_mispredict(1'b0) 
  );

  // Pass-Through Signal Assignments (Decode -> Rename -> Dispatch)
  assign rename_to_skid_pc       = skid_to_rename_pc;
  assign rename_to_skid_futype   = skid_to_rename_FUtype;
  assign rename_to_skid_alu_op   = skid_to_rename_ALUOp;
  assign rename_to_skid_immediate= skid_to_rename_immediate;
  assign rename_to_skid_branch   = skid_to_rename_Branch;
  assign rename_to_skid_alusrc   = skid_to_rename_ALUsrc;
  assign rename_to_skid_memwrite = skid_to_rename_Memwrite; // NEW Pass-through

  // 7. Skid Buffer: Rename -> Dispatch
  // DWIDTH Increased: 81 -> 82 (+1 for MemWrite)
  pipe_skid_buffer #(
    .DWIDTH(82) 
  ) skid_buffer_rename_dispatch (
    .clk(clk),                              
    .reset(rst),                           
    .i_data({rename_to_skid_pc, rename_to_skid_prs1, 
             rename_to_skid_prs2, rename_to_skid_prd,
             rename_to_skid_old_prd, rename_to_skid_rob_tag,
             rename_to_skid_futype, rename_to_skid_alu_op,
             rename_to_skid_immediate, rename_to_skid_branch, 
             rename_to_skid_alusrc,
             rename_to_skid_memwrite}), // NEW
    .i_valid(rename_to_skid_valid),      
    .o_ready(skid_to_rename_ready),                 
    .o_data({skid_to_dispatch_pc, skid_to_dispatch_prs1, 
             skid_to_dispatch_prs2, skid_to_dispatch_prd,
             skid_to_dispatch_old_prd, skid_to_dispatch_rob_tag,
             skid_to_dispatch_futype, skid_to_dispatch_alu_op,
             skid_to_dispatch_immediate, skid_to_dispatch_branch,
             skid_to_dispatch_alusrc,
             skid_to_dispatch_memwrite}), // NEW
    .o_valid(skid_to_dispatch_valid),               
    .i_ready(dispatch_to_skid_ready)                 
  );

  // 8. Dispatch Controller
  dispatch dispatch_unit (
      .i_valid(skid_to_dispatch_valid),
      .i_futype(skid_to_dispatch_futype),
      .rob_full(rob_full),
      .alu_rs_full(alu_rs_full),
      .branch_rs_full(branch_rs_full),
      .lsu_rs_full(lsu_rs_full),
      .o_ready(dispatch_to_skid_ready),
      .rob_alloc(dispatch_alloc_rob),
      .alu_rs_alloc(dispatch_alloc_alu),
      .branch_rs_alloc(dispatch_alloc_branch),
      .lsu_rs_alloc(dispatch_alloc_lsu)
  );

  // 9. Reorder Buffer (ROB) & CDB Arbiter
  always_comb begin
      if (branch_wb_valid) begin
          cdb_valid = 1'b1;
          cdb_tag   = branch_cdb_tag;
          cdb_prd   = 7'b0;
      end else if (lsu_wb_valid) begin
          cdb_valid = 1'b1;
          cdb_tag   = lsu_cdb_tag;
          cdb_prd   = lsu_wb_dest;
      end else if (alu_wb_valid) begin
          cdb_valid = 1'b1;
          cdb_tag   = alu_cdb_tag;
          cdb_prd   = alu_wb_dest;
      end else begin
          cdb_valid = 1'b0;
          cdb_tag   = 4'b0;
          cdb_prd   = 7'b0;
      end
  end

  rob #(
      .ROB_WIDTH(4), 
      .PREG_WIDTH(7)
  ) rob_inst (
      .clk(clk),
      .reset(rst),
      .i_valid(dispatch_alloc_rob), 
      .i_tag(skid_to_dispatch_rob_tag),
      .i_old_prd(skid_to_dispatch_old_prd),
      .i_is_branch(skid_to_dispatch_branch),
      .i_pc({23'b0, skid_to_dispatch_pc}),
      .o_full(rob_full),
      .i_cdb_valid(cdb_valid),
      .i_cdb_tag(cdb_tag),
      .o_commit_valid(commit_valid),
      .o_commit_old_preg(commit_old_preg),
      .o_commit_tag(commit_tag),
      .branch_mispredict(1'b0)
  );

  // 10. Reservation Station: ALU
  reservation_station #(
      .PREG_WIDTH(7), .ROB_WIDTH(4), .RS_SIZE(8)
  ) rs_alu_inst (
      .clk(clk), .reset(rst),
      
      .i_valid(dispatch_alloc_alu),
      .i_pc({23'b0, skid_to_dispatch_pc}),
      .i_prs1(skid_to_dispatch_prs1),
      .i_prs2(skid_to_dispatch_prs2),
      .i_prd(skid_to_dispatch_prd),
      .i_rob_tag(skid_to_dispatch_rob_tag),
      .i_imm(skid_to_dispatch_immediate),
      .i_cdb_valid(cdb_valid),
      .i_cdb_prd(cdb_prd),
      .i_alu_op(skid_to_dispatch_alu_op), 
      .i_alusrc(skid_to_dispatch_alusrc),
      .i_memwrite(1'b0), // Unused for ALU

      .i_rs1_ready((skid_to_dispatch_prs1 == 0) || phys_reg_busy[skid_to_dispatch_prs1]),
      .i_rs2_ready((skid_to_dispatch_prs2 == 0) || phys_reg_busy[skid_to_dispatch_prs2]),

      .o_full(alu_rs_full),

      .i_eu_ready(1'b1), 
      .o_issue_valid(alu_issue_valid),
      .o_issue_prs1(alu_issue_prs1),
      .o_issue_prs2(alu_issue_prs2),
      .o_issue_prd(alu_issue_prd),
      .o_issue_rob_tag(alu_issue_rob_tag),
      .o_issue_imm(alu_issue_imm),
      .o_issue_alu_op(alu_issue_op), 
      .o_issue_pc(alu_issue_pc),
      .o_issue_alusrc(alu_issue_alusrc),
      .o_issue_memwrite(), // Unconnected
      .branch_mispredict(1'b0)
  );

  // 11. Reservation Station: Branch
  reservation_station #(
      .PREG_WIDTH(7), .ROB_WIDTH(4), .RS_SIZE(8)
  ) rs_branch_inst (
      .clk(clk), .reset(rst),
      .i_valid(dispatch_alloc_branch),
      .i_pc({23'b0, skid_to_dispatch_pc}),
      .i_prs1(skid_to_dispatch_prs1), .i_prs2(skid_to_dispatch_prs2), .i_prd(skid_to_dispatch_prd),
      .i_rob_tag(skid_to_dispatch_rob_tag), .i_imm(skid_to_dispatch_immediate), 
      .i_alu_op(skid_to_dispatch_alu_op),
      .i_alusrc(1'b0),
      .i_memwrite(1'b0), // Unused for Branch
      .i_cdb_valid(cdb_valid),
      .i_cdb_prd(cdb_prd),
      
      .i_rs1_ready((skid_to_dispatch_prs1 == 0) || phys_reg_busy[skid_to_dispatch_prs1]),
      .i_rs2_ready((skid_to_dispatch_prs2 == 0) || phys_reg_busy[skid_to_dispatch_prs2]),
      
      .o_full(branch_rs_full),
      .i_eu_ready(1'b1), 
      
      .o_issue_valid(branch_issue_valid),
      .o_issue_prs1(branch_issue_prs1),
      .o_issue_prs2(branch_issue_prs2),
      .o_issue_prd(branch_issue_prd),
      .o_issue_rob_tag(branch_issue_rob_tag),
      .o_issue_imm(branch_issue_imm),
      .o_issue_alu_op(branch_issue_op),
      .o_issue_pc(branch_issue_pc),
      .o_issue_memwrite(), // Unconnected
      
      .branch_mispredict(1'b0)
  );

  // 12. Reservation Station: LSU
  reservation_station #(
      .PREG_WIDTH(7), .ROB_WIDTH(4), .RS_SIZE(8)
  ) rs_lsu_inst (
      .clk(clk), .reset(rst),
      .i_valid(dispatch_alloc_lsu),
      .i_pc({23'b0, skid_to_dispatch_pc}),
      .i_prs1(skid_to_dispatch_prs1), .i_prs2(skid_to_dispatch_prs2), .i_prd(skid_to_dispatch_prd),
      .i_rob_tag(skid_to_dispatch_rob_tag), .i_imm(skid_to_dispatch_immediate), 
      .i_alu_op(skid_to_dispatch_alu_op),
      .i_alusrc(1'b1),
      .i_memwrite(skid_to_dispatch_memwrite), // NEW: Capture MemWrite
      .i_cdb_valid(cdb_valid),
      .i_cdb_prd(cdb_prd),
      
      .i_rs1_ready((skid_to_dispatch_prs1 == 0) || phys_reg_busy[skid_to_dispatch_prs1]),
      .i_rs2_ready((skid_to_dispatch_prs2 == 0) || phys_reg_busy[skid_to_dispatch_prs2]),
      
      .o_full(lsu_rs_full),
      .i_eu_ready(1'b1), 
      
      .o_issue_valid(lsu_issue_valid),
      .o_issue_prs1(lsu_issue_prs1),
      .o_issue_prs2(lsu_issue_prs2),
      .o_issue_prd(lsu_issue_prd),
      .o_issue_rob_tag(lsu_issue_rob_tag),
      .o_issue_imm(lsu_issue_imm),
      .o_issue_alu_op(lsu_issue_op),
      .o_issue_pc(lsu_issue_pc),
      .o_issue_memwrite(lsu_issue_memwrite), // NEW: Issue MemWrite
      
      .branch_mispredict(1'b0)
  );

  // 13. Physical Register File
  physical_register_file #(
      .DATA_WIDTH(32), .PREG_WIDTH(7)
  ) prf_inst (
      .clk(clk),
      .reset(rst),

      // -- Read Ports --
      .alu_prs1_addr(alu_issue_prs1), 
      .alu_prs2_addr(alu_issue_prs2), 
      .alu_prs1_data(alu_op_a),       
      .alu_prs2_data(alu_op_b),       
      
      .br_prs1_addr(branch_issue_prs1), 
      .br_prs2_addr(branch_issue_prs2),
      .br_prs1_data(br_op_a),
      .br_prs2_data(br_op_b),
      
      .lsu_prs1_addr(lsu_issue_prs1),
      .lsu_prs2_addr(lsu_issue_prs2),
      .lsu_prs1_data(lsu_op_a),
      .lsu_prs2_data(lsu_op_b), // This reads the Store Data from PRF

      // -- Write Ports --
      .alu_wb_valid(alu_wb_valid), 
      .alu_wb_dest(alu_wb_dest),   
      .alu_wb_data(alu_wb_data),    
      
      .lsu_wb_valid(lsu_wb_valid),
      .lsu_wb_dest(lsu_wb_dest),
      .lsu_wb_data(lsu_wb_data)
  );

  // 14. ALU Unit
  alu_unit #(
      .DATA_WIDTH(32), .ROB_WIDTH(4), .PREG_WIDTH(7)
  ) alu_instance (
      .i_op1(alu_op_a),            // From PRF
      .i_op2(alu_issue_alusrc ? alu_issue_imm : alu_op_b),            
      
      .i_imm(alu_issue_imm),   
      .i_pc(alu_issue_pc),        
      .i_alu_op(alu_issue_op),     
      .i_valid(alu_issue_valid),   
      .i_prd(alu_issue_prd),       
      .i_rob_tag(alu_issue_rob_tag),
      
      // Outputs
      .o_result(alu_wb_data),      
      .o_prd(alu_wb_dest),         
      .o_rob_tag(alu_cdb_tag),     
      .o_valid(alu_wb_valid)       
  );

  // 15. Branch Unit
  branch_unit #(
      .DATA_WIDTH(32), .ROB_WIDTH(4)
  ) branch_instance (
      .i_op1(br_op_a),             
      .i_op2(br_op_b),             
      .i_pc(branch_issue_pc),      
      .i_imm(branch_issue_imm),    
      .i_funct3(branch_issue_op[2:0]), 
      .i_valid(branch_issue_valid),
      .i_rob_tag(branch_issue_rob_tag),
      
      // Outputs
      .o_valid(branch_wb_valid),   
      .o_rob_tag(branch_cdb_tag),  
      .o_taken(branch_taken),
      .o_target_addr(branch_target_addr),
      .o_mispredict(branch_mispredict)
  );

  // 16. Load Store Unit
  lsu_unit #(
      .DATA_WIDTH(32), .ROB_WIDTH(4), .PREG_WIDTH(7)
  ) lsu_instance (
      .clk(clk),
      .reset(rst),
      .i_base_addr(lsu_op_a),      // From PRF (RS1)
      .i_offset(lsu_issue_imm),    // From RS
      .i_store_data(lsu_op_b),     // NEW: From PRF (RS2 - Store Data)
      .i_memwrite(lsu_issue_memwrite), // NEW: From RS
      
      .i_valid(lsu_issue_valid),   // From RS
      .i_prd(lsu_issue_prd),       // From RS
      .i_rob_tag(lsu_issue_rob_tag),
      
      // Outputs
      .o_data(lsu_wb_data),        
      .o_prd(lsu_wb_dest),         
      .o_rob_tag(lsu_cdb_tag),     
      .o_valid(lsu_wb_valid)       
  );
endmodule