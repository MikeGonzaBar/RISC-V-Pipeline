`timescale 1ns/1ps

/******************************************************************
* Description
*	This is the control unit for the ALU. It receves a signal called 
*	ALUOp from the control unit and signals called funct7 and funct3  from
*	the instruction bus.
* Version:
*	1.0
* Author:
*	Dr. José Luis Pizano Escalante
* email:
*	luispizano@iteso.mx
* Date:
*	16/08/2021
******************************************************************/
module ALU_Control
(
	input funct7_i,
	input [2:0] ALU_Op_i,
	input [2:0] funct3_i,
	

	output [3:0] ALU_Operation_o

);

localparam ALU_R_TYPE = 3'b000;
localparam ALU_I_TYPE = 3'b001;
localparam ALU_LUI    = 3'b010;
localparam ALU_ADD    = 3'b011;
localparam ALU_AUIPC  = 3'b100;

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

reg [3:0] alu_control_values;

always @(*) begin
	alu_control_values = ADD;

	case (ALU_Op_i)
		ALU_R_TYPE: begin
			case (funct3_i)
				3'b000: alu_control_values = funct7_i ? SUB : ADD;
				3'b001: alu_control_values = SLL;
				3'b010: alu_control_values = SLT;
				3'b011: alu_control_values = SLTU;
				3'b100: alu_control_values = XOR;
				3'b101: alu_control_values = funct7_i ? SRA : SRL;
				3'b110: alu_control_values = OR;
				3'b111: alu_control_values = AND;
				default: alu_control_values = ADD;
			endcase
		end

		ALU_I_TYPE: begin
			case (funct3_i)
				3'b000: alu_control_values = ADD;
				3'b001: alu_control_values = SLL;
				3'b010: alu_control_values = SLT;
				3'b011: alu_control_values = SLTU;
				3'b100: alu_control_values = XOR;
				3'b101: alu_control_values = funct7_i ? SRA : SRL;
				3'b110: alu_control_values = OR;
				3'b111: alu_control_values = AND;
				default: alu_control_values = ADD;
			endcase
		end

		ALU_LUI:
			alu_control_values = LUI;

		ALU_ADD,
		ALU_AUIPC:
			alu_control_values = ADD;

		default:
			alu_control_values = ADD;
	endcase
end

assign ALU_Operation_o = alu_control_values;

endmodule
