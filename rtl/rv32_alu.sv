// =============================================================================
// RV32I ALU - 5-bit operation code
// =============================================================================
`default_nettype none

module rv32_alu (
    input  logic [4:0] op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result,
    output logic        zero
);

    localparam logic [4:0] ALU_ADD  = 5'd0;
    localparam logic [4:0] ALU_SUB  = 5'd1;
    localparam logic [4:0] ALU_SLL  = 5'd2;
    localparam logic [4:0] ALU_SLT  = 5'd3;
    localparam logic [4:0] ALU_SLTU = 5'd4;
    localparam logic [4:0] ALU_XOR  = 5'd5;
    localparam logic [4:0] ALU_SRL  = 5'd6;
    localparam logic [4:0] ALU_SRA  = 5'd7;
    localparam logic [4:0] ALU_OR   = 5'd8;
    localparam logic [4:0] ALU_AND  = 5'd9;
    localparam logic [4:0] ALU_PASSB = 5'd10;

    logic [31:0] alu_out;

    always_comb begin
        case (op)
            ALU_ADD:   alu_out = a + b;
            ALU_SUB:   alu_out = a - b;
            ALU_SLL:   alu_out = a << b[4:0];
            ALU_SLT:   alu_out = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU:  alu_out = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:   alu_out = a ^ b;
            ALU_SRL:   alu_out = a >> b[4:0];
            ALU_SRA:   alu_out = $signed(a) >>> b[4:0];
            ALU_OR:    alu_out = a | b;
            ALU_AND:   alu_out = a & b;
            ALU_PASSB: alu_out = b;
            default:   alu_out = 32'd0;
        endcase
    end

    assign result = alu_out;
    assign zero   = (alu_out == 32'd0);

endmodule