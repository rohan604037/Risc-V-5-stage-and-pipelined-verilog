`timescale 1ns/1ps

module regfile (
    input wire clk,
    input wire we,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

    reg [31:0] regs [0:31];

    // Asynchronous, simple reads (x0 always 0)
    assign rdata1 = (rs1 == 0) ? 32'b0 : regs[rs1];
    assign rdata2 = (rs2 == 0) ? 32'b0 : regs[rs2];

    always @(posedge clk) begin
        if (we && rd != 0)
            regs[rd] <= wdata;
    end

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 0;
    end

endmodule
