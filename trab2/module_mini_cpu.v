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
	reg			start_lcd = 0;	//indica se o lcd deve atualizar
	reg			rst = 1;	//pulso para simular o rst do lcd
	reg			finish_lcd = 1;	//indica se o lcd já atualizou(permite que a cpu mude de estado)
			
	wire			done;		//verifica se o lcd ja atualizou no modulo
	
	//sequencial
	always@ (*) begin
		case(state)
			LCD_FETCH: if(start_lcd && done) finish_lcd <= 1;
			
			default: begin
				finish_lcd <= 0;
			end
		endcase
	end
	
	//combinacional
	always@(posedge clk) begin
		case(state)
			OFF: begin		//estado desligado
				if(!button_on) begin
					on <= 1;	//<- deve ligar
					state <= PULSE;	//entra no estado de transição quando o botão for pressionado
				end else begin
					rst <= 1;
					state <= state;
				end
			end
				
			PULSE: begin		//transição Wait <-> OFF ou Wait <-> Decode quando o botão for solto
				if(on && button_on) begin
					rst <= 1;
					state <= WAIT;
				end
				else if(!on && button_on) begin
					rst <= 1;
					state <= OFF;
				end
				
				else if(on && send && button_send) begin
					send <= 0;
					state <= DECODE;
				end
				else begin
					rst <= 0;
					state <= state;
				end
			end
			
			WAIT: begin		//estado de espera da entrada
				if(!button_send) begin
					send <= 1; //<- está enviando uma entrada
					state <= PULSE;
				end
				
				else if(!button_on == 1) begin
					on <= 0; //<- deve desligar
					state <= PULSE;
				end
				
				else begin
					start <= 0;
					state <= state;
				end
				rst <= 1;
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
			
			LCD_FETCH:
				if(finish_lcd) begin
					start_lcd <= 1;
					state <= WAIT;
				end
				
				else if(!start)begin
					start <= 1;
					state <= state;
				end
				
				else if(start) begin
					ram[reg1] <= ram_reg;
					start_lcd <= 0;
					state <= state;
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
		.rst						(button_on),
		.opcode					(opcode),
		.destino					(reg1),
		.valor_destino			(ram_reg),
		.button_on				(button_on),
		.button_send			(button_send),
    // Saídas para o LCD
		.lcd_data				(lcd_data),
		.lcd_rs					(lcd_rs),
		.lcd_rw					(lcd_rw),
		.lcd_e					(lcd_e),
		.sinal					(done)
	);
	
	
	

endmodule