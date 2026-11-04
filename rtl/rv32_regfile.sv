// =============================================================================
// RV32I Register File - 32x32-bit, x0 hardwired to 0
// =============================================================================
`default_nettype none

module rv32_regfile (
    input  logic        clk,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,
    input  logic        wen,
    input  logic [4:0]  raddr_a,
    input  logic [4:0]  raddr_b,
    output logic [31:0] rdata_a,
    output logic [31:0] rdata_b
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clk) begin
        if (wen && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

    always_comb begin
        rdata_a = (raddr_a == 5'd0) ? 32'd0 : regs[raddr_a];
        rdata_b = (raddr_b == 5'd0) ? 32'd0 : regs[raddr_b];
    end

endmodule