`timescale 1ns/1ps

module rv32i_pipeline (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc_out,
    output wire [31:0] alu_out,
    output wire [31:0] mem_rdata_out
);

    // =====================================
    // IF Stage
    // =====================================
    reg [31:0] pc;
    wire [31:0] next_pc;
    wire [31:0] instr;

    // Instruction memory (4 KB)
    reg [31:0] imem [0:1023];

    assign instr = imem[pc[11:2]];

    // =====================================
    // IF/ID pipeline register
    // =====================================
    reg [31:0] IF_ID_pc;
    reg [31:0] IF_ID_instr;

    wire hazard_stall, pc_write, if_id_write;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IF_ID_pc    <= 0;
            IF_ID_instr <= 32'h00000013;  // NOP
        end else begin
            if (exmem_branch && exmem_zero) begin
                // Flush after branch taken
                IF_ID_pc    <= 0;
                IF_ID_instr <= 32'h00000013;
            end
            else if (if_id_write) begin
                // Normal IF/ID update
                IF_ID_pc    <= pc;
                IF_ID_instr <= instr;
            end
            // else hold (stall)
        end
    end

    // =====================================
    // ID Stage
    // =====================================
    wire [6:0] opcode = IF_ID_instr[6:0];
    wire [4:0] rd     = IF_ID_instr[11:7];
    wire [2:0] funct3 = IF_ID_instr[14:12];
    wire [4:0] rs1    = IF_ID_instr[19:15];
    wire [4:0] rs2    = IF_ID_instr[24:20];
    wire [6:0] funct7 = IF_ID_instr[31:25];

    wire regwrite, memwrite, memread, branch, alusrc, memtoreg, jump;
    wire [3:0] aluop;

    control CONTROL (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .regwrite(regwrite),
        .memwrite(memwrite),
        .memread(memread),
        .branch(branch),
        .alusrc(alusrc),
        .memtoreg(memtoreg),
        .jump(jump),
        .aluop(aluop)
    );

    // Register file
    wire [31:0] rdata1, rdata2;
    wire [31:0] wb_data;

    regfile REGS (
        .clk(clk),
        .we(memwb_regwrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(memwb_rd),
        .wdata(wb_data),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // Immediate generation
    reg [31:0] imm;
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111:
                imm = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:20]};
            7'b0100011:
                imm = {{20{IF_ID_instr[31]}},
                       IF_ID_instr[31:25], IF_ID_instr[11:7]};
            7'b1100011:
                imm = {{19{IF_ID_instr[31]}}, IF_ID_instr[31],
                       IF_ID_instr[7], IF_ID_instr[30:25],
                       IF_ID_instr[11:8], 1'b0};
            7'b0010111, 7'b0110111:
                imm = {IF_ID_instr[31:12], 12'd0};
            7'b1101111:
                imm = {{11{IF_ID_instr[31]}}, IF_ID_instr[31],
                       IF_ID_instr[19:12], IF_ID_instr[20],
                       IF_ID_instr[30:21], 1'b0};
            default: imm = 0;
        endcase
    end

    // =====================================
    // Hazard Unit
    // =====================================
    hazard_unit HAZARD (
        .id_ex_memread(idex_memread),
        .id_ex_rd(idex_rd),
        .if_id_rs1(rs1),
        .if_id_rs2(rs2),
        .stall(hazard_stall),
        .pc_write(pc_write),
        .if_id_write(if_id_write)
    );

    // =====================================
    // ID/EX pipeline register
    // =====================================
    reg [31:0] idex_pc, idex_rdata1, idex_rdata2, idex_imm;
    reg [4:0] idex_rs1, idex_rs2, idex_rd;
    reg [3:0] idex_aluop;
    reg idex_memread, idex_memwrite, idex_regwrite;
    reg idex_memtoreg, idex_alusrc, idex_branch, idex_jump;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            idex_pc <= 0; idex_rdata1 <= 0; idex_rdata2 <= 0; idex_imm <= 0;
            idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0; idex_aluop <= 0;
            idex_memread <= 0; idex_memwrite <= 0; idex_regwrite <= 0;
            idex_memtoreg <= 0; idex_alusrc <= 0; idex_branch <= 0; idex_jump <= 0;
        end 
        else if (hazard_stall) begin
            // Insert bubble
            idex_pc <= 0; idex_rdata1 <= 0; idex_rdata2 <= 0; idex_imm <= 0;
            idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0; idex_aluop <= 0;
            idex_memread <= 0; idex_memwrite <= 0; idex_regwrite <= 0;
            idex_memtoreg <= 0; idex_alusrc <= 0; idex_branch <= 0; idex_jump <= 0;
        end
        else begin
            idex_pc <= IF_ID_pc;
            idex_rdata1 <= rdata1;
            idex_rdata2 <= rdata2;
            idex_imm <= imm;
            idex_rs1 <= rs1;
            idex_rs2 <= rs2;
            idex_rd <= rd;
            idex_aluop <= aluop;
            idex_memread <= memread;
            idex_memwrite <= memwrite;
            idex_regwrite <= regwrite;
            idex_memtoreg <= memtoreg;
            idex_alusrc <= alusrc;
            idex_branch <= branch;
            idex_jump <= jump;
        end
    end

    // =====================================
    // EX Stage
    // =====================================
    wire [1:0] forwardA, forwardB;

    forward_unit FORWARD (
        .ex_mem_regwrite(exmem_regwrite),
        .ex_mem_rd(exmem_rd),
        .mem_wb_regwrite(memwb_regwrite),
        .mem_wb_rd(memwb_rd),
        .id_ex_rs1(idex_rs1),
        .id_ex_rs2(idex_rs2),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );

    reg [31:0] alu_srcA, alu_srcB;
    wire [31:0] alu_result;
    wire zero_flag;

    always @(*) begin
        case (forwardA)
            2'b10: alu_srcA = exmem_alu_result;
            2'b01: alu_srcA = wb_data;
            default: alu_srcA = idex_rdata1;
        endcase

        case (forwardB)
            2'b10: alu_srcB = exmem_alu_result;
            2'b01: alu_srcB = wb_data;
            default: alu_srcB = idex_alusrc ? idex_imm : idex_rdata2;
        endcase
    end

    alu ALU (
        .a(alu_srcA),
        .b(alu_srcB),
        .aluop(idex_aluop),
        .result(alu_result),
        .zero(zero_flag)
    );

    // =====================================
    // EX/MEM pipeline register
    // =====================================
    reg [31:0] exmem_alu_result, exmem_rdata2, exmem_pc_branch;
    reg [4:0]  exmem_rd;
    reg exmem_zero, exmem_memread, exmem_memwrite;
    reg exmem_regwrite, exmem_memtoreg, exmem_branch, exmem_jump;

    wire [31:0] branch_target = idex_pc + idex_imm;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            exmem_alu_result <= 0;
            exmem_rdata2 <= 0;
            exmem_pc_branch <= 0;
            exmem_rd <= 0;
            exmem_zero <= 0;
            exmem_memread <= 0;
            exmem_memwrite <= 0;
            exmem_regwrite <= 0;
            exmem_memtoreg <= 0;
            exmem_branch <= 0;
            exmem_jump <= 0;
        end else begin
            exmem_alu_result <= alu_result;
            exmem_rdata2 <= idex_rdata2;
            exmem_pc_branch <= branch_target;
            exmem_rd <= idex_rd;
            exmem_zero <= zero_flag;
            exmem_memread <= idex_memread;
            exmem_memwrite <= idex_memwrite;
            exmem_regwrite <= idex_regwrite;
            exmem_memtoreg <= idex_memtoreg;
            exmem_branch <= idex_branch;
            exmem_jump <= idex_jump;
        end
    end

    // =====================================
    // MEM Stage
    // =====================================
    reg [7:0] dmem [0:4095];

    // Protect memory index from X/out-of-range
    wire [11:0] mem_addr = exmem_alu_result[11:0];

    wire [31:0] mem_data_out = {
        dmem[mem_addr+3], dmem[mem_addr+2],
        dmem[mem_addr+1], dmem[mem_addr]
    };

    always @(posedge clk) begin
        if (exmem_memwrite) begin
            dmem[mem_addr]   <= exmem_rdata2[7:0];
            dmem[mem_addr+1] <= exmem_rdata2[15:8];
            dmem[mem_addr+2] <= exmem_rdata2[23:16];
            dmem[mem_addr+3] <= exmem_rdata2[31:24];
        end
    end

    // =====================================
    // MEM/WB pipeline register
    // =====================================
    reg [31:0] memwb_alu_result, memwb_mem_data;
    reg [4:0]  memwb_rd;
    reg memwb_regwrite, memwb_memtoreg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            memwb_alu_result <= 0;
            memwb_mem_data <= 0;
            memwb_rd <= 0;
            memwb_regwrite <= 0;
            memwb_memtoreg <= 0;
        end else begin
            memwb_alu_result <= exmem_alu_result;
            memwb_mem_data <= mem_data_out;
            memwb_rd <= exmem_rd;
            memwb_regwrite <= exmem_regwrite;
            memwb_memtoreg <= exmem_memtoreg;
        end
    end

    // =====================================
    // WB Stage
    // =====================================
    assign wb_data = memwb_memtoreg ? memwb_mem_data : memwb_alu_result;

    // =====================================
    // PC Update
    // =====================================
    assign next_pc =
        (exmem_branch && exmem_zero) ? exmem_pc_branch :
        pc + 4;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 0;
        end
        else if (pc_write) begin
            pc <= next_pc;
        end
        // else: stall, hold PC
    end

    // Outputs for testbench
    assign pc_out        = pc;
    assign alu_out       = alu_result;
    assign mem_rdata_out = mem_data_out;

endmodule
