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
	reg [15:0] 	ram [15:0];
	reg [3:0] 	state = OFF;
	reg [2:0] 	opcode;
	reg [3:0] 	reg1;
	reg [3:0] 	reg2;
	reg [3:0] 	reg3;
	reg [7:0] 	imm;
	reg [7:0] 	n2;
	reg		 	on = 0;
	reg		 	send = 0;
	reg		 	we;
	reg [15:0]	to_storage;
	reg			finish = 0;
	reg			start = 0;
	
	//sequencial
	always@ (*) begin
		case(state)
			LCD_FETCH: begin
				if() begin
					//modulo lcd
				end
			end
			
			OFF: begin
				if() begin
					//modulo lcd
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
					state <= PULSE;
					on <= 1;
				end
			end
				
			PULSE: begin
				if(on == 1 && !button_on == 0) state <= WAIT;
				else if(send == 1 && button_send == 1) begin
					state <= DECODE;
					send <= 0;
				end else if(on == 0 && !button_on == 0) begin
					state <= OFF;
				end else state <= state;
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
				state <= EXECUTE;
			end
			
			EXECUTE: begin
				//troca de estado
				if(finish) begin
					state <= LCD_FETCH;
					start = 0;
				end
					
				else begin
					//garantir execução
					state <= state;
					case(op) 
						ADD: n2 <= ram[reg3];
						ADDI: n2 <= imm;
						SUB: n2 <= ram[reg3];
						SUBI: n2 <= imm;
						MUL: n2 <= imm;
						LOAD: we <= 0;
						DISPLAY: we <= 1;
						default: n2 <= ram[reg3];
					endcase
					start <= 1;
				end
			end
			
			LCD_FETCH:
				if() begin
					state <= WAIT;
				end
				else state <= state;
			
			default: state <= state;
		endcase
	end
	
	ula alu (
		.state		(state),
		.n1			(ram[reg2]),
		.n2			(n2),
		.op			(opcode),
		.result		(to_storage)
	);
	
	memory mem (
		.state		(state),
		.addr			(reg1),
		.data			(to_storage),
		.we			(we),
		.clk			(start),
		.op			(opcode),
		.q				(ram[reg1]),
		.finish		(finish)
	);
	
	
	

endmodule