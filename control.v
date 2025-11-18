`timescale 1ns/1ps

module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        regwrite,
    output reg        memwrite,
    output reg        memread,
    output reg        branch,
    output reg        alusrc,
    output reg        memtoreg,
    output reg        jump,
    output reg [3:0]  aluop
);

    always @(*) begin
        // Defaults (NOP)
        regwrite = 0;
        memwrite = 0;
        memread  = 0;
        branch   = 0;
        alusrc   = 0;
        memtoreg = 0;
        jump     = 0;
        aluop    = 4'b0000;

        case (opcode)

            //---------------------------------------
            // R-TYPE
            //---------------------------------------
            7'b0110011: begin
                regwrite = 1;
                alusrc   = 0;
                memtoreg = 0;

                case ({funct7, funct3})
                    10'b0000000_000: aluop = 4'b0000; // ADD
                    10'b0100000_000: aluop = 4'b1000; // SUB
                    10'b0000000_001: aluop = 4'b0001; // SLL
                    10'b0000000_010: aluop = 4'b0010; // SLT
                    10'b0000000_011: aluop = 4'b0011; // SLTU
                    10'b0000000_100: aluop = 4'b0100; // XOR
                    10'b0000000_101: aluop = 4'b0101; // SRL
                    10'b0100000_101: aluop = 4'b1101; // SRA
                    10'b0000000_110: aluop = 4'b0110; // OR
                    10'b0000000_111: aluop = 4'b0111; // AND
                endcase
            end

            //---------------------------------------
            // I-TYPE (ADDI, SLTI…)
            //---------------------------------------
            7'b0010011: begin
                regwrite = 1;
                alusrc   = 1;
                memtoreg = 0;
                case (funct3)
                    3'b000: aluop = 4'b0000; // ADDI
                    3'b010: aluop = 4'b0010; // SLTI
                    3'b011: aluop = 4'b0011; // SLTIU
                    3'b100: aluop = 4'b0100; // XORI
                    3'b110: aluop = 4'b0110; // ORI
                    3'b111: aluop = 4'b0111; // ANDI
                    3'b001: aluop = 4'b0001; // SLLI
                    3'b101: aluop = funct7[5] ? 4'b1101 : 4'b0101;
                endcase
            end

            //---------------------------------------
            // LW
            //---------------------------------------
            7'b0000011: begin
                regwrite = 1;
                memread  = 1;
                alusrc   = 1;
                memtoreg = 1;
                aluop    = 4'b0000;
            end

            //---------------------------------------
            // SW
            //---------------------------------------
            7'b0100011: begin
                memwrite = 1;
                alusrc = 1;
                aluop = 4'b0000;
            end

            //---------------------------------------
            // BRANCH (BEQ only)
            //---------------------------------------
            7'b1100011: begin
                branch = 1;
                aluop = 4'b1000; // SUB comparator
            end

            //---------------------------------------
            // AUIPC
            //---------------------------------------
            7'b0010111: begin
                regwrite = 1;
                alusrc = 1;
                aluop = 4'b0000;
            end

            //---------------------------------------
            // LUI
            //---------------------------------------
            7'b0110111: begin
                regwrite = 1;
                alusrc = 1;
                aluop = 4'b0000;
            end

            //---------------------------------------
            // JAL
            //---------------------------------------
            7'b1101111: begin
                regwrite = 1;
                jump = 1;
                alusrc = 1;
                aluop = 4'b0000; // PC + imm
            end

        endcase
    end
endmodule
