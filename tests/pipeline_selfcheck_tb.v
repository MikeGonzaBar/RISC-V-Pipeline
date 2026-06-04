`timescale 1ns/1ps

module pipeline_selfcheck_tb;
	localparam integer PROGRAM_DEPTH = 256;
	localparam [31:0] NOP = 32'h00000013;

	reg clk;
	reg reset;
	reg [1023:0] test_name;
	reg [1023:0] wave_file;
	integer errors;
	integer program_len;
	integer idx;
	wire [31:0] debug_pc;
	wire [31:0] debug_instruction;
	wire debug_wb_reg_write;
	wire [4:0] debug_wb_rd;
	wire [31:0] debug_wb_data;
	wire [31:0] debug_t0;
	wire [31:0] debug_t1;
	wire [31:0] debug_t2;
	wire [31:0] debug_s0;
	wire [31:0] debug_s1;
	wire [31:0] debug_s2;
	wire [31:0] debug_s3;

	RISC_V_Single_Cycle
	#(
		.PROGRAM_MEMORY_DEPTH(PROGRAM_DEPTH),
		.DATA_MEMORY_DEPTH(1024),
		.PROGRAM_LOAD_ENABLE(0)
	)
	dut
	(
		.clk(clk),
		.reset(reset),
		.debug_pc_o(debug_pc),
		.debug_instruction_o(debug_instruction),
		.debug_wb_reg_write_o(debug_wb_reg_write),
		.debug_wb_rd_o(debug_wb_rd),
		.debug_wb_data_o(debug_wb_data),
		.debug_t0_o(debug_t0),
		.debug_t1_o(debug_t1),
		.debug_t2_o(debug_t2),
		.debug_s0_o(debug_s0),
		.debug_s1_o(debug_s1),
		.debug_s2_o(debug_s2),
		.debug_s3_o(debug_s3)
	);

	initial begin
		clk = 1'b0;
		forever #5 clk = ~clk;
	end

	initial begin
		if ($value$plusargs("WAVE=%s", wave_file)) begin
			$dumpfile(wave_file);
			$dumpvars(0, pipeline_selfcheck_tb);
		end
	end

	initial begin
		errors = 0;
		reset = 1'b0;
		if (!$value$plusargs("TEST=%s", test_name))
			test_name = "smoke";

		#1;
		clear_program();

		if (test_name == "smoke")
			load_smoke();
		else if (test_name == "raw_forwarding")
			load_raw_forwarding();
		else if (test_name == "load_use_stall")
			load_load_use_stall();
		else if (test_name == "lw_sw_store_forwarding")
			load_lw_sw_store_forwarding();
		else if (test_name == "beq_bne")
			load_beq_bne();
		else if (test_name == "jal_jalr")
			load_jal_jalr();
		else if (test_name == "immediate_edges")
			load_immediate_edges();
		else if (test_name == "memory_offsets")
			load_memory_offsets();
		else if (test_name == "branch_forwarding")
			load_branch_forwarding();
		else if (test_name == "expanded_alu_isa")
			load_expanded_alu_isa();
		else if (test_name == "branch_variants")
			load_branch_variants();
		else if (test_name == "byte_halfword_memory")
			load_byte_halfword_memory();
		else begin
			$display("FAIL: unknown TEST '%0s'", test_name);
			$fatal(1);
		end

		#12;
		reset = 1'b1;
		repeat (80) @(posedge clk);
		#1;

		if (test_name == "smoke")
			check_smoke();
		else if (test_name == "raw_forwarding")
			check_raw_forwarding();
		else if (test_name == "load_use_stall")
			check_load_use_stall();
		else if (test_name == "lw_sw_store_forwarding")
			check_lw_sw_store_forwarding();
		else if (test_name == "beq_bne")
			check_beq_bne();
		else if (test_name == "jal_jalr")
			check_jal_jalr();
		else if (test_name == "immediate_edges")
			check_immediate_edges();
		else if (test_name == "memory_offsets")
			check_memory_offsets();
		else if (test_name == "branch_forwarding")
			check_branch_forwarding();
		else if (test_name == "expanded_alu_isa")
			check_expanded_alu_isa();
		else if (test_name == "branch_variants")
			check_branch_variants();
		else if (test_name == "byte_halfword_memory")
			check_byte_halfword_memory();

		if (errors == 0) begin
			$display("PASS: %0s", test_name);
			$finish;
		end

		$display("FAIL: %0s had %0d error(s)", test_name, errors);
		$fatal(1);
	end

	task clear_program;
		begin
			for (idx = 0; idx < PROGRAM_DEPTH; idx = idx + 1)
				dut.Instruction_memory.rom[idx] = NOP;
			program_len = 1;
		end
	endtask

	task emit;
		input [31:0] instruction;
		begin
			dut.Instruction_memory.rom[program_len] = instruction;
			program_len = program_len + 1;
		end
	endtask

	task check_value;
		input [31:0] actual;
		input [31:0] expected;
		input [255:0] label;
		begin
			if (actual !== expected) begin
				$display("ERROR %0s: expected 0x%08h, got 0x%08h", label, expected, actual);
				errors = errors + 1;
			end
		end
	endtask

	task check_reg;
		input integer reg_index;
		input [31:0] expected;
		input [255:0] label;
		reg [31:0] actual;
		begin
			actual = register_value(reg_index);
			if (actual !== expected) begin
				$display("ERROR %0s: x%0d expected 0x%08h, got 0x%08h", label, reg_index, expected, actual);
				errors = errors + 1;
			end
		end
	endtask

	function [31:0] register_value;
		input integer reg_index;
		begin
			case (reg_index)
				0: register_value = dut.Registers.Intercnection_wire[31:0];
				1: register_value = dut.Registers.Intercnection_wire[63:32];
				2: register_value = dut.Registers.Intercnection_wire[95:64];
				3: register_value = dut.Registers.Intercnection_wire[127:96];
				4: register_value = dut.Registers.Intercnection_wire[159:128];
				5: register_value = dut.Registers.Intercnection_wire[191:160];
				6: register_value = dut.Registers.Intercnection_wire[223:192];
				7: register_value = dut.Registers.Intercnection_wire[255:224];
				8: register_value = dut.Registers.Intercnection_wire[287:256];
				9: register_value = dut.Registers.Intercnection_wire[319:288];
				10: register_value = dut.Registers.Intercnection_wire[351:320];
				11: register_value = dut.Registers.Intercnection_wire[383:352];
				12: register_value = dut.Registers.Intercnection_wire[415:384];
				13: register_value = dut.Registers.Intercnection_wire[447:416];
				14: register_value = dut.Registers.Intercnection_wire[479:448];
				15: register_value = dut.Registers.Intercnection_wire[511:480];
				16: register_value = dut.Registers.Intercnection_wire[543:512];
				17: register_value = dut.Registers.Intercnection_wire[575:544];
				18: register_value = dut.Registers.Intercnection_wire[607:576];
				19: register_value = dut.Registers.Intercnection_wire[639:608];
				20: register_value = dut.Registers.Intercnection_wire[671:640];
				21: register_value = dut.Registers.Intercnection_wire[703:672];
				22: register_value = dut.Registers.Intercnection_wire[735:704];
				23: register_value = dut.Registers.Intercnection_wire[767:736];
				24: register_value = dut.Registers.Intercnection_wire[799:768];
				25: register_value = dut.Registers.Intercnection_wire[831:800];
				26: register_value = dut.Registers.Intercnection_wire[863:832];
				27: register_value = dut.Registers.Intercnection_wire[895:864];
				28: register_value = dut.Registers.Intercnection_wire[927:896];
				29: register_value = dut.Registers.Intercnection_wire[959:928];
				30: register_value = dut.Registers.Intercnection_wire[991:960];
				31: register_value = dut.Registers.Intercnection_wire[1023:992];
				default: register_value = 32'hx;
			endcase
		end
	endfunction

	function [31:0] r_type;
		input [6:0] funct7;
		input [4:0] rs2;
		input [4:0] rs1;
		input [2:0] funct3;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			r_type = {funct7, rs2, rs1, funct3, rd, opcode};
		end
	endfunction

	function [31:0] i_type;
		input integer imm;
		input [4:0] rs1;
		input [2:0] funct3;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			i_type = {imm[11:0], rs1, funct3, rd, opcode};
		end
	endfunction

	function [31:0] s_type;
		input integer imm;
		input [4:0] rs2;
		input [4:0] rs1;
		input [2:0] funct3;
		input [6:0] opcode;
		begin
			s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
		end
	endfunction

	function [31:0] b_type;
		input integer imm;
		input [4:0] rs2;
		input [4:0] rs1;
		input [2:0] funct3;
		input [6:0] opcode;
		reg [12:0] branch_imm;
		begin
			branch_imm = imm[12:0];
			b_type = {branch_imm[12], branch_imm[10:5], rs2, rs1, funct3, branch_imm[4:1], branch_imm[11], opcode};
		end
	endfunction

	function [31:0] u_type;
		input [19:0] imm;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			u_type = {imm, rd, opcode};
		end
	endfunction

	function [31:0] j_type;
		input integer imm;
		input [4:0] rd;
		input [6:0] opcode;
		reg [20:0] jump_imm;
		begin
			jump_imm = imm[20:0];
			j_type = {jump_imm[20], jump_imm[10:1], jump_imm[11], jump_imm[19:12], rd, opcode};
		end
	endfunction

	function [31:0] ADD;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			ADD = r_type(7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SUB;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SUB = r_type(7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011);
		end
	endfunction

	function [31:0] AND_R;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			AND_R = r_type(7'b0000000, rs2, rs1, 3'b111, rd, 7'b0110011);
		end
	endfunction

	function [31:0] OR_R;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			OR_R = r_type(7'b0000000, rs2, rs1, 3'b110, rd, 7'b0110011);
		end
	endfunction

	function [31:0] XOR_R;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			XOR_R = r_type(7'b0000000, rs2, rs1, 3'b100, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SLT;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SLT = r_type(7'b0000000, rs2, rs1, 3'b010, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SLTU;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SLTU = r_type(7'b0000000, rs2, rs1, 3'b011, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SLL;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SLL = r_type(7'b0000000, rs2, rs1, 3'b001, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SRL;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SRL = r_type(7'b0000000, rs2, rs1, 3'b101, rd, 7'b0110011);
		end
	endfunction

	function [31:0] SRA;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			SRA = r_type(7'b0100000, rs2, rs1, 3'b101, rd, 7'b0110011);
		end
	endfunction

	function [31:0] ADDI;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			ADDI = i_type(imm, rs1, 3'b000, rd, 7'b0010011);
		end
	endfunction

	function [31:0] ORI;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			ORI = i_type(imm, rs1, 3'b110, rd, 7'b0010011);
		end
	endfunction

	function [31:0] ANDI;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			ANDI = i_type(imm, rs1, 3'b111, rd, 7'b0010011);
		end
	endfunction

	function [31:0] XORI;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			XORI = i_type(imm, rs1, 3'b100, rd, 7'b0010011);
		end
	endfunction

	function [31:0] SLTI;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			SLTI = i_type(imm, rs1, 3'b010, rd, 7'b0010011);
		end
	endfunction

	function [31:0] SLTIU;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			SLTIU = i_type(imm, rs1, 3'b011, rd, 7'b0010011);
		end
	endfunction

	function [31:0] SLLI;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] shamt;
		begin
			SLLI = {7'b0000000, shamt, rs1, 3'b001, rd, 7'b0010011};
		end
	endfunction

	function [31:0] SRLI;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] shamt;
		begin
			SRLI = {7'b0000000, shamt, rs1, 3'b101, rd, 7'b0010011};
		end
	endfunction

	function [31:0] SRAI;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] shamt;
		begin
			SRAI = {7'b0100000, shamt, rs1, 3'b101, rd, 7'b0010011};
		end
	endfunction

	function [31:0] LUI;
		input [4:0] rd;
		input [19:0] imm;
		begin
			LUI = u_type(imm, rd, 7'b0110111);
		end
	endfunction

	function [31:0] AUIPC;
		input [4:0] rd;
		input [19:0] imm;
		begin
			AUIPC = u_type(imm, rd, 7'b0010111);
		end
	endfunction

	function [31:0] LW;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			LW = i_type(imm, rs1, 3'b010, rd, 7'b0000011);
		end
	endfunction

	function [31:0] LB;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			LB = i_type(imm, rs1, 3'b000, rd, 7'b0000011);
		end
	endfunction

	function [31:0] LH;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			LH = i_type(imm, rs1, 3'b001, rd, 7'b0000011);
		end
	endfunction

	function [31:0] LBU;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			LBU = i_type(imm, rs1, 3'b100, rd, 7'b0000011);
		end
	endfunction

	function [31:0] LHU;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			LHU = i_type(imm, rs1, 3'b101, rd, 7'b0000011);
		end
	endfunction

	function [31:0] SW;
		input [4:0] rs2;
		input [4:0] rs1;
		input integer imm;
		begin
			SW = s_type(imm, rs2, rs1, 3'b010, 7'b0100011);
		end
	endfunction

	function [31:0] SB;
		input [4:0] rs2;
		input [4:0] rs1;
		input integer imm;
		begin
			SB = s_type(imm, rs2, rs1, 3'b000, 7'b0100011);
		end
	endfunction

	function [31:0] SH;
		input [4:0] rs2;
		input [4:0] rs1;
		input integer imm;
		begin
			SH = s_type(imm, rs2, rs1, 3'b001, 7'b0100011);
		end
	endfunction

	function [31:0] BEQ;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BEQ = b_type(imm, rs2, rs1, 3'b000, 7'b1100011);
		end
	endfunction

	function [31:0] BNE;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BNE = b_type(imm, rs2, rs1, 3'b001, 7'b1100011);
		end
	endfunction

	function [31:0] BLT;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BLT = b_type(imm, rs2, rs1, 3'b100, 7'b1100011);
		end
	endfunction

	function [31:0] BGE;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BGE = b_type(imm, rs2, rs1, 3'b101, 7'b1100011);
		end
	endfunction

	function [31:0] BLTU;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BLTU = b_type(imm, rs2, rs1, 3'b110, 7'b1100011);
		end
	endfunction

	function [31:0] BGEU;
		input [4:0] rs1;
		input [4:0] rs2;
		input integer imm;
		begin
			BGEU = b_type(imm, rs2, rs1, 3'b111, 7'b1100011);
		end
	endfunction

	function [31:0] JAL;
		input [4:0] rd;
		input integer imm;
		begin
			JAL = j_type(imm, rd, 7'b1101111);
		end
	endfunction

	function [31:0] JALR;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			JALR = i_type(imm, rs1, 3'b000, rd, 7'b1100111);
		end
	endfunction

	task load_smoke;
		begin
			emit(32'h00000013);
			emit(32'h00000013);
			emit(32'h00000013);
			emit(32'h10010437);
			emit(32'h00000013);
			emit(32'h00000013);
			emit(32'h02446493);
			emit(32'h00100913);
			emit(32'h02000993);
			emit(32'h00000013);
			emit(32'h00491293);
			emit(32'h00000013);
			emit(32'h0049d313);
			emit(32'h00000013);
			emit(32'h00000013);
			emit(32'h406283b3);
		end
	endtask

	task check_smoke;
		begin
			check_reg(5, 32'd16, "smoke t0 slli");
			check_reg(6, 32'd2, "smoke t1 srli");
			check_reg(7, 32'd14, "smoke t2 sub");
			check_reg(8, 32'h10010000, "smoke s0 lui");
			check_reg(9, 32'h10010024, "smoke s1 ori");
			check_reg(18, 32'd1, "smoke s2 addi");
			check_reg(19, 32'd32, "smoke s3 addi");
			check_value(debug_t0, 32'd16, "debug t0");
			check_value(debug_t1, 32'd2, "debug t1");
			check_value(debug_t2, 32'd14, "debug t2");
			check_value(debug_s0, 32'h10010000, "debug s0");
			check_value(debug_s1, 32'h10010024, "debug s1");
			check_value(debug_s2, 32'd1, "debug s2");
			check_value(debug_s3, 32'd32, "debug s3");
		end
	endtask

	task load_immediate_edges;
		begin
			emit(ADDI(5'd0, 5'd0, 123));
			emit(ADDI(5'd1, 5'd0, 0));
			emit(ADDI(5'd2, 5'd0, -1));
			emit(ADDI(5'd3, 5'd2, 1));
			emit(ORI(5'd4, 5'd0, -1));
			emit(SRLI(5'd5, 5'd4, 5'd31));
			emit(SLLI(5'd6, 5'd5, 5'd4));
			emit(SUB(5'd7, 5'd0, 5'd6));
			emit(ADDI(5'd8, 5'd7, -16));
			emit(LUI(5'd9, 20'hfffff));
			emit(ORI(5'd10, 5'd9, 2047));
			emit(ORI(5'd11, 5'd0, -2048));
		end
	endtask

	task check_immediate_edges;
		begin
			check_reg(0, 32'd0, "x0 remains hard-wired zero");
			check_reg(1, 32'd0, "read after ignored x0 write");
			check_reg(2, 32'hffff_ffff, "addi sign-extends -1");
			check_reg(3, 32'd0, "addi wraps negative plus one");
			check_reg(4, 32'hffff_ffff, "ori sign-extends -1");
			check_reg(5, 32'd1, "srli is logical");
			check_reg(6, 32'd16, "slli uses shamt");
			check_reg(7, 32'hffff_fff0, "sub from zero");
			check_reg(8, 32'hffff_ffe0, "addi negative immediate chain");
			check_reg(9, 32'hffff_f000, "lui high immediate");
			check_reg(10, 32'hffff_f7ff, "ori positive edge immediate");
			check_reg(11, 32'hffff_f800, "ori negative edge immediate");
		end
	endtask

	task load_raw_forwarding;
		begin
			emit(ADDI(5'd1, 5'd0, 10));
			emit(ADDI(5'd2, 5'd1, 5));
			emit(ADD(5'd3, 5'd2, 5'd1));
			emit(SUB(5'd4, 5'd3, 5'd2));
			emit(ADD(5'd5, 5'd4, 5'd3));
		end
	endtask

	task check_raw_forwarding;
		begin
			check_reg(1, 32'd10, "raw producer");
			check_reg(2, 32'd15, "raw ex/ex addi");
			check_reg(3, 32'd25, "raw dual operand add");
			check_reg(4, 32'd10, "raw sub");
			check_reg(5, 32'd35, "raw chained add");
		end
	endtask

	task load_load_use_stall;
		begin
			emit(ADDI(5'd1, 5'd0, 0));
			emit(ADDI(5'd2, 5'd0, 37));
			emit(NOP);
			emit(NOP);
			emit(NOP);
			emit(SW(5'd2, 5'd1, 0));
			emit(NOP);
			emit(NOP);
			emit(NOP);
			emit(LW(5'd3, 5'd1, 0));
			emit(ADDI(5'd4, 5'd3, 5));
			emit(ADD(5'd5, 5'd4, 5'd3));
		end
	endtask

	task check_load_use_stall;
		begin
			check_reg(3, 32'd37, "load-use loaded word");
			check_reg(4, 32'd42, "load-use immediate consumer");
			check_reg(5, 32'd79, "load-use forwarded add");
		end
	endtask

	task load_lw_sw_store_forwarding;
		begin
			emit(ADDI(5'd1, 5'd0, 16));
			emit(ADDI(5'd2, 5'd0, 99));
			emit(SW(5'd2, 5'd1, 0));
			emit(LW(5'd3, 5'd1, 0));
			emit(ADDI(5'd4, 5'd0, 100));
			emit(ADDI(5'd5, 5'd0, 20));
			emit(SW(5'd4, 5'd5, 4));
			emit(LW(5'd6, 5'd5, 4));
			emit(LW(5'd7, 5'd1, 0));
			emit(SW(5'd7, 5'd1, 8));
			emit(LW(5'd8, 5'd1, 8));
		end
	endtask

	task check_lw_sw_store_forwarding;
		begin
			check_reg(3, 32'd99, "lw after sw first address");
			check_reg(6, 32'd100, "lw after sw second address");
			check_reg(7, 32'd99, "load before store data");
			check_reg(8, 32'd99, "load-to-store forwarded data");
		end
	endtask

	task load_memory_offsets;
		begin
			emit(ADDI(5'd1, 5'd0, 64));
			emit(ADDI(5'd2, 5'd0, 11));
			emit(SW(5'd2, 5'd1, 0));
			emit(ADDI(5'd3, 5'd0, 22));
			emit(SW(5'd3, 5'd1, 4));
			emit(LW(5'd4, 5'd1, 0));
			emit(LW(5'd5, 5'd1, 4));
			emit(SW(5'd5, 5'd1, -4));
			emit(LW(5'd6, 5'd1, -4));
			emit(ADDI(5'd7, 5'd6, 3));
		end
	endtask

	task check_memory_offsets;
		begin
			check_reg(1, 32'd64, "memory base register");
			check_reg(4, 32'd11, "lw positive offset zero");
			check_reg(5, 32'd22, "lw positive offset four");
			check_reg(6, 32'd22, "sw/lw negative offset");
			check_reg(7, 32'd25, "load-use after negative offset");
		end
	endtask

	task load_beq_bne;
		begin
			emit(ADDI(5'd1, 5'd0, 5));
			emit(ADDI(5'd2, 5'd1, 0));
			emit(BEQ(5'd1, 5'd2, 8));
			emit(ADDI(5'd3, 5'd0, 99));
			emit(ADDI(5'd3, 5'd0, 1));
			emit(BNE(5'd1, 5'd2, 8));
			emit(ADDI(5'd4, 5'd0, 2));
			emit(ADDI(5'd8, 5'd0, 2));
			emit(ADDI(5'd7, 5'd0, 0));
			emit(ADDI(5'd7, 5'd7, 1));
			emit(BNE(5'd7, 5'd8, -4));
			emit(BNE(5'd1, 5'd3, 8));
			emit(ADDI(5'd5, 5'd0, 77));
			emit(ADDI(5'd5, 5'd0, 5));
		end
	endtask

	task check_beq_bne;
		begin
			check_reg(3, 32'd1, "beq taken skipped poison");
			check_reg(4, 32'd2, "bne not taken fallthrough");
			check_reg(7, 32'd2, "backward bne loop");
			check_reg(8, 32'd2, "backward bne limit");
			check_reg(5, 32'd5, "bne taken skipped poison");
		end
	endtask

	task load_jal_jalr;
		begin
			emit(JAL(5'd1, 16));
			emit(ADDI(5'd2, 5'd0, 99));
			emit(ADDI(5'd2, 5'd0, 88));
			emit(ADDI(5'd2, 5'd0, 77));
			emit(ADDI(5'd2, 5'd0, 1));
			emit(ADDI(5'd3, 5'd0, 45));
			emit(JALR(5'd4, 5'd3, 0));
			emit(ADDI(5'd5, 5'd0, 77));
			emit(ADDI(5'd5, 5'd0, 88));
			emit(ADDI(5'd5, 5'd0, 99));
			emit(ADDI(5'd5, 5'd0, 5));
			emit(ADDI(5'd6, 5'd1, 0));
			emit(ADDI(5'd7, 5'd4, 0));
		end
	endtask

	task check_jal_jalr;
		begin
			check_reg(1, 32'd8, "jal link");
			check_reg(2, 32'd1, "jal target");
			check_reg(3, 32'd45, "jalr odd base");
			check_reg(4, 32'd32, "jalr link");
			check_reg(5, 32'd5, "jalr target");
			check_reg(6, 32'd8, "jal link observable");
			check_reg(7, 32'd32, "jalr link observable");
		end
	endtask

	task load_branch_forwarding;
		begin
			emit(ADDI(5'd1, 5'd0, 3));
			emit(ADDI(5'd2, 5'd0, 3));
			emit(BEQ(5'd1, 5'd2, 8));
			emit(ADDI(5'd3, 5'd0, 99));
			emit(ADDI(5'd3, 5'd0, 1));
			emit(ADDI(5'd4, 5'd3, 1));
			emit(BNE(5'd4, 5'd3, 8));
			emit(ADDI(5'd5, 5'd0, 99));
			emit(ADDI(5'd5, 5'd0, 5));
			emit(ADDI(5'd6, 5'd5, 1));
			emit(BEQ(5'd6, 5'd5, 8));
			emit(ADDI(5'd7, 5'd0, 7));
		end
	endtask

	task check_branch_forwarding;
		begin
			check_reg(1, 32'd3, "branch forwarding lhs");
			check_reg(2, 32'd3, "branch forwarding rhs");
			check_reg(3, 32'd1, "beq forwarded compare skipped poison");
			check_reg(4, 32'd2, "bne forwarded producer");
			check_reg(5, 32'd5, "bne forwarded compare skipped poison");
			check_reg(6, 32'd6, "beq not taken forwarded compare");
			check_reg(7, 32'd7, "branch fallthrough after not-taken");
		end
	endtask

	task load_expanded_alu_isa;
		begin
			emit(AUIPC(5'd18, 20'h00001));
			emit(ADDI(5'd1, 5'd0, 240));
			emit(ADDI(5'd2, 5'd0, 51));
			emit(AND_R(5'd3, 5'd1, 5'd2));
			emit(OR_R(5'd4, 5'd1, 5'd2));
			emit(XOR_R(5'd5, 5'd1, 5'd2));
			emit(ADDI(5'd6, 5'd0, -1));
			emit(SLT(5'd7, 5'd6, 5'd1));
			emit(SLTU(5'd8, 5'd6, 5'd1));
			emit(SLTI(5'd9, 5'd6, 0));
			emit(SLTIU(5'd10, 5'd6, 1));
			emit(ADDI(5'd12, 5'd0, 2));
			emit(SLL(5'd11, 5'd2, 5'd12));
			emit(SRL(5'd13, 5'd11, 5'd12));
			emit(SRA(5'd14, 5'd6, 5'd12));
			emit(ANDI(5'd15, 5'd4, 15));
			emit(XORI(5'd16, 5'd15, 85));
			emit(SRAI(5'd17, 5'd6, 4));
		end
	endtask

	task check_expanded_alu_isa;
		begin
			check_reg(18, 32'h0000_1004, "auipc adds current pc");
			check_reg(3, 32'd48, "and register");
			check_reg(4, 32'd243, "or register");
			check_reg(5, 32'd195, "xor register");
			check_reg(7, 32'd1, "slt signed");
			check_reg(8, 32'd0, "sltu unsigned");
			check_reg(9, 32'd1, "slti signed");
			check_reg(10, 32'd0, "sltiu unsigned");
			check_reg(11, 32'd204, "sll register");
			check_reg(13, 32'd51, "srl register");
			check_reg(14, 32'hffff_ffff, "sra register");
			check_reg(15, 32'd3, "andi");
			check_reg(16, 32'd86, "xori");
			check_reg(17, 32'hffff_ffff, "srai");
		end
	endtask

	task load_branch_variants;
		begin
			emit(ADDI(5'd1, 5'd0, -1));
			emit(ADDI(5'd2, 5'd0, 1));
			emit(BLT(5'd1, 5'd2, 8));
			emit(ADDI(5'd3, 5'd0, 99));
			emit(ADDI(5'd3, 5'd0, 3));
			emit(BGE(5'd2, 5'd1, 8));
			emit(ADDI(5'd4, 5'd0, 99));
			emit(ADDI(5'd4, 5'd0, 4));
			emit(BLTU(5'd2, 5'd1, 8));
			emit(ADDI(5'd5, 5'd0, 99));
			emit(ADDI(5'd5, 5'd0, 5));
			emit(BGEU(5'd1, 5'd2, 8));
			emit(ADDI(5'd6, 5'd0, 99));
			emit(ADDI(5'd6, 5'd0, 6));
			emit(BLT(5'd2, 5'd1, 8));
			emit(ADDI(5'd7, 5'd0, 7));
			emit(BGEU(5'd2, 5'd1, 8));
			emit(ADDI(5'd8, 5'd0, 8));
		end
	endtask

	task check_branch_variants;
		begin
			check_reg(3, 32'd3, "blt signed taken");
			check_reg(4, 32'd4, "bge signed taken");
			check_reg(5, 32'd5, "bltu unsigned taken");
			check_reg(6, 32'd6, "bgeu unsigned taken");
			check_reg(7, 32'd7, "blt signed not taken");
			check_reg(8, 32'd8, "bgeu unsigned not taken");
		end
	endtask

	task load_byte_halfword_memory;
		begin
			emit(ADDI(5'd1, 5'd0, 96));
			emit(ADDI(5'd2, 5'd0, -128));
			emit(SB(5'd2, 5'd1, 0));
			emit(LB(5'd3, 5'd1, 0));
			emit(LBU(5'd4, 5'd1, 0));
			emit(ADDI(5'd5, 5'd0, 127));
			emit(SB(5'd5, 5'd1, 3));
			emit(LBU(5'd6, 5'd1, 3));
			emit(ADDI(5'd7, 5'd0, -2048));
			emit(SLLI(5'd7, 5'd7, 5'd4));
			emit(ORI(5'd7, 5'd7, 1));
			emit(SH(5'd7, 5'd1, 4));
			emit(LH(5'd8, 5'd1, 4));
			emit(LHU(5'd9, 5'd1, 4));
			emit(ADDI(5'd10, 5'd0, 466));
			emit(SH(5'd10, 5'd1, 6));
			emit(LHU(5'd11, 5'd1, 6));
			emit(LW(5'd12, 5'd1, 4));
		end
	endtask

	task check_byte_halfword_memory;
		begin
			check_reg(3, 32'hffff_ff80, "lb sign extends byte");
			check_reg(4, 32'h0000_0080, "lbu zero extends byte");
			check_reg(6, 32'h0000_007f, "sb high byte lane");
			check_reg(8, 32'hffff_8001, "lh sign extends low halfword");
			check_reg(9, 32'h0000_8001, "lhu zero extends low halfword");
			check_reg(11, 32'h0000_01d2, "sh high halfword lane");
			check_reg(12, 32'h01d2_8001, "word view of halfword lanes");
		end
	endtask
endmodule
