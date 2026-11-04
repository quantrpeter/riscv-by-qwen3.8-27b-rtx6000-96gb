// =============================================================================
// Testbench for RV32I Soft Core
// =============================================================================
`default_nettype none

module tb_rv32_core;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Core interfaces
    logic [31:0] imem_addr;
    logic [31:0] imem_data;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_we;
    logic [3:0]  dmem_be;
    logic [31:0] dmem_rdata;
    logic [31:0] pc_out;

    // Memory models
    logic [31:0] imem [0:255];
    logic [31:0] dmem [0:255];

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    // DUT instantiation
    rv32_core dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .imem_addr (imem_addr),
        .imem_data (imem_data),
        .dmem_addr (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we  (dmem_we),
        .dmem_be  (dmem_be),
        .dmem_rdata (dmem_rdata),
        .pc_out   (pc_out)
    );

    // Instruction memory (combinational read)
    /* verilator lint_off WIDTHEXPAND */
    assign imem_data = imem[imem_addr[8:2]];

    // Data memory model
    always_comb begin
        dmem_rdata = dmem[dmem_addr[8:2]];
    end

    always_ff @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_be[0]) dmem[dmem_addr[8:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_be[1]) dmem[dmem_addr[8:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_be[2]) dmem[dmem_addr[8:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) dmem[dmem_addr[8:2]][31:24] <= dmem_wdata[31:24];
        end
    end
    /* verilator lint_on WIDTHEXPAND */

    // Load test program into instruction memory
    initial begin
        for (int i = 0; i < 256; i++) imem[i] = 32'h0000_0013; // NOPs

        // Test program
        imem[0]  = 32'h00A00093;  // addi x1, x0, 10
        imem[1]  = 32'h01400113;  // addi x2, x0, 20
        imem[2]  = 32'h002081B3;  // add  x3, x1, x2      (x3 = 30)
        imem[3]  = 32'hFFB18213;  // addi x4, x3, -5      (x4 = 25)
        imem[4]  = 32'h0020B2B3;  // and  x5, x1, x2      (x5 = 8)
        imem[5]  = 32'h0011E333;  // or   x6, x3, x1      (x6 = 30)
        imem[6]  = 32'h0011C3B3;  // xor  x7, x3, x1      (x7 = 20)
        imem[7]  = 32'h00300023;  // sw   x3, 0(x0)
        imem[8]  = 32'h00002403;  // lw   x8, 0(x0)       (x8 = 30)
        imem[9]  = 32'h00100293;  // addi x5, x0, 1       (halt - x5=1)

        // Initialize data memory to 0
        for (int i = 0; i < 256; i++) dmem[i] = 32'd0;
    end

    // Monitor
    integer errors;
    initial begin
        // Wait for reset to complete
        @(posedge rst_n);
        // Wait 40 cycles (plenty for 10 instructions + pipeline fill)
        repeat (40) @(posedge clk);

        // Check results
        $display("========================================");
        $display("RV32I Soft Core - Test Results");
        $display("========================================");
        $display("x1  = %0d (expected 10)", dut.u_regfile.regs[1]);
        $display("x2  = %0d (expected 20)", dut.u_regfile.regs[2]);
        $display("x3  = %0d (expected 30)", dut.u_regfile.regs[3]);
        $display("x4  = %0d (expected 25)", dut.u_regfile.regs[4]);
        $display("x5  = %0d (expected 1)",  dut.u_regfile.regs[5]);
        $display("x6  = %0d (expected 30)", dut.u_regfile.regs[6]);
        $display("x7  = %0d (expected 20)", dut.u_regfile.regs[7]);
        $display("x8  = %0d (expected 30)", dut.u_regfile.regs[8]);
        $display("dmem[0] = %0d", dmem[0]);
        $display("========================================");

        // Assertions
        if (dut.u_regfile.regs[1] != 32'd10) begin
            $display("FAIL: x1");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[2] != 32'd20) begin
            $display("FAIL: x2");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[3] != 32'd30) begin
            $display("FAIL: x3");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[4] != 32'd25) begin
            $display("FAIL: x4");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[6] != 32'd30) begin
            $display("FAIL: x6");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[7] != 32'd20) begin
            $display("FAIL: x7");
            errors = errors + 1;
        end
        if (dut.u_regfile.regs[8] != 32'd30) begin
            $display("FAIL: x8");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("%0d TESTS FAILED", errors);

        $finish;
    end

    // Timeout
    initial begin
        #100000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule