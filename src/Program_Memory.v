`timescale 1ns/1ps

/******************************************************************
* Description
*   Portable ROM program memory for the RISC-V processor.
******************************************************************/
module Program_Memory
#(
    parameter MEMORY_DEPTH = 64,
    parameter DATA_WIDTH = 32,
    parameter PROGRAM_FILE = "src/text.dat",
    parameter PROGRAM_INIT_WORDS = 0,
    parameter PROGRAM_LOAD_ENABLE = 1
)
(
    input [(DATA_WIDTH-1):0] Address_i,
    output reg [(DATA_WIDTH-1):0] Instruction_o
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

reg [DATA_WIDTH-1:0] rom[0:MEMORY_DEPTH-1];

initial begin
    for (index = 0; index < MEMORY_DEPTH; index = index + 1) begin
        rom[index] = 32'h00000013;
    end

    if (PROGRAM_LOAD_ENABLE != 0) begin
        if (PROGRAM_INIT_WORDS == 0) begin
            $readmemh(PROGRAM_FILE, rom);
        end
        else begin
            $readmemh(PROGRAM_FILE, rom, 0, PROGRAM_INIT_WORDS - 1);
        end
    end
end

always @(real_address) begin
    Instruction_o = rom[real_address];
end

endmodule
