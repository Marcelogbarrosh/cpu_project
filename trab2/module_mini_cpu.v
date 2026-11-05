module module_mini_cpu 
(
	input [17:0]  data,
	input 		  button_on,
	input			  button_send,
	input         clk,

   // Saídas para o LCD
   output  [7:0] lcd_data,
   output        lcd_rs,
   output        lcd_rw,
   output        lcd_e

);

	parameter OFF = 8, DECODE = 9, EXECUTE = 10, LCD_FETCH = 11, WAIT = 12, PULSE = 13;
	parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7;
	reg [15:0] ram [15:0];
	reg [3:0] state = OFF;
	reg [2:0] opcode;
	reg [3:0] reg1;
	reg [3:0] reg2;
	reg [3:0] reg3;
	reg [7:0] imm;
	reg		 confirm_s = 0;
	reg 		 confirm_c = 0;
	reg		 on = 0;
	reg		 send = 0;
	
	//sequencial
	always@ (*) begin
		case(state)
			LCD_FETCH: begin
				
			end
			
			OFF: begin
				if(!confirm_s) begin
					confirm_s <= 1;
				end
			end
			
			default: begin
				lcd_data <= lcd_data;
				lcd_rs <= lcd_rs;
				lcd_rw <= lcd_rw;
				lcd_e <= lcd_e;
			end
		endcase
	end
	
	//combinacional
	always@(posedge clk) begin
		case(state)
			OFF: begin
				if(!button_on == 1) begin
					state <= PULSE
					on <= 1;
				end
			end
				
			PULSE: begin
				if(on == 1 & !button_on == 0) state <= WAIT;
				else if(send == 1 & button_send == 1) begin
					state <= DECODE;
					send <= 0;
				end else if(on == 0 & !button_on == 0) state <= OFF:
				else state <= state;
			end
			
			WAIT: begin
				if(!button_send == 1) begin
					state <= PULSE;
					send <= 1;
				end
				
				else if(!button_on == 1) begin
					state <= PULSE;
					on <= 0;
				end
			end
			
			DECODE: begin
				opcode <= data[17:15];
				reg1 <= data[14:11];
				reg2 <= data[10:7];
				reg3 <= data[6:3];
				imm <= data[6:0];
			end
			
			EXECUTE: begin
				if(opcode == 0 | opcode == 6) begin
					memory mem (
						.addr		(reg1),
						.data		(imm),
						.we		(1'b1),
						.clk		(clk),
						.op		(opcode),
						.q			(ram[reg1])
					);
				end else if(opcode == 7) begin
					memory mem2 (
						.addr		(reg1),
						.data		(imm),
						.we		(1'b0),
						.clk		(clk),
						.op		(opcode),
						.q			(ram[reg1])
					);
				end else if(opcode == 1 | opcode == 3) begin
					ula alu(
						.n1		(ram[reg2]),
						.n2		(ram[reg3]),
						.op		(opcode),
						.result	(ram[reg1]),
					);
				end else begin
					ula alu2(
						.n1		(ram[reg2]),
						.n2		(ram[imm]),
						.op		(opcode),
						.result	(ram[reg1]),
					);
				end
				
				state <= LCD_FETCH;
				blz_c <= 1;
			end
			
			LCD_FETCH:
				if(blz_s) state <= WAIT;
				else state <= state;
			
			default: state <= state;
		endcase
	end
	
	

endmodule