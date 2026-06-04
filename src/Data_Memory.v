`timescale 1ns/1ps

/******************************************************************
* Description
*   Word-addressed RV32 data memory.
******************************************************************/
module Data_Memory
#(
    parameter DATA_WIDTH = 32,
    parameter MEMORY_DEPTH = 128
)
(
    input clk,
    input Mem_Write_i,
    input Mem_Read_i,
    input [DATA_WIDTH-1:0] Write_Data_i,
    input [DATA_WIDTH-1:0] Address_i,
    input [2:0] funct3_i,

    output reg [DATA_WIDTH-1:0] Read_Data_o
);

function integer clog2;
    input integer value;
    integer i;
    begin
        value = value - 1;
        for (i = 0; value > 0; i = i + 1) begin
            value = value >> 1;
        end
        clog2 = i;
    end
endfunction

localparam ADDRESS_WIDTH = clog2(MEMORY_DEPTH);

wire [ADDRESS_WIDTH-1:0] real_address;
integer index;

assign real_address = Address_i[ADDRESS_WIDTH+1:2];

reg [DATA_WIDTH-1:0] ram[0:MEMORY_DEPTH-1];

wire [31:0] read_word_w;
wire [7:0] read_byte_w;
wire [15:0] read_halfword_w;

assign read_word_w = ram[real_address];
assign read_byte_w = (Address_i[1:0] == 2'b00) ? read_word_w[7:0] :
                     (Address_i[1:0] == 2'b01) ? read_word_w[15:8] :
                     (Address_i[1:0] == 2'b10) ? read_word_w[23:16] :
                                                  read_word_w[31:24];
assign read_halfword_w = Address_i[1] ? read_word_w[31:16] : read_word_w[15:0];

initial begin
    for (index = 0; index < MEMORY_DEPTH; index = index + 1) begin
        ram[index] = {DATA_WIDTH{1'b0}};
    end
end

always @(posedge clk) begin
    if (Mem_Write_i) begin
        case (funct3_i)
            3'b000: begin
                case (Address_i[1:0])
                    2'b00: ram[real_address][7:0] <= Write_Data_i[7:0];
                    2'b01: ram[real_address][15:8] <= Write_Data_i[7:0];
                    2'b10: ram[real_address][23:16] <= Write_Data_i[7:0];
                    2'b11: ram[real_address][31:24] <= Write_Data_i[7:0];
                    default: ram[real_address][7:0] <= Write_Data_i[7:0];
                endcase
            end

            3'b001: begin
                if (Address_i[1]) begin
                    ram[real_address][31:16] <= Write_Data_i[15:0];
                end
                else begin
                    ram[real_address][15:0] <= Write_Data_i[15:0];
                end
            end

            default:
                ram[real_address] <= Write_Data_i;
        endcase
    end
end

always @(*) begin
    if (Mem_Read_i) begin
        case (funct3_i)
            3'b000: Read_Data_o = {{24{read_byte_w[7]}}, read_byte_w};
            3'b001: Read_Data_o = {{16{read_halfword_w[15]}}, read_halfword_w};
            3'b010: Read_Data_o = read_word_w;
            3'b100: Read_Data_o = {24'b0, read_byte_w};
            3'b101: Read_Data_o = {16'b0, read_halfword_w};
            default: Read_Data_o = read_word_w;
        endcase
    end
    else begin
        Read_Data_o = {DATA_WIDTH{1'b0}};
    end
end

endmodule
