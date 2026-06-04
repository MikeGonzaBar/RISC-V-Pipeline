`timescale 1ns/1ps

/******************************************************************
* Description
*   Main control unit for the course-level RV32 pipeline subset.
******************************************************************/
module Control
(
    input [6:0] OP_i,

    output Branch_o,
    output Jump_o,
    output Jalr_o,
    output Mem_Read_o,
    output Mem_to_Reg_o,
    output Mem_Write_o,
    output ALU_Src_o,
    output Reg_Write_o,
    output [1:0] Result_Src_o,
    output [2:0] ALU_Op_o
);

localparam R_TYPE = 7'h33;
localparam I_TYPE = 7'h13;
localparam LOAD   = 7'h03;
localparam STORE  = 7'h23;
localparam BRANCH = 7'h63;
localparam AUIPC  = 7'h17;
localparam LUI    = 7'h37;
localparam JAL    = 7'h6f;
localparam JALR   = 7'h67;

localparam RESULT_ALU = 2'b00;
localparam RESULT_MEM = 2'b01;
localparam RESULT_PC4 = 2'b10;

localparam ALU_R_TYPE = 3'b000;
localparam ALU_I_TYPE = 3'b001;
localparam ALU_LUI    = 3'b010;
localparam ALU_ADD    = 3'b011;
localparam ALU_AUIPC  = 3'b100;

reg branch_r;
reg jump_r;
reg jalr_r;
reg mem_read_r;
reg mem_write_r;
reg alu_src_r;
reg reg_write_r;
reg [1:0] result_src_r;
reg [2:0] alu_op_r;

always @(*) begin
    branch_r = 1'b0;
    jump_r = 1'b0;
    jalr_r = 1'b0;
    mem_read_r = 1'b0;
    mem_write_r = 1'b0;
    alu_src_r = 1'b0;
    reg_write_r = 1'b0;
    result_src_r = RESULT_ALU;
    alu_op_r = ALU_ADD;

    case (OP_i)
        R_TYPE: begin
            reg_write_r = 1'b1;
            alu_op_r = ALU_R_TYPE;
        end

        I_TYPE: begin
            reg_write_r = 1'b1;
            alu_src_r = 1'b1;
            alu_op_r = ALU_I_TYPE;
        end

        LOAD: begin
            reg_write_r = 1'b1;
            mem_read_r = 1'b1;
            alu_src_r = 1'b1;
            result_src_r = RESULT_MEM;
            alu_op_r = ALU_ADD;
        end

        STORE: begin
            mem_write_r = 1'b1;
            alu_src_r = 1'b1;
            alu_op_r = ALU_ADD;
        end

        BRANCH: begin
            branch_r = 1'b1;
            alu_op_r = ALU_ADD;
        end

        LUI: begin
            reg_write_r = 1'b1;
            alu_src_r = 1'b1;
            alu_op_r = ALU_LUI;
        end

        AUIPC: begin
            reg_write_r = 1'b1;
            alu_src_r = 1'b1;
            alu_op_r = ALU_AUIPC;
        end

        JAL: begin
            reg_write_r = 1'b1;
            jump_r = 1'b1;
            result_src_r = RESULT_PC4;
            alu_op_r = ALU_ADD;
        end

        JALR: begin
            reg_write_r = 1'b1;
            jalr_r = 1'b1;
            alu_src_r = 1'b1;
            result_src_r = RESULT_PC4;
            alu_op_r = ALU_ADD;
        end

        default: begin
            branch_r = 1'b0;
        end
    endcase
end

assign Branch_o = branch_r;
assign Jump_o = jump_r;
assign Jalr_o = jalr_r;
assign Mem_Read_o = mem_read_r;
assign Mem_to_Reg_o = (result_src_r == RESULT_MEM);
assign Mem_Write_o = mem_write_r;
assign ALU_Src_o = alu_src_r;
assign Reg_Write_o = reg_write_r;
assign Result_Src_o = result_src_r;
assign ALU_Op_o = alu_op_r;

endmodule
