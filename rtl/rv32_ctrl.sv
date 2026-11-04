// =============================================================================
// RV32I Control Unit
// =============================================================================
`default_nettype none

`default_nettype none

module rv32_ctrl (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic [4:0] alu_op,
    output logic       reg_we,
    output logic [1:0] reg_wsrc,   // 0=ALU, 1=MEM, 2=PC+4
    output logic       mem_we,
    output logic       mem_re,
    output logic [1:0] mem_size,   // 0=byte, 1=half, 2=word
    output logic       is_branch,
    output logic       is_jal,
    output logic       is_jalr,
    output logic       is_load
);

    localparam logic [6:0] OP_LUI     = 7'b0110111;
    localparam logic [6:0] OP_AUIPC   = 7'b0010111;
    localparam logic [6:0] OP_JAL     = 7'b1101111;
    localparam logic [6:0] OP_JALR    = 7'b1100111;
    localparam logic [6:0] OP_BRANCH  = 7'b1100011;
    localparam logic [6:0] OP_LOAD    = 7'b0000011;
    localparam logic [6:0] OP_STORE   = 7'b0100011;
    localparam logic [6:0] OP_OP      = 7'b0110011;
    localparam logic [6:0] OP_OP_IMM  = 7'b0010011;

    // ALU op encoding
    localparam logic [4:0] ALU_ADD   = 5'd0;
    localparam logic [4:0] ALU_SUB   = 5'd1;
    localparam logic [4:0] ALU_SLL   = 5'd2;
    localparam logic [4:0] ALU_SLT   = 5'd3;
    localparam logic [4:0] ALU_SLTU  = 5'd4;
    localparam logic [4:0] ALU_XOR   = 5'd5;
    localparam logic [4:0] ALU_SRL   = 5'd6;
    localparam logic [4:0] ALU_SRA   = 5'd7;
    localparam logic [4:0] ALU_OR    = 5'd8;
    localparam logic [4:0] ALU_AND   = 5'd9;
    localparam logic [4:0] ALU_PASSB = 5'd10;

    always_comb begin
        alu_op   = ALU_ADD;
        reg_we   = 1'b0;
        reg_wsrc = 2'd0;
        mem_we   = 1'b0;
        mem_re   = 1'b0;
        mem_size = 2'd2;
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;
        is_load   = 1'b0;

        case (opcode)
            OP_LUI: begin
                alu_op   = ALU_PASSB;
                reg_we   = 1'b1;
                reg_wsrc = 2'd0;
            end

            OP_AUIPC: begin
                alu_op   = ALU_ADD;
                reg_we   = 1'b1;
                reg_wsrc = 2'd0;
            end

            OP_JAL: begin
                alu_op   = ALU_ADD;
                reg_we   = 1'b1;
                reg_wsrc = 2'd2;  // write PC+4
                is_jal   = 1'b1;
            end

            OP_JALR: begin
                alu_op   = ALU_ADD;
                reg_we   = 1'b1;
                reg_wsrc = 2'd2;  // write PC+4
                is_jalr  = 1'b1;
            end

            OP_BRANCH: begin
                alu_op   = ALU_ADD;  // result unused, use comparator
                reg_we   = 1'b0;
                is_branch = 1'b1;
            end

            OP_LOAD: begin
                alu_op   = ALU_ADD;
                mem_re   = 1'b1;
                reg_we   = 1'b1;
                reg_wsrc = 2'd1;  // write memory data
                is_load  = 1'b1;
                case (funct3)
                    3'b000: mem_size = 2'd0;
                    3'b001: mem_size = 2'd1;
                    3'b010: mem_size = 2'd2;
                    3'b100: mem_size = 2'd0;
                    3'b101: mem_size = 2'd1;
                    default: mem_size = 2'd2;
                endcase
            end

            OP_STORE: begin
                alu_op   = ALU_ADD;
                mem_we   = 1'b1;
                mem_size = funct3[1:0];
            end

            OP_OP: begin
                reg_we   = 1'b1;
                reg_wsrc = 2'd0;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end

            OP_OP_IMM: begin
                reg_we   = 1'b1;
                reg_wsrc = 2'd0;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end

            default: begin
                alu_op   = ALU_ADD;
                reg_we   = 1'b0;
            end
        endcase
    end

endmodule