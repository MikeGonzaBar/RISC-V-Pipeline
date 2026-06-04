`timescale 1ns/1ps

/******************************************************************
* Description
*   RV32 immediate generator for I, S, B, U, and J instruction forms.
******************************************************************/
module Immediate_Unit
(
    input [6:0] op_i,
    input [31:0] Instruction_bus_i,

    output reg [31:0] Immediate_o
);

localparam R_TYPE  = 7'h33;
localparam I_TYPE  = 7'h13;
localparam LOAD    = 7'h03;
localparam STORE   = 7'h23;
localparam BRANCH  = 7'h63;
localparam AUIPC   = 7'h17;
localparam LUI     = 7'h37;
localparam JAL     = 7'h6f;
localparam JALR    = 7'h67;

always @(*) begin
    case (op_i)
        I_TYPE,
        LOAD,
        JALR:
            Immediate_o = {{20{Instruction_bus_i[31]}}, Instruction_bus_i[31:20]};

        STORE:
            Immediate_o = {{20{Instruction_bus_i[31]}}, Instruction_bus_i[31:25], Instruction_bus_i[11:7]};

        BRANCH:
            Immediate_o = {{19{Instruction_bus_i[31]}}, Instruction_bus_i[31], Instruction_bus_i[7],
                           Instruction_bus_i[30:25], Instruction_bus_i[11:8], 1'b0};

        AUIPC,
        LUI:
            Immediate_o = {Instruction_bus_i[31:12], 12'b0};

        JAL:
            Immediate_o = {{11{Instruction_bus_i[31]}}, Instruction_bus_i[31], Instruction_bus_i[19:12],
                           Instruction_bus_i[20], Instruction_bus_i[30:21], 1'b0};

        R_TYPE:
            Immediate_o = 32'b0;

        default:
            Immediate_o = 32'b0;
    endcase
end

endmodule
