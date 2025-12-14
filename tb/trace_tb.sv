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
        // 1. Initialize all instruction memory with NOP instructions
        $display("[TB] Initializing instruction memory with NOPs...");
        for (i = 0; i < 512; i++) begin // 9-bit address space = 512 locations
            dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[i] = 32'h00000013;
            // NOP
        end
        $display("[TB] Initialized %0d memory locations with NOP (0x00000013).", i);
        // 2. Load Instruction Memory
        $display("[TB] Loading '25instMem-test.txt'...");
        fd = $fopen("25instMem-test.txt", "r");
        if (fd == 0) begin
            $display("[TB] Error: Could not open '25instMem-test.txt'. Make sure the file is in the simulation directory.");
            $finish;
        end

        i = 0;
        while (!$feof(fd)) begin
            // Read 4 bytes (lines) to form one 32-bit instruction
            // RISC-V is Little Endian: LSB is at the lowest address
            status = $fscanf(fd, "%h\n", b0);
            if (status != 1) break; // Stop if EOF hit mid-instruction
            status = $fscanf(fd, "%h\n", b1);
            status = $fscanf(fd, "%h\n", b2);
            status = $fscanf(fd, "%h\n", b3);
            // Assemble Word: {Byte3, Byte2, Byte1, Byte0}
            instr = {b3, b2, b1, b0};
            // Write to mock memory
            // Note: addra in OoO_top is [8:0], addressing 32-bit words.
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

        // 4. Execution Phase - Wait for PC to wrap back to 000
        // This indicates the program has completed and wrapped around
        wait_for_pc_overflow();
        // 5. Report Final Results
        report_results();

        $display("[TB] Simulation Finished.");
        $fclose(log_fd);
        $finish;
    end

    // =========================================================================
    // 2. Logging and Monitoring
    // =========================================================================
    integer log_fd;
    initial begin
        log_fd = $fopen("processor_state.log", "w");
        if (log_fd == 0) $display("Error opening log file.");

        // Write header with detailed Pipeline Stages and Registers
        $fwrite(log_fd, "Time  | Fetch | Decod | Renam | Dispt | ALU   | Br    | LSU   | WB    | Commt |");
        for (int i = 0; i < 32; i++) begin
            $fwrite(log_fd, " x%02d     |", i);
        end
        $fwrite(log_fd, "\n");
        // Write separator line
        $fwrite(log_fd, "------+-------+-------+-------+-------+-------+-------+-------+-------+-------+");
        for (int i = 0; i < 32; i++) begin
            $fwrite(log_fd, "--------+");
        end
        $fwrite(log_fd, "\n");
    end

    // Log processor state every cycle
    always @(posedge clk) begin
        if (!rst) begin
            // -----------------------------------------------------------
            // Helper logic to get PCs only when valid (otherwise 0 or X)
            // -----------------------------------------------------------
            logic [31:0] fetch_pc, decode_pc, rename_pc, dispatch_pc;
            logic [31:0] alu_pc, br_pc, lsu_pc, wb_pc, commit_pc;

            // Pipeline Stage PCs (Mask with Valid bit for cleaner logs)
            fetch_pc    = dut.fetch_to_skid_valid    ? {23'b0, dut.fetch_to_skid_pc}    : 32'b0;
            decode_pc   = dut.decode_to_skid_valid   ? {23'b0, dut.decode_to_skid_pc}   : 32'b0;
            rename_pc   = dut.rename_to_skid_valid   ? {23'b0, dut.rename_to_skid_pc}   : 32'b0;
            dispatch_pc = dut.skid_to_dispatch_valid ? {23'b0, dut.skid_to_dispatch_pc} : 32'b0;

            // Functional Unit PCs (Issue Stage)
            alu_pc      = dut.alu_issue_valid        ? dut.alu_issue_pc    : 32'b0;
            br_pc       = dut.branch_issue_valid     ? dut.branch_issue_pc : 32'b0;
            // LSU PC comes from the dispatch skid buffer because LSU RS is opaque in top level
            // But we can peek at the signal wired to the LSU unit:
            lsu_pc      = dut.lsu_issue_valid        ? dut.lsu_issue_pc    : 32'b0; 

            // Writeback PC: Look up the ROB using the CDB Tag
            if (dut.cdb_valid) begin
                // Accessing internal ROB memory to get PC associated with the tag
                wb_pc = dut.rob_inst.rob_mem[dut.cdb_tag].pc; 
            end else begin
                wb_pc = 32'b0;
            end

            // Commit PC: Look up the ROB using the Commit Tag
            if (dut.commit_valid) begin
                commit_pc = dut.rob_inst.rob_mem[dut.commit_tag].pc;
            end else begin
                commit_pc = 32'b0;
            end

            // -----------------------------------------------------------
            // Write to Log
            // -----------------------------------------------------------
            $fwrite(log_fd, "%5t |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |  %03h  |",
                $time,
                fetch_pc[8:0],    
                decode_pc[8:0],   
                rename_pc[8:0],   
                dispatch_pc[8:0], 
                alu_pc[8:0],      
                br_pc[8:0],       
                lsu_pc[8:0],      
                wb_pc[8:0],       
                commit_pc[8:0]    
            );

            // Write all 32 register values
            for (int i = 0; i < 32; i++) begin
                $fwrite(log_fd, " %8h |", get_reg_value(i));
            end
            $fwrite(log_fd, "\n");
        end
    end

    // =========================================================================
    // 3. Helper Tasks & Functions
    // =========================================================================

    // Task to wait for PC to overflow back to 000
    task wait_for_pc_overflow();
        logic [8:0] prev_pc;
        int timeout_cycles;
        int max_cycles = 10000; // Safety timeout

        $display("[TB] Waiting for PC to become non-zero...");
        // First, wait for PC to leave 000 (start of execution)
        timeout_cycles = 0;
        while (dut.fetch_to_cache_pc == 9'h000 && timeout_cycles < max_cycles) begin
            @(posedge clk);
            timeout_cycles++;
        end

        if (timeout_cycles >= max_cycles) begin
            $display("[TB] ERROR: Timeout waiting for PC to start execution!");
            $finish;
        end

        $display("[TB] PC started execution at 0x%h. Waiting for overflow back to 000...", dut.fetch_to_cache_pc);
        // Now wait for PC to return to 000 (overflow/wrap-around)
        timeout_cycles = 0;
        prev_pc = dut.fetch_to_cache_pc;
        while (timeout_cycles < max_cycles) begin
            @(posedge clk);
            if (dut.fetch_to_cache_pc == 9'h000 && prev_pc != 9'h000) begin
                $display("[TB] PC overflow detected at time %0t! PC wrapped from 0x%h to 0x000", $time, prev_pc);
                // Wait a few more cycles for pipeline to drain
                repeat(50) @(posedge clk);
                return;
            end
            prev_pc = dut.fetch_to_cache_pc;
            timeout_cycles++;
        end

        $display("[TB] ERROR: Timeout waiting for PC overflow! Last PC = 0x%h", dut.fetch_to_cache_pc);
        $finish;
    endtask

    // Function to retrieve architectural register value from the design
    // It traverses the Map Table to find the physical register, then reads the PRF.
    function logic [31:0] get_reg_value(int reg_idx);
        logic [6:0] phys_reg_idx;
        
        // 1. Look up Physical Register Index in Map Table
        // Path: dut -> rename module -> map_table module -> map_table array
        phys_reg_idx = dut.rename_inst.u_map_table.map_table[reg_idx];
        // 2. Handle x0 (Always 0)
        if (phys_reg_idx == 0) return 32'h0;
        // 3. Read Value from Physical Register File
        // Path: dut -> prf module -> registers array
        return dut.prf_inst.registers[phys_reg_idx];
    endfunction

    // Task to display final results
    task report_results();
        logic [31:0] reg_value;

        $display("\n=============================================");
        $display("FINAL EXECUTION RESULTS - Register Values");
        $display("=============================================");

        // Display all 32 registers in a formatted table
        for (int i = 0; i < 32; i++) begin
            reg_value = get_reg_value(i);
            if (i % 4 == 0 && i != 0) $display(""); // Blank line every 4 registers
            $display("x%-2d: 0x%08h (%0d)", i, reg_value, $signed(reg_value));
        end

        $display("=============================================");
        $display("Log file 'processor_state.log' generated.");
    endtask

endmodule