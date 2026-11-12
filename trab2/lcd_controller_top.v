
module lcd_controller_top (
    input  wire       clk,
    input  wire       rst,
	 input wire[2:0]    opcode,
	 input wire[3:0]   destino,
	 input wire [15:0]  valor_destino,
	 input wire 		button_on,
	 input wire 		button_send,
    // Saídas para o LCD
    output wire  [7:0] lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e,
	 output reg			  sinal
);
	
    // -----------------------------------------------------------------------
    // Instância do módulo de inicialização
    // -----------------------------------------------------------------------
    wire [7:0] init_data;
    wire       init_rs;
    wire       init_rw;
    wire       init_e;
    wire       init_done;

    reg        start_init;  // gerado pelo controlador

    lcd_init_hd44780 lcd_init (
        .clk      (clk),
        .rst      (rst),
        .start    (start_init),
        .done     (init_done),
        .lcd_data (init_data),
        .lcd_rs   (init_rs),
        .lcd_rw   (init_rw),
        .lcd_e    (init_e)
    );

    // -----------------------------------------------------------------------
    // MUX: decide quem controla o LCD (init ou controlador principal)
    // -----------------------------------------------------------------------
    wire controller_mode = init_done;
    assign lcd_data = (controller_mode == 0) ? init_data : wr_data;
    assign lcd_rs   = (controller_mode == 0) ? init_rs   : wr_rs;
    assign lcd_rw   = (controller_mode == 0) ? init_rw   : wr_rw;
    assign lcd_e    = (controller_mode == 0) ? init_e    : wr_e;

    // -----------------------------------------------------------------------
    // Mensagem a ser exibida
    // -----------------------------------------------------------------------
	  
	 localparam OFF = 0, WAIT = 1, TRACO = 2, ON = 3;
	 
	 reg [1:0] estado_tela = OFF;
	 
	 //verificador do pulso dos botoes
	 
	 reg button_on_bef;
	 reg button_send_bef;
	 
	 always@(posedge clk or negedge rst)begin
		if (!rst)begin
			button_on_bef <= 1'b1;
			button_send_bef <=1'b1;
			
		end 
		else begin
			button_on_bef <= button_on;
			button_send_bef <= button_send;
		end
	 end
	 
	 wire soltou_on = (~button_on_bef && button_on);
	 wire soltou_send = (~button_send_bef && button_send);
	 
	 
	 //sequencial
	 
	 always @(posedge clk or negedge rst)begin
		if (!rst)
			estado_tela <= OFF;
		else begin
			case (estado_tela)
			
				OFF: begin
					if(soltou_on) estado_tela <= TRACO;
				end
					
				TRACO: begin
					if(soltou_send) 
						estado_tela <= ON;
					else if (soltou_on) 
						estado_tela <= OFF;
				end
					
				ON: begin
					if (soltou_on) estado_tela <= OFF;
					else if (soltou_send) estado_tela <= ON;
				end
			endcase
		end
	 end
	 
	 //combinacional
	 
	 localparam integer MSG_LEN = 32;
	 localparam LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4,  MUL = 5, CLEAR = 6, DISPLAY = 7; 

    reg [7:0] message [0:MSG_LEN-1];
	
    integer i;
	 
	 wire eh_negativo =  valor_destino[15];
	 wire [15:0]absoluto = eh_negativo ? (~valor_destino + 16'd1): valor_destino;
	 
	 reg [19:0] bcd;
    reg [3:0] d4, d3, d2, d1, d0;
    integer j;

    // Bloco combinacional para a conversão Binário -> BCD (Shift and Add 3)
    always @(*) begin
        bcd = 20'd0; // Inicializa com zero
        
        for (j = 15; j >= 0; j = j - 1) begin
            // Passo 1: Se um dígito (nibble) for >= 5, soma 3
            if (bcd[3:0]   >= 4'd5) bcd[3:0]   = bcd[3:0]   + 4'd3;
            if (bcd[7:4]   >= 4'd5) bcd[7:4]   = bcd[7:4]   + 4'd3;
            if (bcd[11:8]  >= 4'd5) bcd[11:8]  = bcd[11:8]  + 4'd3;
            if (bcd[15:12] >= 4'd5) bcd[15:12] = bcd[15:12] + 4'd3;
            if (bcd[19:16] >= 4'd5) bcd[19:16] = bcd[19:16] + 4'd3;
            
            // Passo 2: Shift para a esquerda, puxando o MSB atual do valor binário
            bcd = {bcd[18:0], absoluto[j]};
        end
        
        // Extrai os dígitos isolados para facilitar o uso
        d4 = bcd[19:16]; // Dezenas de milhar
        d3 = bcd[15:12]; // Unidades de milhar
        d2 = bcd[11:8];  // Centenas
        d1 = bcd[7:4];   // Dezenas
        d0 = bcd[3:0];   // Unidades
    end
	 
	 //imprimo de acordo com o estado da tela
	 always@(*) begin
		for (i =0; i < 32; i = i + 1)begin
			message[i] = " ";
		end
		 case(estado_tela)
			OFF: begin
			end
			TRACO: begin
				message[0]  = "-";
				message[1]  = "-";
				message[2]  = "-";
				message[3]  = "-";
				message[4]  = " ";
				message[5]  = " ";
				message[6]  = " ";
				message[7]  = " ";
				message[8]  = " ";
				message[9]  = " ";
				message[10] = "[";
				message[11] = "-";
				message[12] = "-";
				message[13] = "-";
				message[14] = "-";
				message[15] = "]";
				message[16] = " ";
				message[17] = " ";
				message[18] = " ";
				message[19] = " ";
				message[20] = " ";
				message[21] = " ";
				message[22] = " ";
				message[23] = " ";
				message[24] = " ";
				message[25] = " ";
				message[26] = "+";
				message[27] = "0";
				message[28] = "0";
				message[29] = "0";
				message[30] = "0";
				message[31] = "0";
				
			end
			ON: begin
			
				

				case(opcode)
					LOAD: begin
						message[0] = "L";
						message[1] = "O";
						message[2] = "A";
						message[3] = "D";

						
					end
					ADD: begin
						message[0] = "A";
						message[1] = "D";
						message[2] = "D";
					end
					
					ADDI: begin
						message[0] = "A";
						message[1] = "D";
						message[2] = "D";
						message[3] = "I";
						
					end
					
					
					SUB: begin
						message[0] = "S";
						message[1] = "U";
						message[2] = "B";
						
					end
					SUBI: begin
						message[0] = "S";
						message[1] = "U";
						message[2] = "B";
						message[3] = "I";
						
					
					end
					MUL: begin
						message[0] = "M";
						message[1] = "U";
						message[2] = "L";
						
					end
					CLEAR: begin
						message[0] = "C";
						message[1] = "L";
						message[2] = "R";
						
					end
					DISPLAY: begin
						message[0] = "D";
						message[1] = "S";
						message[2] = "P";
					
					end
					default: begin
						message[0] = "E";
						message[1] = "R";
						message[2] = "R";
						
					end
				endcase
				if(opcode != CLEAR) begin
					message[10] = "[";
					message[11] = destino[3] ? "1" : "0";
					message[12] = destino[2] ? "1" : "0";
					message[13] = destino[1] ? "1" : "0";
					message[14] = destino[0] ? "1" : "0"; // da pra fazer isso pq é só um bit, mas se nao fosse, soma o valor com o cod ASCII (PARTE DO 26-31)
					message[15] = "]";
					message[26] = eh_negativo ? "-" : "+";
					message[27] = d4 + 8'h30;
					message[28] = d3 + 8'h30;
					message[29] = d2 + 8'h30;
					message[30] = d1 + 8'h30;
					message[31] = d0 + 8'h30;
					
				end
					
			end
		 endcase
	 end
		 
		
    

    // -----------------------------------------------------------------------
    // Temporizações para escrita de caracteres (ajustar ao clock real)
    // -----------------------------------------------------------------------
    // Exemplo para 50 MHz:
    localparam [31:0] DELAY_WRITE = 32'd2000; // ~40 us
    localparam [31:0] DELAY_PULSE = 32'd50;   // ~1 us

    // -----------------------------------------------------------------------
    // Estados da FSM principal
    // -----------------------------------------------------------------------
    localparam [2:0]
        S_WAIT_INIT  = 3'd0,
        S_PREPARE    = 3'd1,
        S_PULSE_E    = 3'd2,
        S_WAIT       = 3'd3,
        S_DONE       = 3'd4,
		  S_LINHA2     = 3'd5,
		  S_CMD_PULSE  = 3'd6,
		  S_CMD_WAIT   = 3'd7;

    reg [2:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [4:0]  msg_index, next_msg_index; // até 31 caracteres
	 reg [31:0] count = 32'd0;

    // =======================================================================
    // 1) BLOCO SEQUENCIAL: registra estado, contador e índice da mensagem
    // =======================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state      <= S_WAIT_INIT;
            delay_cnt  <= 32'd0;
            msg_index  <= 5'd0;
        end else if(count == 0)begin
            state      <= next_state;
            delay_cnt  <= next_delay_cnt;
            msg_index  <= next_msg_index;
        end
    end

    // =======================================================================
    // 2) BLOCO COMBINACIONAL: cálculo do próximo estado/contador/índice
    // =======================================================================
    always @(*) begin
        // valores padrão
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_msg_index = msg_index;

        case (state)
            // ---------------------------------------------------------------
            // Espera a inicialização do LCD ser concluída
            // ---------------------------------------------------------------
            S_WAIT_INIT: begin
                if (init_done) begin
                    next_state     = S_PREPARE;
                    next_msg_index = 5'd0;
						  sinal = 0;
						  count = 32'd0;
                end else if(count > 0) count = count - 1;
            end

            // ---------------------------------------------------------------
            // Prepara para escrever o caractere atual
            // ---------------------------------------------------------------
            S_PREPARE: begin
                // apenas configura o próximo estado e o delay para o pulso
                next_state     = S_PULSE_E;
                next_delay_cnt = DELAY_PULSE;
            end

            // ---------------------------------------------------------------
            // Gera pulso de Enable
            // ---------------------------------------------------------------
            S_PULSE_E: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            // ---------------------------------------------------------------
            // Espera o tempo de escrita do caractere
            // ---------------------------------------------------------------
            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    if (msg_index == (5'd15)) begin
                        next_state = S_LINHA2;
                    end else if (msg_index == MSG_LEN -1) begin
								next_state = S_DONE;
						  end else begin
                        next_msg_index = msg_index + 1;
                        next_state     = S_PREPARE;
                    end 
					 end
            end
				S_LINHA2: begin //sinal pra jogar um puslo de enable com comando, ja vai direto pro pulso 0 -> 1
					next_state = S_CMD_PULSE;
					next_delay_cnt = DELAY_PULSE;
					next_msg_index = 5'd16;
            end
				S_CMD_PULSE : begin		//pulso =1, espera pro clk pegar, joga pro cmd wait que inverte o sinal pra 0, assim a lcd vai pegar o cmd (negedge)
					if (delay_cnt > 0)
						next_delay_cnt = delay_cnt - 1;
					else begin
						next_state = S_CMD_WAIT;
						next_delay_cnt = DELAY_WRITE;					
					end
				end
				S_CMD_WAIT : begin
					if (delay_cnt > 0)
						next_delay_cnt = delay_cnt - 1;
					else begin
						next_state = S_PREPARE;
					end
				end

            // ---------------------------------------------------------------
            // Mensagem completa
            // ---------------------------------------------------------------
            S_DONE: begin
                // Permanece nesse estado até reset
                next_state = S_DONE;
					 sinal = 1;
            end

            default: begin
                next_state     = S_WAIT_INIT;
                next_delay_cnt = 32'd0;
                next_msg_index = 5'd0;
            end
        endcase
    end

    // =======================================================================
    // 3) BLOCO COMBINACIONAL: geração das saídas
    //     - start_init
    //     - sinais de escrita (wr_rs, wr_rw, wr_e, wr_data)
// =======================================================================
    reg [7:0] wr_data;
    reg       wr_rs;
    reg       wr_rw;
    reg       wr_e;

    always @(*) begin
        // -------------------------------------------------------------------
        // 3.1) Controle de quem controla os sinais do LCD
        // -------------------------------------------------------------------

        // start_init: fica em '1' enquanto estamos esperando a inicialização.
        // O módulo lcd_init só usa o nível de start para sair do IDLE.
        start_init = (state == S_WAIT_INIT) ? 1'b1 : 1'b0;

        // -------------------------------------------------------------------
        // 3.2) Sinais de escrita do controlador principal
        // -------------------------------------------------------------------
        // Default
        wr_data = 8'h00;
        wr_rs   = 1'b0;
        wr_rw   = 1'b0;
        wr_e    = 1'b0;

        case (state)
            // Durante a escrita da mensagem, usamos os caracteres da array
            S_PREPARE: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1; // dado (caractere)
                wr_rw   = 1'b0; // escrita
                wr_e    = 1'b0;
            end

            S_PULSE_E: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1;
                wr_rw   = 1'b0;
                wr_e    = 1'b1; // pulso de enable
            end

            S_WAIT: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_DONE: begin
                // mensagem já escrita — manter sinais em estado "neutro"
                wr_rs = 1'b0;
                wr_rw = 1'b0;
                wr_e  = 1'b0;
                // wr_data pode permanecer com o último valor ou 0
            end
				S_LINHA2: begin
					wr_data = 8'hC0;
					wr_rs = 1'b0;
					wr_rw = 1'b0;
					wr_e = 1'b0;
				end
				S_CMD_PULSE: begin
					wr_data = 8'hC0; 
					wr_rs = 1'b0; 
					wr_rw = 1'b0; 
					wr_e = 1'b1;
				end
				S_CMD_WAIT: begin
					wr_data = 8'hC0; //comando pra jogar pra segunda linha
					wr_rs = 1'b0; 
					wr_rw = 1'b0; 
					wr_e = 1'b0;
				end

            default: begin
                // outros estados: controlador principal não mexe no LCD
                wr_rs = 1'b0;
                wr_rw = 1'b0;
                wr_e  = 1'b0;
                wr_data = 8'h00;
            end
        endcase
    end
endmodule