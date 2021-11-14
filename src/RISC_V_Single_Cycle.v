/******************************************************************
* Description
*	This is the top-level of a RISC-V Microprocessor that can execute the next set of instructions:
*		add
*		addi
* This processor is written Verilog-HDL. It is synthesizabled into hardware.
* Parameter MEMORY_DEPTH configures the program memory to allocate the program to
* be executed. If the size of the program changes, thus, MEMORY_DEPTH must change.
* This processor was made for computer organization class at ITESO.
* Version:
*	1.0
* Author:
*	Dr. José Luis Pizano Escalante
* email:
*	luispizano@iteso.mx
* Date:
*	16/08/2021
******************************************************************/

module RISC_V_Single_Cycle
#(
	parameter PROGRAM_MEMORY_DEPTH = 64,
	parameter DATA_MEMORY_DEPTH = 128
)

(
	// Inputs
	input clk,
	input reset

);
//******************************************************************/
//******************************************************************/

//******************************************************************/
//******************************************************************/
/* Signals to connect modules*/

/**Control**/
wire alu_src_w;
wire reg_write_w;
wire mem_to_reg_w;
wire mem_write_w;
wire mem_read_w;
wire [2:0] alu_op_w;

/** Program Counter**/
wire [31:0] pc_plus_4_w;
wire [31:0] pc_w;


/**Register File**/
wire [31:0] read_data_1_w;
wire [31:0] read_data_2_w;

/**Inmmediate Unit**/
wire [31:0] inmmediate_data_w;

/**ALU**/
wire zero_w;
wire [31:0] alu_result_w;

/**Multiplexer MUX_DATA_OR_IMM_FOR_ALU**/
wire [31:0] read_data_2_or_imm_w;

/**ALU Control**/
wire [3:0] alu_operation_w;

/**Instruction Bus**/	
wire [31:0] instruction_bus_w;



/**Pipeline's Wires**/
wire [31:0] pipeline_if_id_pc_W_o;
wire [31:0] pipeline_if_id_instruction_bus_w_o;
wire pipeline_mem_wb_reg_write_w_o;
wire pipeline_mem_wb_mem_to_reg_w_o;
wire pipeline_ex_mem_reg_write_w_o;
wire pipeline_ex_mem_mem_to_reg_w_o;
wire pipeline_ex_mem_mem_write_w_o;
wire pipeline_ex_mem_mem_read_w_o;
wire [31:0] pipeline_id_ex_pc_W_o;
wire pipeline_id_ex_alu_src_w_o;
wire pipeline_id_ex_reg_write_w_o;
wire pipeline_id_ex_mem_to_reg_w_o;
wire pipeline_id_ex_mem_write_w_o;
wire pipeline_id_ex_mem_read_w_o;
wire [2:0] pipeline_id_ex_alu_op_w_o;
wire [31:0] pipeline_id_ex_read_data_1_w_o;
wire [31:0] pipeline_id_ex_read_data_2_w_o;
wire [31:0] pipeline_ex_mem_read_data_2_w_o;
wire [31:0] pipeline_id_ex_immediate_data_w_o;
wire [3:0] pipeline_id_ex_instruction_bus_w_30_14_12_o;
wire [4:0] pipeline_id_ex_instruction_bus_w_11_7_o;
wire [4:0] pipeline_ex_mem_instruction_bus_w_11_7_o;
wire [4:0] pipeline_mem_wb_instruction_bus_w_11_7_o;
wire [31:0] AddSum_result;
wire [31:0] pipeline_ex_mem_AddSum_result_w_o;
wire pipeline_ex_mem_zero_w_o;
wire[31:0] pipeline_mem_wb_ALU_Result_w_o;
wire[31:0] pipeline_ex_mem_ALU_Result_w_o;
wire [255:0] pipeline_mem_wb_read_data_w_o;
wire [255:0] read_data_w;
wire [255:0] mux_read_Data_OR_alu_result_w;
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
PC_Register
PC
(
	.clk(clk),
	.reset(reset),
	.Next_PC(pc_plus_4_w),
	.PC_Value(pc_w)
);


Program_Memory
#(
	.MEMORY_DEPTH(PROGRAM_MEMORY_DEPTH)
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
	.Data1(4),
	
	.Result(pc_plus_4_w)
);


Pipeline_Register
#(
	.N(64)
)
PIPELINE_IF_ID
(
	.clk(clk),
	.reset(reset),
	.pipeline_INPUT({
							pc_w,
							instruction_bus_w
						 }),
	.pipeline_OUTPUT({
							pipeline_if_id_pc_W_o,
							pipeline_if_id_instruction_bus_w_o
						  })
);

//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
Control
CONTROL_UNIT
(
	/****/
	.OP_i(pipeline_if_id_instruction_bus_w_o[6:0]),
	/** outputus**/
	.ALU_Op_o(alu_op_w),
	.ALU_Src_o(alu_src_w),
	.Reg_Write_o(reg_write_w),
	.Mem_to_Reg_o(mem_to_reg_w),
	.Mem_Read_o(mem_read_w),
	.Mem_Write_o(mem_write_w)
);


Register_File
Registers
(
	.clk(clk),
	.reset(reset),
	.Reg_Write_i(pipeline_mem_wb_reg_write_w_o),
	.Write_Register_i(pipeline_mem_wb_instruction_bus_w_11_7_o),
	.Read_Register_1_i(pipeline_if_id_instruction_bus_w_o[19:15]),
	.Read_Register_2_i(pipeline_if_id_instruction_bus_w_o[24:20]),
	.Write_Data_i(mux_read_Data_OR_alu_result_w),
	.Read_Data_1_o(read_data_1_w),
	.Read_Data_2_o(read_data_2_w)

);


Immediate_Unit
Imm_Gen
(  .op_i(pipeline_if_id_instruction_bus_w_o[6:0]),
   .Instruction_bus_i(pipeline_if_id_instruction_bus_w_o),
   .Immediate_o(inmmediate_data_w)
);


Pipeline_Register
#(
	.N(145)
)
PIPELINE_ID_EX
(
	.clk(clk),
	.reset(reset),
	.pipeline_INPUT({
							alu_op_w, //3
							alu_src_w,  //1
							reg_write_w, //1
							mem_to_reg_w, //1
							mem_read_w, //1
							mem_write_w, //1
							pipeline_if_id_pc_W_o, //32
							read_data_1_w, //32
							read_data_2_w, //32
							inmmediate_data_w, //32
							{
							 pipeline_if_id_instruction_bus_w_o[30], //1
							 pipeline_if_id_instruction_bus_w_o[14:12] //3
							},
							pipeline_if_id_instruction_bus_w_o[11:7] //5
						 }),
	.pipeline_OUTPUT({
							
							pipeline_id_ex_alu_op_w_o, //3
							pipeline_id_ex_alu_src_w_o, //1
							pipeline_id_ex_reg_write_w_o, //1
							pipeline_id_ex_mem_to_reg_w_o, //1
							pipeline_id_ex_mem_read_w_o, //1
							pipeline_id_ex_mem_write_w_o, //1
							pipeline_id_ex_pc_W_o,
							pipeline_id_ex_read_data_1_w_o,
							pipeline_id_ex_read_data_2_w_o,
							pipeline_id_ex_immediate_data_w_o,
							pipeline_id_ex_instruction_bus_w_30_14_12_o,
							pipeline_id_ex_instruction_bus_w_11_7_o
						  })
);

//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/

Adder_32_Bits
AddSum
(
	.Data0(pipeline_id_ex_pc_W_o),
	.Data1(pipeline_id_ex_immediate_data_w_o),
	
	.Result(AddSum_result)
);

Multiplexer_2_to_1
#(
	.NBits(32)
)
MUX_DATA_OR_IMM_FOR_ALU
(
	.Selector_i(pipeline_id_ex_alu_src_w_o),
	.Mux_Data_0_i(pipeline_id_ex_read_data_2_w_o),
	.Mux_Data_1_i(pipeline_id_ex_immediate_data_w_o),
	
	.Mux_Output_o(read_data_2_or_imm_w)

);


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
	.A_i(pipeline_id_ex_read_data_1_w_o),
	.B_i(read_data_2_or_imm_w),
	.Zero_o(zero_w),
	.ALU_Result_o(alu_result_w)
);


Pipeline_Register
#(
	.N(106)
)
PIPELINE_EX_MEM
(
	.clk(clk),
	.reset(reset),
	.pipeline_INPUT({
							pipeline_id_ex_reg_write_w_o,
							pipeline_id_ex_mem_to_reg_w_o,
							pipeline_id_ex_mem_write_w_o,
							pipeline_id_ex_mem_read_w_o,
							AddSum_result,
							zero_w,
							alu_result_w,
							pipeline_id_ex_read_data_2_w_o,
							pipeline_id_ex_instruction_bus_w_11_7_o
						 }),
	.pipeline_OUTPUT({
							pipeline_ex_mem_reg_write_w_o,
							pipeline_ex_mem_mem_to_reg_w_o,
							pipeline_ex_mem_mem_write_w_o,
							pipeline_ex_mem_mem_read_w_o,
							pipeline_ex_mem_AddSum_result_w_o,
							pipeline_ex_mem_zero_w_o,
							pipeline_ex_mem_ALU_Result_w_o,
							pipeline_ex_mem_read_data_2_w_o,
							pipeline_ex_mem_instruction_bus_w_11_7_o
						  })
);

//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/


Data_Memory
#(
	.DATA_WIDTH(256)
)
Data_Memory
(
	.clk(clk),
	.Mem_Write_i(pipeline_ex_mem_mem_write_w_o),
	.Mem_Read_i(pipeline_ex_mem_mem_read_w_o),
	.Write_Data_i(pipeline_ex_mem_read_data_2_w_o),
	.Address_i(pipeline_ex_mem_ALU_Result_w_o),
	.Read_Data_o(read_data_w)
);

Pipeline_Register
#(
	.N(295)
)
PIPELINE_MEM_WB
(
	.clk(clk),
	.reset(reset),
	.pipeline_INPUT({
							pipeline_ex_mem_reg_write_w_o,
							pipeline_ex_mem_mem_to_reg_w_o,
							read_data_w,
							pipeline_ex_mem_ALU_Result_w_o,
							pipeline_ex_mem_instruction_bus_w_11_7_o
						 }),
	.pipeline_OUTPUT({
							pipeline_mem_wb_reg_write_w_o,
							pipeline_mem_wb_mem_to_reg_w_o,
							pipeline_mem_wb_read_data_w_o,
							pipeline_mem_wb_ALU_Result_w_o,
							pipeline_mem_wb_instruction_bus_w_11_7_o
						  })
);

//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/
//******************************************************************/

Multiplexer_2_to_1
#(
	.NBits(256)
)
MUX_READ_DATA_OR_ALU_RESULT
(
	.Selector_i(pipeline_mem_wb_mem_to_reg_w_o),
	.Mux_Data_0_i(pipeline_mem_wb_ALU_Result_w_o),
	.Mux_Data_1_i(pipeline_mem_wb_read_data_w_o),
	
	.Mux_Output_o(mux_read_Data_OR_alu_result_w)

);

endmodule

