`timescale 1ns/1ps

/******************************************************************
* Description
*	This is an 32-bit arithetic logic unit.

* This ALU is written by using behavioral description.
* Version:
*	1.0
* Author:
*	Dr. José Luis Pizano Escalante
* email:
*	luispizano@iteso.mx
* Date:
*	16/08/2021
******************************************************************/

module ALU 
(
	input [3:0] ALU_Operation_i,
	input signed [31:0] A_i,
	input signed [31:0] B_i,
	output reg Zero_o,
	output reg [31:0] ALU_Result_o
);

localparam ADD  = 4'b0000;
localparam LUI  = 4'b0001;
localparam OR   = 4'b0010;
localparam SLL  = 4'b0011;
localparam SRL  = 4'b0100;
localparam SUB  = 4'b0101;
localparam AND  = 4'b0110;
localparam XOR  = 4'b0111;
localparam SLT  = 4'b1000;
localparam SLTU = 4'b1001;
localparam SRA  = 4'b1010;

always @(*) begin
	case (ALU_Operation_i)
		ADD:  ALU_Result_o = A_i + B_i;
		LUI:  ALU_Result_o = B_i;
		OR:   ALU_Result_o = A_i | B_i;
		SLL:  ALU_Result_o = A_i << B_i[4:0];
		SRL:  ALU_Result_o = A_i >> B_i[4:0];
		SUB:  ALU_Result_o = A_i - B_i;
		AND:  ALU_Result_o = A_i & B_i;
		XOR:  ALU_Result_o = A_i ^ B_i;
		SLT:  ALU_Result_o = ($signed(A_i) < $signed(B_i)) ? 32'd1 : 32'd0;
		SLTU: ALU_Result_o = ($unsigned(A_i) < $unsigned(B_i)) ? 32'd1 : 32'd0;
		SRA:  ALU_Result_o = A_i >>> B_i[4:0];

		default:
			ALU_Result_o = 0;
	endcase

	Zero_o = (ALU_Result_o == 0) ? 1'b1 : 1'b0;
end
endmodule // ALU
