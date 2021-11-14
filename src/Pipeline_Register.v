/******************************************************************
* Description
*	This is a register of 32-bit that corresponds to the PC counter. 
*	This register does not have an enable signal.
* Version:
*	1.0
* Author:
*	Dr. José Luis Pizano Escalante
* email:
*	luispizano@iteso.mx
* Date:
*	16/08/2021
******************************************************************/

module Pipeline_Register
#(
	parameter N=32
)
(
	input clk,
	input reset,
	input  [N-1:0] pipeline_INPUT,
	
	
	output reg [N-1:0] pipeline_OUTPUT
);

always@(negedge reset or negedge clk) begin
	if(reset==0)
		pipeline_OUTPUT <= 0;
	else	
		pipeline_OUTPUT <= pipeline_INPUT;
end

endmodule
