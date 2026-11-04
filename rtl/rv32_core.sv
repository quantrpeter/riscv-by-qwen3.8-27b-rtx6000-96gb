// =============================================================================
// RV32I Soft Core - 5-Stage Pipeline (IF, ID, EX, MEM, WB)
// With forwarding and load-use hazard detection
// =============================================================================
`default_nettype none

module rv32_core (
    input  logic        clk,
    input  logic        rst_n,
    // Instruction memory (combinational read)
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_data,
    // Data memory
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_we,
    output logic [3:0]  dmem_be,
    input  logic [31:0] dmem_rdata,
    // Status
    output logic [31:0] pc_out
);

    // =========================================================================
    // IF Stage
    // =========================================================================
    logic [31:0] if_pc;
    logic [31:0] if_pc4;
    logic [31:0] if_instr;

    assign imem_addr = if_pc;
    assign if_instr  = imem_data;
    assign if_pc4    = if_pc + 32'd4;

    // =========================================================================
    // IF/ID Pipeline Register
    // =========================================================================
    logic [31:0] id_pc;
    logic [31:0] id_pc4;
    logic [31:0] id_instr;

    // Hazard / flush signals
    logic       stall;
    logic       flush_id;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            id_pc    <= 32'd0;
            id_pc4   <= 32'd4;
            id_instr <= 32'd0;
        end else if (flush_id) begin
            id_instr <= 32'h0000_0013; // NOP: addi x0,x0,0
        end else begin
            id_pc    <= if_pc;
            id_pc4   <= if_pc4;
            id_instr <= if_instr;
        end
    end

    // =========================================================================
    // ID Stage - Decode
    // =========================================================================
    logic [6:0]  id_opcode;
    logic [4:0]  id_rd;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [31:0] id_imm;
    logic [31:0] id_reg1;
    logic [31:0] id_reg2;

    assign id_opcode = id_instr[6:0];
    assign id_rd     = id_instr[11:7];
    assign id_funct3 = id_instr[14:12];
    assign id_rs1    = id_instr[19:15];
    assign id_rs2    = id_instr[24:20];
    assign id_funct7 = id_instr[31:25];

    // Immediate generation
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    assign imm_i = {{20{id_instr[31]}}, id_instr[31:20]};
    assign imm_s = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
    assign imm_b = {{19{id_instr[31]}}, id_instr[31], id_instr[30:25], id_instr[11:8], id_instr[7], 1'b0};
    assign imm_u = {id_instr[31:12], 12'b0};
    assign imm_j = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};

    always_comb begin
        case (id_opcode)
            7'b0110111: id_imm = imm_u;   // LUI
            7'b0010111: id_imm = imm_u;   // AUIPC
            7'b1101111: id_imm = imm_j;   // JAL
            7'b1100111: id_imm = imm_i;   // JALR
            7'b1100011: id_imm = imm_b;   // BRANCH
            7'b0000011: id_imm = imm_i;   // LOAD
            7'b0100011: id_imm = imm_s;   // STORE
            7'b0010011: id_imm = imm_i;   // OP-IMM
            default:    id_imm = 32'd0;
        endcase
    end

    // =========================================================================
    // Register File
    // =========================================================================
    logic [4:0]  wb_rd;
    logic [31:0] wb_data;
    logic        wb_we;

    rv32_regfile u_regfile (
        .clk     (clk),
        .waddr   (wb_rd),
        .wdata   (wb_data),
        .wen     (wb_we),
        .raddr_a (id_rs1),
        .raddr_b (id_rs2),
        .rdata_a (id_reg1),
        .rdata_b (id_reg2)
    );

    // =========================================================================
    // Control Unit
    // =========================================================================
    logic [4:0] id_alu_op;
    logic       id_reg_we;
    logic [1:0] id_reg_wsrc;
    logic       id_mem_we;
    logic       id_mem_re;
    logic [1:0] id_mem_size;
    logic       id_is_branch;
    logic       id_is_jal;
    logic       id_is_jalr;
    logic       id_is_load;

    rv32_ctrl u_ctrl (
        .opcode    (id_opcode),
        .funct3    (id_funct3),
        .funct7    (id_funct7),
        .alu_op    (id_alu_op),
        .reg_we    (id_reg_we),
        .reg_wsrc  (id_reg_wsrc),
        .mem_we    (id_mem_we),
        .mem_re    (id_mem_re),
        .mem_size  (id_mem_size),
        .is_branch (id_is_branch),
        .is_jal    (id_is_jal),
        .is_jalr   (id_is_jalr),
        .is_load   (id_is_load)
    );

    // =========================================================================
    // EX/MEM Pipeline Register
    // =========================================================================
    logic [31:0] exmem_alu_result;
    logic [31:0] exmem_wdata;     // Store data
    logic [4:0]  exmem_rd;
    logic [2:0]  exmem_funct3;
    logic [31:0] exmem_pc4;
    logic        exmem_reg_we;
    logic [1:0]  exmem_reg_wsrc;
    logic        exmem_mem_we;
    logic        exmem_mem_re;
    logic [1:0]  exmem_mem_size;
    logic [3:0]  exmem_store_be;

    // =========================================================================
    // MEM/WB Pipeline Register
    // =========================================================================
    logic [31:0] memwb_alu_result;
    logic [31:0] memwb_load_data;
    logic [31:0] memwb_pc4;
    logic [4:0]  memwb_rd;
    logic        memwb_reg_we;
    logic [1:0]  memwb_reg_wsrc;

    // =========================================================================
    // EX Stage
    // =========================================================================
    logic [31:0] ex_op_a;
    logic [31:0] ex_op_b;
    logic [4:0]  ex_alu_op;
    logic [31:0] ex_alu_result;
    logic        ex_zero;
    logic [31:0] rs1_fwd;
    logic [31:0] rs2_fwd;
    logic [31:0] ex_store_data;

    // Determine ALU operands based on instruction type
    always_comb begin
        // Operand A
        if (id_opcode == 7'b0010111)      // AUIPC
            ex_op_a = id_pc;
        else if (id_opcode == 7'b1101111 || id_opcode == 7'b1100011) // JAL or BRANCH
            ex_op_a = id_pc;
        else
            ex_op_a = rs1_fwd;

        // Operand B
        if (id_opcode == 7'b0110111 ||    // LUI
            id_opcode == 7'b0010111 ||    // AUIPC
            id_opcode == 7'b1101111 ||    // JAL
            id_opcode == 7'b1100111 ||    // JALR
            id_opcode == 7'b0000011 ||    // LOAD
            id_opcode == 7'b0100011 ||    // STORE
            id_opcode == 7'b0010011)      // OP-IMM
            ex_op_b = id_imm;
        else
            ex_op_b = rs2_fwd;

        // ALU operation
        ex_alu_op = id_alu_op;
    end

    // Forwarding muxes
    logic [1:0] fwd_a;
    logic [1:0] fwd_b;

    // MEM/WB forwarding value
    logic [31:0] memwb_fwd_val;
    always_comb begin
        case (memwb_reg_wsrc)
            2'd0: memwb_fwd_val = memwb_alu_result;
            2'd1: memwb_fwd_val = memwb_load_data;
            2'd2: memwb_fwd_val = memwb_pc4;
            default: memwb_fwd_val = 32'd0;
        endcase
    end

    always_comb begin
        if (memwb_reg_we && (memwb_rd != 5'd0) && (memwb_rd == id_rs1) && (id_rs1 != 5'd0))
            fwd_a = 2'b10;
        else if (exmem_reg_we && (exmem_rd != 5'd0) && (exmem_rd == id_rs1) && (id_rs1 != 5'd0))
            fwd_a = 2'b01;
        else
            fwd_a = 2'b00;
    end

    always_comb begin
        if (memwb_reg_we && (memwb_rd != 5'd0) && (memwb_rd == id_rs2) && (id_rs2 != 5'd0))
            fwd_b = 2'b10;
        else if (exmem_reg_we && (exmem_rd != 5'd0) && (exmem_rd == id_rs2) && (id_rs2 != 5'd0))
            fwd_b = 2'b01;
        else
            fwd_b = 2'b00;
    end

    // Forwarded register values
    always_comb begin
        case (fwd_a)
            2'b00: rs1_fwd = id_reg1;
            2'b01: rs1_fwd = exmem_alu_result;
            2'b10: rs1_fwd = memwb_fwd_val;
            default: rs1_fwd = id_reg1;
        endcase
    end

    always_comb begin
        case (fwd_b)
            2'b00: rs2_fwd = id_reg2;
            2'b01: rs2_fwd = exmem_alu_result;
            2'b10: rs2_fwd = memwb_fwd_val;
            default: rs2_fwd = id_reg2;
        endcase
    end

    // Store data is always the forwarded rs2
    assign ex_store_data = rs2_fwd;

    // ALU
    rv32_alu u_alu (
        .op     (ex_alu_op),
        .a      (ex_op_a),
        .b      (ex_op_b),
        .result (ex_alu_result),
        .zero   (ex_zero)
    );

    // =========================================================================
    // Branch Resolution
    // =========================================================================
    logic ex_eq, ex_lt, ex_ltu;
    logic ex_branch_taken;
    logic [31:0] ex_branch_target;
    logic ex_pc_update;
    logic [31:0] ex_next_pc;

    assign ex_eq  = (ex_op_a == ex_op_b);
    assign ex_lt  = ($signed(ex_op_a) < $signed(ex_op_b));
    assign ex_ltu = (ex_op_a < ex_op_b);

    always_comb begin
        case (id_funct3)
            3'b000: ex_branch_taken = ex_eq;
            3'b001: ex_branch_taken = ~ex_eq;
            3'b100: ex_branch_taken = ex_lt;
            3'b101: ex_branch_taken = ~ex_lt;
            3'b110: ex_branch_taken = ex_ltu;
            3'b111: ex_branch_taken = ~ex_ltu;
            default: ex_branch_taken = 1'b0;
        endcase
    end

    // Branch target: for JALR, clear bit 0
    assign ex_branch_target = (id_is_jalr) ? (ex_alu_result & ~32'd1) : ex_alu_result;

    always_comb begin
        ex_pc_update = 1'b0;
        ex_next_pc   = if_pc4;
        if (id_is_branch && ex_branch_taken) begin
            ex_pc_update = 1'b1;
            ex_next_pc   = ex_branch_target;
        end else if (id_is_jal || id_is_jalr) begin
            ex_pc_update = 1'b1;
            ex_next_pc   = ex_branch_target;
        end
    end

    // =========================================================================
    // Load/Use Hazard Detection
    // Stall 1 cycle if a load in EX/MEM feeds a value to ID
    // =========================================================================
    always_comb begin
        stall    = 1'b0;
        flush_id = 1'b0;
        if (exmem_mem_re && (exmem_rd != 5'd0)) begin
            if ((exmem_rd == id_rs1 && id_rs1 != 5'd0) ||
                (exmem_rd == id_rs2 && id_rs2 != 5'd0)) begin
                stall    = 1'b1;
                flush_id = 1'b1;
            end
        end
    end

    // =========================================================================
    // PC Update
    // =========================================================================
    always_ff @(posedge clk) begin
        if (!rst_n)
            if_pc <= 32'd0;
        else if (stall)
            if_pc <= if_pc;      // Hold: bubble in IF
        else if (ex_pc_update)
            if_pc <= ex_next_pc;
        else
            if_pc <= if_pc4;
    end

    // =========================================================================
    // EX/MEM Pipeline Register
    // =========================================================================
    // Generate store byte enables
    function automatic logic [3:0] store_be(input logic [2:0] f3, input logic [31:0] addr);
        case (f3[1:0])
            2'd0: begin
                case (addr[1:0])
                    2'd0: store_be = 4'b0001;
                    2'd1: store_be = 4'b0010;
                    2'd2: store_be = 4'b0100;
                    2'd3: store_be = 4'b1000;
                endcase
            end
            2'd1: store_be = addr[1] ? 4'b1100 : 4'b0011;
            default: store_be = 4'b1111;
        endcase
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            exmem_alu_result <= 32'd0;
            exmem_wdata      <= 32'd0;
            exmem_rd         <= 5'd0;
            exmem_funct3     <= 3'd0;
            exmem_pc4        <= 32'd0;
            exmem_reg_we     <= 1'b0;
            exmem_reg_wsrc   <= 2'd0;
            exmem_mem_we     <= 1'b0;
            exmem_mem_re     <= 1'b0;
            exmem_mem_size   <= 2'd2;
            exmem_store_be   <= 4'd0;
        end else if (stall) begin
            // Insert bubble
            exmem_reg_we     <= 1'b0;
            exmem_mem_we     <= 1'b0;
            exmem_mem_re     <= 1'b0;
        end else begin
            exmem_alu_result <= ex_alu_result;
            exmem_wdata      <= ex_store_data; // Store data (forwarded rs2)
            exmem_rd         <= id_rd;
            exmem_funct3     <= id_funct3;
            exmem_pc4        <= id_pc4;
            exmem_reg_we     <= id_reg_we;
            exmem_reg_wsrc   <= id_reg_wsrc;
            exmem_mem_we     <= id_mem_we;
            exmem_mem_re     <= id_mem_re;
            exmem_mem_size   <= id_mem_size;
            exmem_store_be   <= store_be(id_funct3, ex_alu_result);
        end
    end

    // =========================================================================
    // MEM Stage
    // =========================================================================
    assign dmem_addr  = exmem_alu_result;
    assign dmem_wdata = exmem_wdata;
    assign dmem_we    = exmem_mem_we;
    assign dmem_be    = exmem_store_be;

    // Load data extension
    logic [31:0] mem_load_data;

    always_comb begin
        mem_load_data = dmem_rdata;
        if (exmem_mem_re) begin
            case (exmem_mem_size)
                2'd0: begin // Byte
                    case (exmem_alu_result[1:0])
                        2'd0: mem_load_data = (exmem_funct3 == 3'b000) ? {{24{dmem_rdata[7]}}, dmem_rdata[7:0]}
                                                                        : {24'd0, dmem_rdata[7:0]};
                        2'd1: mem_load_data = (exmem_funct3 == 3'b000) ? {{24{dmem_rdata[15]}}, dmem_rdata[15:8]}
                                                                        : {24'd0, dmem_rdata[15:8]};
                        2'd2: mem_load_data = (exmem_funct3 == 3'b000) ? {{24{dmem_rdata[23]}}, dmem_rdata[23:16]}
                                                                        : {24'd0, dmem_rdata[23:16]};
                        2'd3: mem_load_data = (exmem_funct3 == 3'b000) ? {{24{dmem_rdata[31]}}, dmem_rdata[31:24]}
                                                                        : {24'd0, dmem_rdata[31:24]};
                    endcase
                end
                2'd1: begin // Halfword
                    case (exmem_alu_result[1:0])
                        2'd0: mem_load_data = (exmem_funct3 == 3'b001) ? {{16{dmem_rdata[15]}}, dmem_rdata[15:0]}
                                                                        : {16'd0, dmem_rdata[15:0]};
                        2'd2: mem_load_data = (exmem_funct3 == 3'b001) ? {{16{dmem_rdata[31]}}, dmem_rdata[31:16]}
                                                                        : {16'd0, dmem_rdata[31:16]};
                        default: mem_load_data = 32'd0;
                    endcase
                end
                default: mem_load_data = dmem_rdata; // Word
            endcase
        end
    end

    // =========================================================================
    // MEM/WB Pipeline Register
    // =========================================================================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            memwb_alu_result <= 32'd0;
            memwb_load_data  <= 32'd0;
            memwb_pc4        <= 32'd0;
            memwb_rd         <= 5'd0;
            memwb_reg_we     <= 1'b0;
            memwb_reg_wsrc   <= 2'd0;
        end else begin
            memwb_alu_result <= exmem_alu_result;
            memwb_load_data  <= mem_load_data;
            memwb_pc4        <= exmem_pc4;
            memwb_rd         <= exmem_rd;
            memwb_reg_we     <= exmem_reg_we;
            memwb_reg_wsrc   <= exmem_reg_wsrc;
        end
    end

    // =========================================================================
    // WB Stage
    // =========================================================================
    always_comb begin
        case (memwb_reg_wsrc)
            2'd0: wb_data = memwb_alu_result;
            2'd1: wb_data = memwb_load_data;
            2'd2: wb_data = memwb_pc4;
            default: wb_data = 32'd0;
        endcase
    end

    assign wb_rd = memwb_rd;
    assign wb_we = memwb_reg_we;

    // Status
    assign pc_out = if_pc;

endmodule