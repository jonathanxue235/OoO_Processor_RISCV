module decoder#(
    parameter type T = logic [31:0]
) (
    input T         instruction,
    input logic [8:0] i_pc,
    input logic     i_valid,

    input logic i_ready,

    // Back to fetch skid buffer
    output logic    o_ready,

    // To rename stage skid buffer
    output logic [8:0] o_pc,
    output logic o_valid,


    // Add more signals here as needed
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,
    output logic ALUsrc,
    output logic Branch,
    output T immediate,
    output logic [1:0] ALUOp,
    output logic [1:0] FUtype, // 0 for ALU, 1 for Branch, 2 for LSU
    output logic Memread,
    output logic Memwrite,
    output logic Regwrite
);

    // Extract opcode and funct fields
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // Extract register fields
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd  = instruction[11:7];

    // Pass through control signals (purely combinational)
    assign o_ready = i_ready;
    assign o_valid = i_valid;
    assign o_pc = i_pc;

    // Decode immediate values based on instruction type
    always_comb begin
        case (opcode)
            // I-type (load, JALR, immediate ALU operations)
            7'b0000011, // Load
            7'b0010011, // ALU immediate
            7'b1100111: // JALR
                immediate = {{20{instruction[31]}}, instruction[31:20]};

            // S-type (store)
            7'b0100011:
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type (branch)
            7'b1100011:
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                            instruction[30:25], instruction[11:8], 1'b0};

            // U-type (LUI, AUIPC)
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                immediate = {instruction[31:12], 12'b0};

            // J-type (JAL)
            7'b1101111:
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                            instruction[20], instruction[30:21], 1'b0};

            default:
                immediate = 32'b0;
        endcase
    end

    // Generate control signals
    always_comb begin
        // Default values
        ALUsrc = 1'b0;
        Branch = 1'b0;
        ALUOp = 2'b00;
        FUtype = 2'b00;  // ALU
        Memread = 1'b0;
        Memwrite = 1'b0;
        Regwrite = 1'b0;

        case (opcode)
            // R-type ALU operations
            7'b0110011: begin
                ALUsrc = 1'b0;      // Use rs2
                Branch = 1'b0;
                ALUOp = 2'b10;      // R-type ALU operation
                FUtype = 2'b00;     // ALU
                Regwrite = 1'b1;    // Write to rd
            end

            // I-type ALU operations (immediate)
            7'b0010011: begin
                ALUsrc = 1'b1;      // Use immediate
                Branch = 1'b0;
                ALUOp = 2'b10;      // I-type ALU operation
                FUtype = 2'b00;     // ALU
                Regwrite = 1'b1;    // Write to rd
            end

            // Load instructions
            7'b0000011: begin
                ALUsrc = 1'b1;      // Use immediate for address calculation
                Branch = 1'b0;
                ALUOp = 2'b00;      // Add for address calculation
                FUtype = 2'b10;     // LSU
                Memread = 1'b1;     // Read from memory
                Regwrite = 1'b1;    // Write to rd
            end

            // Store instructions
            7'b0100011: begin
                ALUsrc = 1'b1;      // Use immediate for address calculation
                Branch = 1'b0;
                ALUOp = 2'b00;      // Add for address calculation
                FUtype = 2'b10;     // LSU
                Memwrite = 1'b1;    // Write to memory
                Regwrite = 1'b0;    // No register write
            end

            // Branch instructions
            7'b1100011: begin
                ALUsrc = 1'b0;      // Use rs2 for comparison
                Branch = 1'b1;      // Branch instruction
                ALUOp = 2'b01;      // Branch comparison
                FUtype = 2'b01;     // Branch unit
                Regwrite = 1'b0;    // No register write
            end

            // LUI (Load Upper Immediate)
            7'b0110111: begin
                ALUsrc = 1'b1;      // Use immediate
                Branch = 1'b0;
                ALUOp = 2'b11;      // Pass immediate
                FUtype = 2'b00;     // ALU
                Regwrite = 1'b1;    // Write to rd
            end

            // AUIPC (Add Upper Immediate to PC)
            7'b0010111: begin
                ALUsrc = 1'b1;      // Use immediate
                Branch = 1'b0;
                ALUOp = 2'b00;      // Add (PC + immediate)
                FUtype = 2'b00;     // ALU
                Regwrite = 1'b1;    // Write to rd
            end

            // JAL (Jump and Link)
            7'b1101111: begin
                ALUsrc = 1'b1;      // Use immediate
                Branch = 1'b1;      // Unconditional jump
                ALUOp = 2'b00;      // Add for PC calculation
                FUtype = 2'b01;     // Branch unit
                Regwrite = 1'b1;    // Write return address to rd
            end

            // JALR (Jump and Link Register)
            7'b1100111: begin
                ALUsrc = 1'b1;      // Use immediate
                Branch = 1'b1;      // Unconditional jump
                ALUOp = 2'b00;      // Add for target calculation
                FUtype = 2'b01;     // Branch unit
                Regwrite = 1'b1;    // Write return address to rd
            end

            default: begin
                // Keep default values for unknown instructions
            end
        endcase
    end

endmodule