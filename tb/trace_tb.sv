module trace_tb;

    parameter type T = logic [31:0];

    // Signals
    logic clk;
    logic rst;

    // DUT Instantiation
    OoO_top #(.T(T)) dut (
        .clk(clk),
        .rst(rst)
    );

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // 1. Trace Loading & Execution Control
    // =========================================================================
    initial begin
        int fd, status;
        logic [7:0] b0, b1, b2, b3; // Byte buffers
        logic [31:0] instr;
        int i;

        $display("=============================================");
        $display("   OoO RISC-V Processor Testbench Setup");
        $display("=============================================");

        // 1. Initialize all instruction memory with NOPs
        $display("[TB] Initializing instruction memory with NOPs...");
        for (i = 0; i < 512; i++) begin 
            dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[i] = 32'h00000013; // NOP
        end
        $display("[TB] Initialized %0d memory locations.", i);

        // 2. Load Instruction Memory from file
        $display("[TB] Loading '25instMem-jswr.txt'...");
        fd = $fopen("25instMem-jswr.txt", "r");
        if (fd == 0) begin
            $display("[TB] Error: Could not open '25instMem-jswr.txt'.");
            $finish;
        end

        i = 0;
        while (!$feof(fd)) begin
            status = $fscanf(fd, "%h\n", b0);
            if (status != 1) break;
            status = $fscanf(fd, "%h\n", b1);
            status = $fscanf(fd, "%h\n", b2);
            status = $fscanf(fd, "%h\n", b3);
            instr = {b3, b2, b1, b0};
            dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[i] = instr;
            i++;
        end
        $fclose(fd);
        $display("[TB] Successfully loaded %0d instructions.", i);

        // 3. Reset Sequence
        $display("[TB] Applying Reset...");
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        $display("[TB] Reset Released. Processor Running...");

        // 4. Execution Phase
        wait_for_pc_overflow();

        // 5. Report Final Results
        report_results();

        $display("[TB] Simulation Finished.");
        $fclose(log_fd);
        $finish;
    end

    // =========================================================================
    // 2. Helper Functions (Disassembler & Registers)
    // =========================================================================
    
    // Helper to format register names
    function string get_reg_name(logic [4:0] r);
        $sformat(get_reg_name, "x%0d", r);
    endfunction

    // RISC-V Disassembler Function
    function string disasm(logic [31:0] instr);
        logic [6:0] opcode = instr[6:0];
        logic [4:0] rd     = instr[11:7];
        logic [2:0] funct3 = instr[14:12];
        logic [4:0] rs1    = instr[19:15];
        logic [4:0] rs2    = instr[24:20];
        logic [6:0] funct7 = instr[31:25];
        logic [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;
        string op_name;

        // Immediate Extraction
        i_imm = {{20{instr[31]}}, instr[31:20]};
        s_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        b_imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        u_imm = {instr[31:12], 12'b0};
        j_imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

        case (opcode)
            7'b0110011: begin // R-Type
                case (funct3)
                    3'b000: op_name = (funct7[5]) ? "SUB" : "ADD";
                    3'b001: op_name = "SLL";
                    3'b010: op_name = "SLT";
                    3'b011: op_name = "SLTU";
                    3'b100: op_name = "XOR";
                    3'b101: op_name = (funct7[5]) ? "SRA" : "SRL";
                    3'b110: op_name = "OR";
                    3'b111: op_name = "AND";
                    default: op_name = "UNK_R";
                endcase
                return $sformatf("%s %s, %s, %s", op_name, get_reg_name(rd), get_reg_name(rs1), get_reg_name(rs2));
            end
            7'b0010011: begin // I-Type ALU
                case (funct3)
                    3'b000: op_name = "ADDI";
                    3'b010: op_name = "SLTI";
                    3'b011: op_name = "SLTIU";
                    3'b100: op_name = "XORI";
                    3'b110: op_name = "ORI";
                    3'b111: op_name = "ANDI";
                    3'b001: op_name = "SLLI";
                    3'b101: op_name = (instr[30]) ? "SRAI" : "SRLI";
                    default: op_name = "UNK_I";
                endcase
                if (funct3 == 3'b001 || funct3 == 3'b101)
                    return $sformatf("%s %s, %s, %0d", op_name, get_reg_name(rd), get_reg_name(rs1), rs2);
                else
                    return $sformatf("%s %s, %s, %0d", op_name, get_reg_name(rd), get_reg_name(rs1), $signed(i_imm));
            end
            7'b0000011: begin // Load
                case (funct3)
                    3'b000: op_name = "LB";
                    3'b001: op_name = "LH";
                    3'b010: op_name = "LW";
                    3'b100: op_name = "LBU";
                    3'b101: op_name = "LHU";
                    default: op_name = "UNK_L";
                endcase
                return $sformatf("%s %s, %0d(%s)", op_name, get_reg_name(rd), $signed(i_imm), get_reg_name(rs1));
            end
            7'b0100011: begin // Store
                case (funct3)
                    3'b000: op_name = "SB";
                    3'b001: op_name = "SH";
                    3'b010: op_name = "SW";
                    default: op_name = "UNK_S";
                endcase
                return $sformatf("%s %s, %0d(%s)", op_name, get_reg_name(rs2), $signed(s_imm), get_reg_name(rs1));
            end
            7'b1100011: begin // Branch
                case (funct3)
                    3'b000: op_name = "BEQ";
                    3'b001: op_name = "BNE";
                    3'b100: op_name = "BLT";
                    3'b101: op_name = "BGE";
                    3'b110: op_name = "BLTU";
                    3'b111: op_name = "BGEU";
                    default: op_name = "UNK_B";
                endcase
                return $sformatf("%s %s, %s, %0d", op_name, get_reg_name(rs1), get_reg_name(rs2), $signed(b_imm));
            end
            7'b0110111: return $sformatf("LUI %s, 0x%h", get_reg_name(rd), u_imm[31:12]);
            7'b0010111: return $sformatf("AUIPC %s, 0x%h", get_reg_name(rd), u_imm[31:12]);
            7'b1101111: return $sformatf("JAL %s, %0d", get_reg_name(rd), $signed(j_imm));
            7'b1100111: return $sformatf("JALR %s, %0d(%s)", get_reg_name(rd), $signed(i_imm), get_reg_name(rs1));
            7'b0000000: return "BUBBLE";
            32'h00000013: return "NOP";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Function to retrieve architectural register value from PRF
    function logic [31:0] get_reg_value(int reg_idx);
        logic [6:0] phys_reg_idx;
        phys_reg_idx = dut.rename_inst.u_map_table.map_table[reg_idx];
        if (phys_reg_idx == 0) return 32'h0;
        return dut.prf_inst.registers[phys_reg_idx];
    endfunction

    // =========================================================================
    // 3. Logging and Monitoring
    // =========================================================================
    integer log_fd;
    initial begin
        log_fd = $fopen("processor_state.log", "w");
        if (log_fd == 0) $display("Error opening log file.");

        // Header
        $fwrite(log_fd, "               Time  | Fetch | Fetch Instr               | Decod | Renam | Dispt | ALU   | Br    | LSU   | WB    | Commt |");
        for (int i = 0; i < 32; i++) begin
            // CHANGED: Added one space to match data width of 11 chars
            $fwrite(log_fd, " x%02d      |", i);
        end
        $fwrite(log_fd, "\n");

        // Separator
        $fwrite(log_fd, "---------------------+-------+---------------------------+-------+-------+-------+-------+-------+-------+-------+-------+");
        for (int i = 0; i < 32; i++) begin
            // CHANGED: Added two dashes to match data width of 11 chars
            $fwrite(log_fd, "----------+");
        end
        $fwrite(log_fd, "\n");
    end

    // Log processor state every cycle
    always @(posedge clk) begin
        if (!rst) begin
            logic [31:0] fetch_pc, decode_pc, rename_pc, dispatch_pc;
            logic [31:0] alu_pc, br_pc, lsu_pc, wb_pc, commit_pc;
            string fetch_instr_str;

            // --- Pipeline Stage PCs ---
            fetch_pc    = dut.fetch_to_skid_valid    ? {23'b0, dut.fetch_to_skid_pc}    : 32'b0;
            decode_pc   = dut.decode_to_skid_valid   ? {23'b0, dut.decode_to_skid_pc}   : 32'b0;
            rename_pc   = dut.rename_to_skid_valid   ? {23'b0, dut.rename_to_skid_pc}   : 32'b0;
            dispatch_pc = dut.skid_to_dispatch_valid ? {23'b0, dut.skid_to_dispatch_pc} : 32'b0;

            // --- Decode Fetch Instruction ---
            if (dut.fetch_to_skid_valid) begin
                fetch_instr_str = disasm(dut.fetch_to_skid_instr);
            end else begin
                fetch_instr_str = "-";
            end

            // --- Functional Units (Issue) ---
            alu_pc      = dut.alu_issue_valid    ? dut.alu_issue_pc    : 32'b0;
            br_pc       = dut.branch_issue_valid ? dut.branch_issue_pc : 32'b0;
            lsu_pc      = dut.lsu_issue_valid    ? dut.lsu_issue_pc    : 32'b0; 

            // --- Writeback & Commit ---
            if (dut.cdb_valid) 
                wb_pc = dut.rob_inst.rob_mem[dut.cdb_tag].pc;
            else 
                wb_pc = 32'b0;

            if (dut.commit_valid) 
                commit_pc = dut.rob_inst.rob_mem[dut.commit_tag].pc;
            else 
                commit_pc = 32'b0;

            // --- Write to Log ---
            // Data format for registers is " %8h |" (11 chars)
            $fwrite(log_fd, "%5t |  %03h  | %-25s |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |",
                $time,
                fetch_pc[8:0], fetch_instr_str,   
                decode_pc[8:0],   
                rename_pc[8:0],   
                dispatch_pc[8:0], 
                alu_pc[8:0],      
                br_pc[8:0],       
                lsu_pc[8:0],      
                wb_pc[8:0],       
                commit_pc[8:0]    
            );

            // Write Register Values
            for (int i = 0; i < 32; i++) begin
                $fwrite(log_fd, " %8h |", get_reg_value(i));
            end
            $fwrite(log_fd, "\n");
        end
    end

    // =========================================================================
    // 4. Tasks (Overflow Wait & Reporting)
    // =========================================================================
    
    task wait_for_pc_overflow();
        logic [8:0] prev_pc;
        int timeout_cycles = 0;
        int max_cycles = 10000;

        $display("[TB] Waiting for PC to become non-zero...");
        while (dut.fetch_to_cache_pc == 9'h000 && timeout_cycles < max_cycles) begin
            @(posedge clk);
            timeout_cycles++;
        end

        if (timeout_cycles >= max_cycles) begin
            $display("[TB] ERROR: Timeout waiting for start!");
            $finish;
        end

        $display("[TB] Started at 0x%h. Waiting for overflow back to 000...", dut.fetch_to_cache_pc);
        prev_pc = dut.fetch_to_cache_pc;
        timeout_cycles = 0;
        while (timeout_cycles < max_cycles) begin
            @(posedge clk);
            if (dut.fetch_to_cache_pc == 9'h000 && prev_pc != 9'h000) begin
                $display("[TB] PC overflow detected at %0t.", $time);
                repeat(50) @(posedge clk);
                return;
            end
            prev_pc = dut.fetch_to_cache_pc;
            timeout_cycles++;
        end
        $display("[TB] ERROR: Timeout waiting for overflow!");
        $finish;
    endtask

    task report_results();
        logic [31:0] reg_value;
        $display("\n=============================================");
        $display("FINAL EXECUTION RESULTS - Register Values");
        $display("=============================================");
        for (int i = 0; i < 32; i++) begin
            reg_value = get_reg_value(i);
            if (i % 4 == 0 && i != 0) $display("");
            $display("x%-2d: 0x%08h (%0d)", i, reg_value, $signed(reg_value));
        end
        $display("=============================================");
        $display("Log file 'processor_state.log' generated.");
    endtask

endmodule