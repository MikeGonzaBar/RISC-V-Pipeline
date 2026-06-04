`timescale 1ns/1ps

module default_program_file_tb;
	reg clk;
	reg reset;
	reg [1023:0] wave_file;
	integer errors;

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

	RISC_V_Single_Cycle dut
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
			$dumpvars(0, default_program_file_tb);
		end
	end

	initial begin
		errors = 0;
		reset = 1'b0;
		#12;
		reset = 1'b1;

		repeat (80) @(posedge clk);
		#1;

		check_value(debug_t0, 32'd16, "default ROM debug t0");
		check_value(debug_t1, 32'd2, "default ROM debug t1");
		check_value(debug_t2, 32'd14, "default ROM debug t2");
		check_value(debug_s0, 32'h10010000, "default ROM debug s0");
		check_value(debug_s1, 32'h10010024, "default ROM debug s1");
		check_value(debug_s2, 32'd1, "default ROM debug s2");
		check_value(debug_s3, 32'd32, "default ROM debug s3");
		check_known(debug_pc, "debug pc");
		check_known(debug_instruction, "debug instruction");
		check_known({31'b0, debug_wb_reg_write}, "debug wb reg write");
		check_known({27'b0, debug_wb_rd}, "debug wb rd");
		check_known(debug_wb_data, "debug wb data");

		if (errors == 0) begin
			$display("PASS: default_program_file");
			$finish;
		end

		$display("FAIL: default_program_file had %0d error(s)", errors);
		$fatal(1);
	end

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

	task check_known;
		input [31:0] actual;
		input [255:0] label;
		begin
			if (^actual === 1'bx) begin
				$display("ERROR %0s is unknown: 0x%08h", label, actual);
				errors = errors + 1;
			end
		end
	endtask
endmodule
