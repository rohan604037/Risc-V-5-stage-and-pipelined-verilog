`timescale 1ns/1ps

module hazard_unit (
    input  wire        id_ex_memread,
    input  wire [4:0]  id_ex_rd,
    input  wire [4:0]  if_id_rs1,
    input  wire [4:0]  if_id_rs2,
    output reg         stall,
    output reg         pc_write,
    output reg         if_id_write
);

    always @(*) begin
        if (id_ex_memread && 
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) &&
            id_ex_rd != 0) begin
            stall       = 1;
            pc_write    = 0;
            if_id_write = 0;
        end else begin
            stall       = 0;
            pc_write    = 1;
            if_id_write = 1;
        end
    end

endmodule
