module module_mini_cpu (
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
	wire [15:0]	ram_reg;	//registrador auxiliar da ram
	reg [3:0] 	state = OFF;
	reg [2:0] 	opcode;
	reg [3:0] 	reg1;
	reg [3:0] 	reg2;
	reg [3:0] 	reg3;
	reg [7:0] 	imm;
	reg [7:0] 	n2;
	reg		 	on = 0;	//indica se deve desligar/ligar
	reg		 	send = 0;	//indica se há alguma entrada enviada até o momento
	reg		 	we = 0;
	reg [15:0]	to_storage1;	//registradores auxiliares
	reg [15:0] 	to_storage2; 
	wire			finish;	//indica se a operação e o armazenamento foi realizado para atualizar o LCD
	reg			start = 0;	//indica se o armazemento de informação deve começar
	
	//combinacional
	always@(posedge clk) begin
		case(state)
			OFF: begin
				if(!button_on == 1) begin
					on <= 1;
					state <= PULSE;
				end else begin
					state <= state;
				end
			end
				
			PULSE: begin		//transição Wait <-> OFF ou Wait <-> Decode quando o botão for solto
				if(on == 1 && !button_on == 0) state <= WAIT;
				else if(on == 0 && !button_on == 0) state <= OFF;
				else if(send == 1 && !button_send == 0) begin
					send <= 0;
					state <= DECODE;
				end
				else state <= state;
			end
			
			WAIT: begin		//estado de espera da entrada
				if(!button_send == 1) begin
					send <= 1; //<- está enviando uma entrada
					state <= PULSE;
				end
				
				else if(!button_on == 1) begin
					on <= 0; //<- deve desligar
					state <= PULSE;
				end
				
				else begin
					state <= state;
					start <= 0;
				end
			end
			
			DECODE: begin		//divide a entrada para seus respectivos lugares para a operação
				opcode <= data[17:15];
				reg1 <= data[14:11];
				reg2 <= data[10:7];
				reg3 <= data[6:3];
				imm <= data[6:0];
				state <= EXECUTE;
			end
			
			EXECUTE: begin		//executa a devida operação com os dados fornecidos
				//troca de estado
				if(finish) begin
					start <= 0;
					state <= LCD_FETCH;
				end
					
				else begin
					//garantir execução
					state <= state;
					case(opcode) 
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
			
			LCD_FETCH: begin
				if(!start) begin
					start <= 1;
					state <= state;
				end else begin
					ram[reg1] <= ram_reg;
					start <= 0;
					state <= WAIT;
				end
			end
			
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
		.q				(ram_reg),
		.finish		(finish)
	);
	
	
	lcd_controller_top controller (
		.clk						(clk),
		.rst						(1'b1),
		.opcode					(opcode),
		.destino					(reg1),
		.valor_destino			(ram_reg),
		.button_on				(button_on),
		.button_send			(button_send),
    // Saídas para o LCD
		.lcd_data					(lcd_data),
		.lcd_rs					(lcd_rs),
		.lcd_rw					(lcd_rw),
		.lcd_e						(lcd_e),
		.sinal						(done)
	);
	
	
	

endmodule