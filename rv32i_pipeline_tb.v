`timescale 1ns/1ps

module rv32i_pipeline_tb;

    reg clk;
    reg reset;

    wire [31:0] pc_out;
    wire [31:0] alu_out;
    wire [31:0] mem_rdata_out;

    rv32i_pipeline dut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc_out),
        .alu_out(alu_out),
        .mem_rdata_out(mem_rdata_out)
    );

    // clock: 100 MHz
    always #5 clk = ~clk;

    integer i;

    initial begin
        $dumpfile("rv32i_pipeline.vcd");
        $dumpvars(0, rv32i_pipeline_tb);

        clk = 0;
        reset = 1;

        // Clear IMEM
        for (i = 0; i < 1024; i = i + 1)
            dut.imem[i] = 32'b0;

        // Clear DMEM
        for (i = 0; i < 4096; i = i + 1)
            dut.dmem[i] = 8'b0;

        // Allow reset to propagate
        #15 reset = 0;

        // Load Program
        dut.imem[0] = 32'h00500093; // addi x1, x0, 5
        dut.imem[1] = 32'h00700113; // addi x2, x0, 7
        dut.imem[2] = 32'h002081b3; // add x3, x1, x2
        dut.imem[3] = 32'h00302023; // sw x3, 0(x0)
        dut.imem[4] = 32'h00001017; // auipc x4, 1
        dut.imem[5] = 32'h0000006f; // jal x0, 0

        #200;

        $display("\n--- FINAL STATE ---");
        $display("PC = %h", pc_out);
        $display("x1 = %0d", dut.REGS.regs[1]);
        $display("x2 = %0d", dut.REGS.regs[2]);
        $display("x3 = %0d", dut.REGS.regs[3]);
        $display("x4 = %0d", dut.REGS.regs[4]);
        $display("Memory[0..3] = %08h",
            {dut.dmem[3], dut.dmem[2], dut.dmem[1], dut.dmem[0]});

        $finish;
    end
endmodule
