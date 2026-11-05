module ula 
(
	input [3:0] state,
	input signed [15:0] n1,
	input signed [15:0] n2,
	input [2:0] op,
	output [15:0] result
);

	parameter OFF = 8, DECODE = 9, EXECUTE = 10, LCD_FETCH = 11, WAIT = 12, PULSE = 13;
	parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7;
	reg [15:0] result_reg;
	always@(*) begin
			case(op)
				ADD: result_reg <= n1 + n2;
				ADDI: result_reg <= n1 + n2;
				SUB: result_reg <= n1 - n2;
				SUBI: result_reg <= n1 - n2;
				MUL: result_reg <= n1 * n2;
				default: result_reg <= n1 + n2;
			endcase
	end
	
	assign result = result_reg;
	
endmodule