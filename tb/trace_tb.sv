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
            dut.instruction_memory.inst.native_mem_module.blk_mem_gen_v8_4_11_inst.memory[i] = 32'h00000013; // NOP
        end
        $display("[TB] Initialized %0d memory locations with NOP (0x00000013).", i);

        // 2. Load Instruction Memory
        $display("[TB] Loading '25instMem-jswr.txt'...");
        fd = $fopen("25instMem-jswr.txt", "r");

        if (fd == 0) begin
            $display("[TB] Error: Could not open '25instMem-r.txt'. Make sure the file is in the simulation directory.");
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
        
        $fwrite(log_fd, "Time  | FetchPC | DispValid | ROB_Head | ROB_Count | Commit | CommitTag | x10 (a0) | x11 (a1)\n");
        $fwrite(log_fd, "------+---------+-----------+----------+-----------+--------+-----------+----------+----------\n");
    end

    // Log processor state every cycle
    always @(posedge clk) begin
        if (!rst) begin
            $fwrite(log_fd, "%5t |   %3h   |     %1b     |    %2d    |     %2d    |   %1b    |    %2d     | %8h | %8h\n",
                $time,
                dut.fetch_to_cache_pc,          // Current PC being fetched
                dut.skid_to_dispatch_valid,     // Dispatch Valid Signal
                dut.rob_inst.head_ptr,          // ROB Head (Commit Pointer)
                dut.rob_inst.count,             // Active Instructions in ROB
                dut.commit_valid,               // Commit Valid Signal
                dut.commit_tag,                 // Tag of committing instruction
                get_reg_value(10),              // Value of a0
                get_reg_value(11)               // Value of a1
            );
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
        logic [31:0] val_a0, val_a1;
        
        val_a0 = get_reg_value(10); // x10
        val_a1 = get_reg_value(11); // x11

        $display("\n=============================================");
        $display("FINAL EXECUTION RESULTS");
        $display("=============================================");
        $display("Register a0 (x10): Hex = 0x%h | Dec = %0d", val_a0, $signed(val_a0));
        $display("Register a1 (x11): Hex = 0x%h | Dec = %0d", val_a1, $signed(val_a1));
        $display("=============================================");
        $display("Log file 'processor_state.log' generated.");
    endtask

endmodule
