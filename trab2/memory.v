module memory
(
	input [3:0] state,
	input [3:0] addr,
	input [15:0] data,
	input we,
	input clk,
	input [2:0] op,
	output reg [15:0] q,
	output reg finish
);

	parameter OFF = 8, DECODE = 9, EXECUTE = 10, LCD_FETCH = 11, WAIT = 12, PULSE = 13;
	parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7;
	reg [15:0] ram [15:0];
	reg [3:0] addr_reg = 0;
	
	always@(posedge clk) begin
		case(op)
			LOAD: begin
				if(we) ram[addr] <= data;
				addr_reg <= addr;
				finish <= 1;
			end
			CLEAR: begin
				ram[0] <= 0;
				ram[1] <= 0;
				ram[2] <= 0;
				ram[3] <= 0;
				ram[4] <= 0;
				ram[5] <= 0;
				ram[6] <= 0;
				ram[7] <= 0;
				ram[8] <= 0;
				ram[9] <= 0;
				ram[10] <= 0;
				ram[11] <= 0;
				ram[12] <= 0;
				ram[13] <= 0;
				ram[14] <= 0;
				ram[15] <= 0;
				finish <= 1;
			end
			default: finish <= 0;
		endcase
	end
	
	always@(*) begin
		q = ram[addr_reg];
	end

endmodule