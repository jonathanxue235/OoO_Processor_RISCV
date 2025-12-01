module decoder#(
    parameter type T = logic [31:0]
) (
    input T         instruction,
    input logic [8:0] i_pc,
    input logic     i_valid,
    input logic     i_ready,
    output logic    o_ready,
    output logic [8:0] o_pc,
    output logic    o_valid,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd,
    output logic    ALUsrc,
    output logic    Branch,
    output T        immediate,
    output logic [3:0] ALUOp, // CHANGED: Expanded to 4 bits
    output logic [1:0] FUtype,
    output logic    Memread,
    output logic    Memwrite,
    output logic    Regwrite
);
    // ... [Previous signal declarations remain the same] ...
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    assign o_ready = i_ready;
    assign o_valid = i_valid;
    assign o_pc = i_pc;

    // ... [Immediate generation block remains the same] ...
    always_comb begin
        case (opcode)
            7'b0000011, 7'b0010011, 7'b1100111: immediate = {{20{instruction[31]}}, instruction[31:20]};
            7'b0100011: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            7'b1100011: immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            7'b0110111, 7'b0010111: immediate = {instruction[31:12], 12'b0};
            7'b1101111: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            default:    immediate = 32'b0;
        endcase
    end

    // ALU Operation Codes (Must match alu_unit.sv)
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_SLL   = 4'b0010;
    localparam ALU_SLT   = 4'b0011;
    localparam ALU_XOR   = 4'b0100;
    localparam ALU_SRL   = 4'b0101;
    localparam ALU_OR    = 4'b0110;
    localparam ALU_AND   = 4'b0111;
    localparam ALU_LUI   = 4'b1000;
    localparam ALU_AUIPC = 4'b1001;

    // Main Control Logic
    always_comb begin
        // Defaults
        ALUsrc = 0; Branch = 0; ALUOp = ALU_ADD; FUtype = 0;
        Memread = 0; Memwrite = 0; Regwrite = 0;
        rs1 = 0; rs2 = 0; rd = 0;

        case (opcode)
            // R-type ALU
            7'b0110011: begin
                FUtype = 2'b00; // ALU
                Regwrite = 1;
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                rd  = instruction[11:7];
                // Decode specific ALU op
                case (funct3)
                    3'b000: ALUOp = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                    3'b001: ALUOp = ALU_SLL;
                    3'b010: ALUOp = ALU_SLT;
                    3'b100: ALUOp = ALU_XOR;
                    3'b101: ALUOp = ALU_SRL; // SRA not implemented in alu_unit yet
                    3'b110: ALUOp = ALU_OR;
                    3'b111: ALUOp = ALU_AND;
                    default: ALUOp = ALU_ADD;
                endcase
            end

            // I-type ALU
            7'b0010011: begin
                ALUsrc = 1;
                FUtype = 2'b00; // ALU
                Regwrite = 1;
                rs1 = instruction[19:15];
                rd  = instruction[11:7];
                case (funct3)
                    3'b000: ALUOp = ALU_ADD; // ADDI
                    3'b010: ALUOp = ALU_SLT; // SLTI
                    3'b100: ALUOp = ALU_XOR; // XORI
                    3'b110: ALUOp = ALU_OR;  // ORI
                    3'b111: ALUOp = ALU_AND; // ANDI
                    3'b001: ALUOp = ALU_SLL; // SLLI
                    3'b101: ALUOp = ALU_SRL; // SRLI
                    default: ALUOp = ALU_ADD;
                endcase
            end

            // Load
            7'b0000011: begin
                ALUsrc = 1;
                ALUOp = ALU_ADD; // Address Gen
                FUtype = 2'b10; // LSU
                Memread = 1;
                Regwrite = 1;
                rs1 = instruction[19:15];
                rd  = instruction[11:7];
            end

            // Store
            7'b0100011: begin
                ALUsrc = 1;
                ALUOp = ALU_ADD; // Address Gen
                FUtype = 2'b10; // LSU
                Memwrite = 1;
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
            end

            // Branch
            7'b1100011: begin
                Branch = 1;
                FUtype = 2'b01; // Branch Unit
                // ALUOp for Branch unit is somewhat don't care, 
                // but usually we passfunct3 via another path or encode it. 
                // For now, keep as 0 or generic. 
                // Note: Your OoO_top passes 'skid_to_dispatch_alu_op' to Branch RS.
                // We should ensure the branch unit gets the funct3.
                // Your Branch Unit uses 'i_funct3'. 
                // Current OoO_top wires: .i_funct3(branch_issue_op[2:0])
                // So we must pass funct3 in ALUOp [2:0]
                ALUOp = {1'b0, funct3}; 
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
            end

            // LUI
            7'b0110111: begin
                ALUsrc = 1;
                ALUOp = ALU_LUI;
                FUtype = 2'b00;
                Regwrite = 1;
                rd = instruction[11:7];
            end

            // AUIPC
            7'b0010111: begin
                ALUsrc = 1;
                ALUOp = ALU_AUIPC;
                FUtype = 2'b00;
                Regwrite = 1;
                rd = instruction[11:7];
            end

            // JAL
            7'b1101111: begin
                ALUsrc = 1; Branch = 1;
                FUtype = 2'b01; // Branch Unit
                Regwrite = 1;
                rd = instruction[11:7];
            end

            // JALR
            7'b1100111: begin
                ALUsrc = 1; Branch = 1;
                FUtype = 2'b01;
                Regwrite = 1;
                rs1 = instruction[19:15];
                rd  = instruction[11:7];
            end
        endcase
    end
endmodule