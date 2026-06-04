`timescale 1ns/1ps

/******************************************************************
* Description
*   Top-level RV32 pipeline. The historical module name is preserved
*   for the existing testbench and project files.
******************************************************************/

module RISC_V_Single_Cycle
#(
	parameter PROGRAM_MEMORY_DEPTH = 64,
	parameter DATA_MEMORY_DEPTH = 1024,
	parameter PROGRAM_FILE = "src/text.dat",
	parameter PROGRAM_INIT_WORDS = 0,
	parameter PROGRAM_LOAD_ENABLE = 1
)
(
	input clk,
	input reset,

	output [31:0] debug_pc_o,
	output [31:0] debug_instruction_o,
	output debug_wb_reg_write_o,
	output [4:0] debug_wb_rd_o,
	output [31:0] debug_wb_data_o,
	output [31:0] debug_t0_o,
	output [31:0] debug_t1_o,
	output [31:0] debug_t2_o,
	output [31:0] debug_s0_o,
	output [31:0] debug_s1_o,
	output [31:0] debug_s2_o,
	output [31:0] debug_s3_o
);

localparam OPCODE_R_TYPE = 7'h33;
localparam OPCODE_I_TYPE = 7'h13;
localparam OPCODE_LOAD   = 7'h03;
localparam OPCODE_STORE  = 7'h23;
localparam OPCODE_BRANCH = 7'h63;
localparam OPCODE_AUIPC  = 7'h17;
localparam OPCODE_LUI    = 7'h37;
localparam OPCODE_JAL    = 7'h6f;
localparam OPCODE_JALR   = 7'h67;

localparam RESULT_ALU = 2'b00;
localparam RESULT_MEM = 2'b01;
localparam RESULT_PC4 = 2'b10;

localparam ALU_AUIPC = 3'b100;

wire [31:0] pc_w;
wire [31:0] pc_plus_4_w;
wire [31:0] pc_next_w;
wire [31:0] instruction_bus_w;

wire pc_enable_w;
wire if_id_enable_w;
wire if_id_flush_w;
wire id_ex_flush_w;

wire [31:0] pipeline_if_id_pc_w_o;
wire [31:0] pipeline_if_id_pc_plus_4_w_o;
wire [31:0] pipeline_if_id_instruction_bus_w_o;

wire branch_w;
wire jump_w;
wire jalr_w;
wire alu_src_w;
wire reg_write_w;
wire mem_to_reg_w;
wire mem_write_w;
wire mem_read_w;
wire [1:0] result_src_w;
wire [2:0] alu_op_w;

wire [31:0] read_data_1_w;
wire [31:0] read_data_2_w;
wire [31:0] immediate_data_w;
wire [31:0] write_back_data_w;

wire pipeline_id_ex_branch_w_o;
wire pipeline_id_ex_jump_w_o;
wire pipeline_id_ex_jalr_w_o;
wire [2:0] pipeline_id_ex_alu_op_w_o;
wire pipeline_id_ex_alu_src_w_o;
wire pipeline_id_ex_reg_write_w_o;
wire pipeline_id_ex_mem_to_reg_w_o;
wire pipeline_id_ex_mem_read_w_o;
wire pipeline_id_ex_mem_write_w_o;
wire [1:0] pipeline_id_ex_result_src_w_o;
wire [31:0] pipeline_id_ex_pc_w_o;
wire [31:0] pipeline_id_ex_pc_plus_4_w_o;
wire [31:0] pipeline_id_ex_read_data_1_w_o;
wire [31:0] pipeline_id_ex_read_data_2_w_o;
wire [31:0] pipeline_id_ex_immediate_data_w_o;
wire [3:0] pipeline_id_ex_instruction_bus_w_30_14_12_o;
wire [4:0] pipeline_id_ex_rs1_w_o;
wire [4:0] pipeline_id_ex_rs2_w_o;
wire [4:0] pipeline_id_ex_rd_w_o;

wire [1:0] forward_a_w;
wire [1:0] forward_b_w;
wire [31:0] forwarded_read_data_1_w;
wire [31:0] forwarded_read_data_2_w;
wire [31:0] read_data_2_or_imm_w;
wire [31:0] alu_a_data_w;

wire [3:0] alu_operation_w;
wire zero_w;
wire [31:0] alu_result_w;
wire [31:0] pc_target_w;
wire [31:0] jalr_target_w;
wire branch_equal_w;
wire branch_less_signed_w;
wire branch_less_unsigned_w;
wire branch_taken_w;
wire pc_src_w;

wire pipeline_ex_mem_reg_write_w_o;
wire pipeline_ex_mem_mem_to_reg_w_o;
wire pipeline_ex_mem_mem_write_w_o;
wire pipeline_ex_mem_mem_read_w_o;
wire [1:0] pipeline_ex_mem_result_src_w_o;
wire [2:0] pipeline_ex_mem_funct3_w_o;
wire [31:0] pipeline_ex_mem_pc_plus_4_w_o;
wire [31:0] pipeline_ex_mem_alu_result_w_o;
wire [31:0] pipeline_ex_mem_write_data_w_o;
wire [4:0] pipeline_ex_mem_rd_w_o;
wire [31:0] ex_mem_forward_data_w;

wire pipeline_mem_wb_reg_write_w_o;
wire pipeline_mem_wb_mem_to_reg_w_o;
wire [1:0] pipeline_mem_wb_result_src_w_o;
wire [31:0] pipeline_mem_wb_pc_plus_4_w_o;
wire [31:0] pipeline_mem_wb_read_data_w_o;
wire [31:0] pipeline_mem_wb_alu_result_w_o;
wire [4:0] pipeline_mem_wb_rd_w_o;

wire [31:0] data_memory_read_data_w;

wire [6:0] if_id_opcode_w;
wire [4:0] if_id_rs1_w;
wire [4:0] if_id_rs2_w;
wire if_id_uses_rs1_w;
wire if_id_uses_rs2_w;
wire load_use_stall_w;

assign pc_enable_w = pc_src_w | ~load_use_stall_w;
assign if_id_enable_w = ~load_use_stall_w;
assign if_id_flush_w = pc_src_w;
assign id_ex_flush_w = pc_src_w | load_use_stall_w;

assign pc_next_w = pc_src_w ? pc_target_w : pc_plus_4_w;

PC_Register
PC
(
	.clk(clk),
	.reset(reset),
	.enable(pc_enable_w),
	.Next_PC(pc_next_w),
	.PC_Value(pc_w)
);

Program_Memory
#(
	.MEMORY_DEPTH(PROGRAM_MEMORY_DEPTH),
	.DATA_WIDTH(32),
	.PROGRAM_FILE(PROGRAM_FILE),
	.PROGRAM_INIT_WORDS(PROGRAM_INIT_WORDS),
	.PROGRAM_LOAD_ENABLE(PROGRAM_LOAD_ENABLE)
)
Instruction_memory
(
	.Address_i(pc_w),
	.Instruction_o(instruction_bus_w)
);

Adder_32_Bits
Add
(
	.Data0(pc_w),
	.Data1(32'd4),
	.Result(pc_plus_4_w)
);

Pipeline_Register
#(
	.N(96)
)
PIPELINE_IF_ID
(
	.clk(clk),
	.reset(reset),
	.enable(if_id_enable_w),
	.flush(if_id_flush_w),
	.pipeline_INPUT({
		pc_w,
		pc_plus_4_w,
		instruction_bus_w
	}),
	.pipeline_OUTPUT({
		pipeline_if_id_pc_w_o,
		pipeline_if_id_pc_plus_4_w_o,
		pipeline_if_id_instruction_bus_w_o
	})
);

assign if_id_opcode_w = pipeline_if_id_instruction_bus_w_o[6:0];
assign if_id_rs1_w = pipeline_if_id_instruction_bus_w_o[19:15];
assign if_id_rs2_w = pipeline_if_id_instruction_bus_w_o[24:20];

assign if_id_uses_rs1_w = (if_id_opcode_w == OPCODE_R_TYPE) |
                          (if_id_opcode_w == OPCODE_I_TYPE) |
                          (if_id_opcode_w == OPCODE_LOAD) |
                          (if_id_opcode_w == OPCODE_STORE) |
                          (if_id_opcode_w == OPCODE_BRANCH) |
                          (if_id_opcode_w == OPCODE_JALR);

assign if_id_uses_rs2_w = (if_id_opcode_w == OPCODE_R_TYPE) |
                          (if_id_opcode_w == OPCODE_STORE) |
                          (if_id_opcode_w == OPCODE_BRANCH);

assign load_use_stall_w = pipeline_id_ex_mem_read_w_o &&
                          (pipeline_id_ex_rd_w_o != 5'b0) &&
                          (((pipeline_id_ex_rd_w_o == if_id_rs1_w) && if_id_uses_rs1_w) ||
                           ((pipeline_id_ex_rd_w_o == if_id_rs2_w) && if_id_uses_rs2_w));

Control
CONTROL_UNIT
(
	.OP_i(if_id_opcode_w),
	.Branch_o(branch_w),
	.Jump_o(jump_w),
	.Jalr_o(jalr_w),
	.Mem_Read_o(mem_read_w),
	.Mem_to_Reg_o(mem_to_reg_w),
	.Mem_Write_o(mem_write_w),
	.ALU_Src_o(alu_src_w),
	.Reg_Write_o(reg_write_w),
	.Result_Src_o(result_src_w),
	.ALU_Op_o(alu_op_w)
);

Register_File
Registers
(
	.clk(clk),
	.reset(reset),
	.Reg_Write_i(pipeline_mem_wb_reg_write_w_o),
	.Write_Register_i(pipeline_mem_wb_rd_w_o),
	.Read_Register_1_i(if_id_rs1_w),
	.Read_Register_2_i(if_id_rs2_w),
	.Write_Data_i(write_back_data_w),
	.Read_Data_1_o(read_data_1_w),
	.Read_Data_2_o(read_data_2_w),
	.Debug_t0_o(debug_t0_o),
	.Debug_t1_o(debug_t1_o),
	.Debug_t2_o(debug_t2_o),
	.Debug_s0_o(debug_s0_o),
	.Debug_s1_o(debug_s1_o),
	.Debug_s2_o(debug_s2_o),
	.Debug_s3_o(debug_s3_o)
);

Immediate_Unit
Imm_Gen
(
	.op_i(if_id_opcode_w),
	.Instruction_bus_i(pipeline_if_id_instruction_bus_w_o),
	.Immediate_o(immediate_data_w)
);

Pipeline_Register
#(
	.N(192)
)
PIPELINE_ID_EX
(
	.clk(clk),
	.reset(reset),
	.enable(1'b1),
	.flush(id_ex_flush_w),
	.pipeline_INPUT({
		branch_w,
		jump_w,
		jalr_w,
		alu_op_w,
		alu_src_w,
		reg_write_w,
		mem_to_reg_w,
		mem_read_w,
		mem_write_w,
		result_src_w,
		pipeline_if_id_pc_w_o,
		pipeline_if_id_pc_plus_4_w_o,
		read_data_1_w,
		read_data_2_w,
		immediate_data_w,
		{
			pipeline_if_id_instruction_bus_w_o[30],
			pipeline_if_id_instruction_bus_w_o[14:12]
		},
		if_id_rs1_w,
		if_id_rs2_w,
		pipeline_if_id_instruction_bus_w_o[11:7]
	}),
	.pipeline_OUTPUT({
		pipeline_id_ex_branch_w_o,
		pipeline_id_ex_jump_w_o,
		pipeline_id_ex_jalr_w_o,
		pipeline_id_ex_alu_op_w_o,
		pipeline_id_ex_alu_src_w_o,
		pipeline_id_ex_reg_write_w_o,
		pipeline_id_ex_mem_to_reg_w_o,
		pipeline_id_ex_mem_read_w_o,
		pipeline_id_ex_mem_write_w_o,
		pipeline_id_ex_result_src_w_o,
		pipeline_id_ex_pc_w_o,
		pipeline_id_ex_pc_plus_4_w_o,
		pipeline_id_ex_read_data_1_w_o,
		pipeline_id_ex_read_data_2_w_o,
		pipeline_id_ex_immediate_data_w_o,
		pipeline_id_ex_instruction_bus_w_30_14_12_o,
		pipeline_id_ex_rs1_w_o,
		pipeline_id_ex_rs2_w_o,
		pipeline_id_ex_rd_w_o
	})
);

assign pc_target_w = pipeline_id_ex_jalr_w_o ? jalr_target_w :
                     (pipeline_id_ex_pc_w_o + pipeline_id_ex_immediate_data_w_o);

assign jalr_target_w = {alu_result_w[31:1], 1'b0};
assign branch_equal_w = (forwarded_read_data_1_w == forwarded_read_data_2_w);
assign branch_less_signed_w = ($signed(forwarded_read_data_1_w) < $signed(forwarded_read_data_2_w));
assign branch_less_unsigned_w = ($unsigned(forwarded_read_data_1_w) < $unsigned(forwarded_read_data_2_w));
assign branch_taken_w = pipeline_id_ex_branch_w_o &&
                        (((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b000) && branch_equal_w) ||
                         ((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b001) && ~branch_equal_w) ||
                         ((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b100) && branch_less_signed_w) ||
                         ((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b101) && ~branch_less_signed_w) ||
                         ((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b110) && branch_less_unsigned_w) ||
                         ((pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0] == 3'b111) && ~branch_less_unsigned_w));
assign pc_src_w = branch_taken_w | pipeline_id_ex_jump_w_o | pipeline_id_ex_jalr_w_o;

assign ex_mem_forward_data_w = (pipeline_ex_mem_result_src_w_o == RESULT_PC4) ?
                               pipeline_ex_mem_pc_plus_4_w_o :
                               pipeline_ex_mem_alu_result_w_o;

assign forward_a_w = ((pipeline_ex_mem_reg_write_w_o == 1'b1) &&
                      (pipeline_ex_mem_mem_to_reg_w_o == 1'b0) &&
                      (pipeline_ex_mem_rd_w_o != 5'b0) &&
                      (pipeline_ex_mem_rd_w_o == pipeline_id_ex_rs1_w_o)) ? 2'b10 :
                     ((pipeline_mem_wb_reg_write_w_o == 1'b1) &&
                      (pipeline_mem_wb_rd_w_o != 5'b0) &&
                      (pipeline_mem_wb_rd_w_o == pipeline_id_ex_rs1_w_o)) ? 2'b01 :
                     2'b00;

assign forward_b_w = ((pipeline_ex_mem_reg_write_w_o == 1'b1) &&
                      (pipeline_ex_mem_mem_to_reg_w_o == 1'b0) &&
                      (pipeline_ex_mem_rd_w_o != 5'b0) &&
                      (pipeline_ex_mem_rd_w_o == pipeline_id_ex_rs2_w_o)) ? 2'b10 :
                     ((pipeline_mem_wb_reg_write_w_o == 1'b1) &&
                      (pipeline_mem_wb_rd_w_o != 5'b0) &&
                      (pipeline_mem_wb_rd_w_o == pipeline_id_ex_rs2_w_o)) ? 2'b01 :
                     2'b00;

assign forwarded_read_data_1_w = (forward_a_w == 2'b10) ? ex_mem_forward_data_w :
                                 (forward_a_w == 2'b01) ? write_back_data_w :
                                 pipeline_id_ex_read_data_1_w_o;

assign forwarded_read_data_2_w = (forward_b_w == 2'b10) ? ex_mem_forward_data_w :
                                 (forward_b_w == 2'b01) ? write_back_data_w :
                                 pipeline_id_ex_read_data_2_w_o;

Multiplexer_2_to_1
#(
	.NBits(32)
)
MUX_DATA_OR_IMM_FOR_ALU
(
	.Selector_i(pipeline_id_ex_alu_src_w_o),
	.Mux_Data_0_i(forwarded_read_data_2_w),
	.Mux_Data_1_i(pipeline_id_ex_immediate_data_w_o),
	.Mux_Output_o(read_data_2_or_imm_w)
);

assign alu_a_data_w = (pipeline_id_ex_alu_op_w_o == ALU_AUIPC) ?
                      pipeline_id_ex_pc_w_o :
                      forwarded_read_data_1_w;

ALU_Control
ALU_CONTROL_UNIT
(
	.funct7_i(pipeline_id_ex_instruction_bus_w_30_14_12_o[3]),
	.ALU_Op_i(pipeline_id_ex_alu_op_w_o),
	.funct3_i(pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0]),
	.ALU_Operation_o(alu_operation_w)
);

ALU
ALU_UNIT
(
	.ALU_Operation_i(alu_operation_w),
	.A_i(alu_a_data_w),
	.B_i(read_data_2_or_imm_w),
	.Zero_o(zero_w),
	.ALU_Result_o(alu_result_w)
);

Pipeline_Register
#(
	.N(110)
)
PIPELINE_EX_MEM
(
	.clk(clk),
	.reset(reset),
	.enable(1'b1),
	.flush(1'b0),
	.pipeline_INPUT({
		pipeline_id_ex_reg_write_w_o,
		pipeline_id_ex_mem_to_reg_w_o,
		pipeline_id_ex_mem_write_w_o,
		pipeline_id_ex_mem_read_w_o,
		pipeline_id_ex_result_src_w_o,
		pipeline_id_ex_instruction_bus_w_30_14_12_o[2:0],
		pipeline_id_ex_pc_plus_4_w_o,
		alu_result_w,
		forwarded_read_data_2_w,
		pipeline_id_ex_rd_w_o
	}),
	.pipeline_OUTPUT({
		pipeline_ex_mem_reg_write_w_o,
		pipeline_ex_mem_mem_to_reg_w_o,
		pipeline_ex_mem_mem_write_w_o,
		pipeline_ex_mem_mem_read_w_o,
		pipeline_ex_mem_result_src_w_o,
		pipeline_ex_mem_funct3_w_o,
		pipeline_ex_mem_pc_plus_4_w_o,
		pipeline_ex_mem_alu_result_w_o,
		pipeline_ex_mem_write_data_w_o,
		pipeline_ex_mem_rd_w_o
	})
);

Data_Memory
#(
	.DATA_WIDTH(32),
	.MEMORY_DEPTH(DATA_MEMORY_DEPTH)
)
Data_memory
(
	.clk(clk),
	.Mem_Write_i(pipeline_ex_mem_mem_write_w_o),
	.Mem_Read_i(pipeline_ex_mem_mem_read_w_o),
	.Write_Data_i(pipeline_ex_mem_write_data_w_o),
	.Address_i(pipeline_ex_mem_alu_result_w_o),
	.funct3_i(pipeline_ex_mem_funct3_w_o),
	.Read_Data_o(data_memory_read_data_w)
);

Pipeline_Register
#(
	.N(105)
)
PIPELINE_MEM_WB
(
	.clk(clk),
	.reset(reset),
	.enable(1'b1),
	.flush(1'b0),
	.pipeline_INPUT({
		pipeline_ex_mem_reg_write_w_o,
		pipeline_ex_mem_mem_to_reg_w_o,
		pipeline_ex_mem_result_src_w_o,
		pipeline_ex_mem_pc_plus_4_w_o,
		data_memory_read_data_w,
		pipeline_ex_mem_alu_result_w_o,
		pipeline_ex_mem_rd_w_o
	}),
	.pipeline_OUTPUT({
		pipeline_mem_wb_reg_write_w_o,
		pipeline_mem_wb_mem_to_reg_w_o,
		pipeline_mem_wb_result_src_w_o,
		pipeline_mem_wb_pc_plus_4_w_o,
		pipeline_mem_wb_read_data_w_o,
		pipeline_mem_wb_alu_result_w_o,
		pipeline_mem_wb_rd_w_o
	})
);

assign write_back_data_w = (pipeline_mem_wb_result_src_w_o == RESULT_MEM) ? pipeline_mem_wb_read_data_w_o :
                           (pipeline_mem_wb_result_src_w_o == RESULT_PC4) ? pipeline_mem_wb_pc_plus_4_w_o :
                           pipeline_mem_wb_alu_result_w_o;

assign debug_pc_o = pc_w;
assign debug_instruction_o = instruction_bus_w;
assign debug_wb_reg_write_o = pipeline_mem_wb_reg_write_w_o;
assign debug_wb_rd_o = pipeline_mem_wb_rd_w_o;
assign debug_wb_data_o = write_back_data_w;

endmodule
