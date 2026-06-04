`timescale 1ns/1ps

module random_reference_tb;
	localparam integer PROGRAM_DEPTH = 256;
	localparam integer DATA_MEMORY_DEPTH = 1024;
	localparam integer REF_DATA_WORDS = 64;
	localparam integer DEFAULT_RANDOM_COUNT = 48;
	localparam [31:0] NOP = 32'h00000013;

	reg clk;
	reg reset;
	reg [1023:0] wave_file;
	reg [31:0] rng_state;
	reg [31:0] ref_regs[0:31];
	reg [31:0] ref_mem[0:REF_DATA_WORDS-1];
	integer errors;
	integer program_len;
	integer idx;
	integer random_count;
	integer seed_arg;
	integer run_cycles;

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
		.DATA_MEMORY_DEPTH(DATA_MEMORY_DEPTH),
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
			$dumpvars(0, random_reference_tb);
		end
	end

	initial begin
		errors = 0;
		reset = 1'b0;
		seed_arg = 32'h1ace_b00c;
		random_count = DEFAULT_RANDOM_COUNT;

		if (!$value$plusargs("SEED=%d", seed_arg))
			seed_arg = 32'h1ace_b00c;
		if (!$value$plusargs("COUNT=%d", random_count))
			random_count = DEFAULT_RANDOM_COUNT;
		if (random_count < 0)
			random_count = 0;
		else if (random_count > 180)
			random_count = 180;

		rng_state = seed_arg[31:0];
		clear_reference();
		clear_program();
		load_warmup_program();
		generate_random_program(random_count);

		$display("INFO: random_reference seed=%0d count=%0d program_words=%0d",
		         seed_arg, random_count, program_len);

		#12;
		reset = 1'b1;
		run_cycles = program_len + 24;
		repeat (run_cycles) @(posedge clk);
		#1;

		check_all_registers();
		check_reference_memory();
		check_debug_outputs();

		if (errors == 0) begin
			$display("PASS: random_reference seed=%0d count=%0d", seed_arg, random_count);
			$finish;
		end

		$display("FAIL: random_reference seed=%0d count=%0d had %0d error(s)",
		         seed_arg, random_count, errors);
		$fatal(1);
	end

	task clear_reference;
		begin
			for (idx = 0; idx < 32; idx = idx + 1)
				ref_regs[idx] = 32'd0;
			for (idx = 0; idx < REF_DATA_WORDS; idx = idx + 1)
				ref_mem[idx] = 32'd0;
		end
	endtask

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
			if (program_len >= PROGRAM_DEPTH) begin
				$display("FAIL: generated program exceeded PROGRAM_DEPTH=%0d", PROGRAM_DEPTH);
				$fatal(1);
			end
			dut.Instruction_memory.rom[program_len] = instruction;
			program_len = program_len + 1;
		end
	endtask

	task next_random;
		output [31:0] value;
		begin
			rng_state = (rng_state * 32'd1664525) + 32'd1013904223;
			value = rng_state;
		end
	endtask

	function [31:0] sext12;
		input integer imm;
		begin
			sext12 = {{20{imm[11]}}, imm[11:0]};
		end
	endfunction

	task ref_write;
		input [4:0] rd;
		input [31:0] value;
		begin
			if (rd != 5'd0)
				ref_regs[rd] = value;
			ref_regs[0] = 32'd0;
		end
	endtask

	task issue_add;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			emit(ADD(rd, rs1, rs2));
			ref_write(rd, ref_regs[rs1] + ref_regs[rs2]);
		end
	endtask

	task issue_sub;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] rs2;
		begin
			emit(SUB(rd, rs1, rs2));
			ref_write(rd, ref_regs[rs1] - ref_regs[rs2]);
		end
	endtask

	task issue_addi;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			emit(ADDI(rd, rs1, imm));
			ref_write(rd, ref_regs[rs1] + sext12(imm));
		end
	endtask

	task issue_ori;
		input [4:0] rd;
		input [4:0] rs1;
		input integer imm;
		begin
			emit(ORI(rd, rs1, imm));
			ref_write(rd, ref_regs[rs1] | sext12(imm));
		end
	endtask

	task issue_slli;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] shamt;
		begin
			emit(SLLI(rd, rs1, shamt));
			ref_write(rd, ref_regs[rs1] << shamt);
		end
	endtask

	task issue_srli;
		input [4:0] rd;
		input [4:0] rs1;
		input [4:0] shamt;
		begin
			emit(SRLI(rd, rs1, shamt));
			ref_write(rd, ref_regs[rs1] >> shamt);
		end
	endtask

	task issue_lui;
		input [4:0] rd;
		input [19:0] imm;
		begin
			emit(LUI(rd, imm));
			ref_write(rd, {imm, 12'b0});
		end
	endtask

	task issue_sw_abs;
		input [4:0] rs2;
		input integer byte_addr;
		integer word_addr;
		begin
			word_addr = byte_addr >> 2;
			emit(SW(rs2, 5'd0, byte_addr));
			ref_mem[word_addr] = ref_regs[rs2];
		end
	endtask

	task issue_lw_abs;
		input [4:0] rd;
		input integer byte_addr;
		integer word_addr;
		begin
			word_addr = byte_addr >> 2;
			emit(LW(rd, 5'd0, byte_addr));
			ref_write(rd, ref_mem[word_addr]);
		end
	endtask

	task load_warmup_program;
		begin
			issue_addi(5'd1, 5'd0, 17);
			issue_addi(5'd2, 5'd0, -9);
			issue_lui(5'd3, 20'h00010);
			issue_ori(5'd4, 5'd3, 291);
			issue_slli(5'd5, 5'd1, 5'd3);
			issue_sub(5'd6, 5'd5, 5'd2);
			issue_sw_abs(5'd1, 0);
			issue_sw_abs(5'd2, 4);
			issue_sw_abs(5'd4, 8);
			issue_lw_abs(5'd7, 8);
			issue_add(5'd8, 5'd7, 5'd1);
		end
	endtask

	task generate_random_program;
		input integer count;
		integer n;
		integer op;
		integer imm;
		integer byte_addr;
		reg [31:0] r0;
		reg [31:0] r1;
		reg [31:0] r2;
		reg [4:0] rd;
		reg [4:0] rs1;
		reg [4:0] rs2;
		reg [4:0] consumer_rd;
		begin
			for (n = 0; n < count; n = n + 1) begin
				next_random(r0);
				next_random(r1);
				next_random(r2);
				op = r0[3:0] % 9;
				rd = r1[4:0];
				rs1 = r1[12:8];
				rs2 = r2[4:0];
				imm = r2[11:0];
				if (r2[11])
					imm = imm - 4096;
				if ((n % 13) == 0)
					rd = 5'd0;

				case (op)
					0: issue_addi(rd, rs1, imm);
					1: issue_add(rd, rs1, rs2);
					2: issue_sub(rd, rs1, rs2);
					3: issue_ori(rd, rs1, imm);
					4: issue_slli(rd, rs1, r2[4:0]);
					5: issue_srli(rd, rs1, r2[4:0]);
					6: begin
						byte_addr = {r2[5:0], 2'b00};
						issue_sw_abs(rs2, byte_addr);
					end
					7: begin
						byte_addr = {r2[5:0], 2'b00};
						if ((n % 5) == 0 && rd == 5'd0)
							rd = 5'd1;
						issue_lw_abs(rd, byte_addr);
						if ((n % 5) == 0 && (n + 1) < count) begin
							consumer_rd = (rd == 5'd31) ? 5'd1 : (rd + 5'd1);
							issue_addi(consumer_rd, rd, 3);
							n = n + 1;
						end
					end
					default: issue_lui(rd, r2[19:0]);
				endcase
			end
		end
	endtask

	task check_all_registers;
		begin
			for (idx = 0; idx < 32; idx = idx + 1)
				check_reg(idx, ref_regs[idx]);
		end
	endtask

	task check_reference_memory;
		begin
			for (idx = 0; idx < REF_DATA_WORDS; idx = idx + 1) begin
				if (dut.Data_memory.ram[idx] !== ref_mem[idx]) begin
					$display("ERROR mem[%0d]: expected 0x%08h, got 0x%08h",
					         idx, ref_mem[idx], dut.Data_memory.ram[idx]);
					errors = errors + 1;
				end
			end
		end
	endtask

	task check_debug_outputs;
		begin
			check_value(debug_t0, ref_regs[5], "debug t0");
			check_value(debug_t1, ref_regs[6], "debug t1");
			check_value(debug_t2, ref_regs[7], "debug t2");
			check_value(debug_s0, ref_regs[8], "debug s0");
			check_value(debug_s1, ref_regs[9], "debug s1");
			check_value(debug_s2, ref_regs[18], "debug s2");
			check_value(debug_s3, ref_regs[19], "debug s3");
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
		reg [31:0] actual;
		begin
			actual = register_value(reg_index);
			if (actual !== expected) begin
				$display("ERROR x%0d: expected 0x%08h, got 0x%08h", reg_index, expected, actual);
				errors = errors + 1;
			end
		end
	endtask

	function [31:0] register_value;
		input integer reg_index;
		begin
			register_value = dut.Registers.Intercnection_wire[(reg_index * 32) +: 32];
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

	function [31:0] u_type;
		input [19:0] imm;
		input [4:0] rd;
		input [6:0] opcode;
		begin
			u_type = {imm, rd, opcode};
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

	function [31:0] LUI;
		input [4:0] rd;
		input [19:0] imm;
		begin
			LUI = u_type(imm, rd, 7'b0110111);
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

	function [31:0] SW;
		input [4:0] rs2;
		input [4:0] rs1;
		input integer imm;
		begin
			SW = s_type(imm, rs2, rs1, 3'b010, 7'b0100011);
		end
	endfunction
endmodule
