module lcd_controller_top (
    input  wire        clk,
    input  wire        rst,          // reset ativo em '0'
    input  wire [1:0]  screen_mode,  // 0: OFF, 1: TRACO, 2: ON
    input  wire [2:0]  opcode,
    input  wire [3:0]  destino,
    input  wire [15:0] valor_destino,

    // Saídas para o LCD
    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e,
    output wire        sinal
);

    // -----------------------------------------------------------------------
    // Instância do módulo de inicialização
    // -----------------------------------------------------------------------
    wire [7:0] init_data;
    wire       init_rs;
    wire       init_rw;
    wire       init_e;
    wire       init_done;

    reg        start_init;

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
    reg [7:0] wr_data;
    reg       wr_rs;
    reg       wr_rw;
    reg       wr_e;

    wire controller_mode = init_done;
    assign lcd_data = (controller_mode == 1'b0) ? init_data : wr_data;
    assign lcd_rs   = (controller_mode == 1'b0) ? init_rs   : wr_rs;
    assign lcd_rw   = (controller_mode == 1'b0) ? init_rw   : wr_rw;
    assign lcd_e    = (controller_mode == 1'b0) ? init_e    : wr_e;

    // -----------------------------------------------------------------------
    // Formatação da mensagem de 32 caracteres (2 linhas x 16 colunas)
    // -----------------------------------------------------------------------
    localparam [1:0] OFF = 2'd0, TRACO = 2'd1, ON = 2'd2;
    localparam integer MSG_LEN = 32;
    localparam [2:0]
        LOAD    = 3'd0,
        ADD     = 3'd1,
        ADDI    = 3'd2,
        SUB     = 3'd3,
        SUBI    = 3'd4,
        MUL     = 3'd5,
        CLEAR   = 3'd6,
        DISPLAY = 3'd7;

    reg [7:0] message [0:MSG_LEN-1];
    integer i;

    wire        eh_negativo = valor_destino[15];
    wire [15:0] absoluto    = eh_negativo ? (~valor_destino + 16'd1) : valor_destino;

    reg [19:0] bcd;
    reg [3:0]  d4, d3, d2, d1, d0;
    integer    j;

    // Conversão Binário (16 bits) -> BCD (5 dígitos) via Shift-and-Add-3
    always @(*) begin
        bcd = 20'd0;
        for (j = 15; j >= 0; j = j - 1) begin
            if (bcd[3:0]   >= 4'd5) bcd[3:0]   = bcd[3:0]   + 4'd3;
            if (bcd[7:4]   >= 4'd5) bcd[7:4]   = bcd[7:4]   + 4'd3;
            if (bcd[11:8]  >= 4'd5) bcd[11:8]  = bcd[11:8]  + 4'd3;
            if (bcd[15:12] >= 4'd5) bcd[15:12] = bcd[15:12] + 4'd3;
            if (bcd[19:16] >= 4'd5) bcd[19:16] = bcd[19:16] + 4'd3;
            bcd = {bcd[18:0], absoluto[j]};
        end
        d4 = bcd[19:16];
        d3 = bcd[15:12];
        d2 = bcd[11:8];
        d1 = bcd[7:4];
        d0 = bcd[3:0];
    end

    // Montagem da tela conforme o estado atual
    always @(*) begin
        for (i = 0; i < 32; i = i + 1) begin
            message[i] = " ";
        end

        case (screen_mode)
            OFF: begin
                // Mantém tudo com espaços (" ") -> display limpo
            end

            TRACO: begin
                message[0]  = "-";
                message[1]  = "-";
                message[2]  = "-";
                message[3]  = "-";
                message[10] = "[";
                message[11] = "-";
                message[12] = "-";
                message[13] = "-";
                message[14] = "-";
                message[15] = "]";
                message[26] = "+";
                message[27] = "0";
                message[28] = "0";
                message[29] = "0";
                message[30] = "0";
                message[31] = "0";
            end

            ON: begin
                case (opcode)
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
                        message[1] = "P";
                        message[2] = "L";
                    end
                    default: begin
                        message[0] = "E";
                        message[1] = "R";
                        message[2] = "R";
                    end
                endcase

                // CLEAR exibe somente o nome da operação
                if (opcode != CLEAR) begin
                    message[10] = "[";
                    message[11] = destino[3] ? "1" : "0";
                    message[12] = destino[2] ? "1" : "0";
                    message[13] = destino[1] ? "1" : "0";
                    message[14] = destino[0] ? "1" : "0";
                    message[15] = "]";
                    message[26] = eh_negativo ? "-" : "+";
                    message[27] = d4 + 8'h30;
                    message[28] = d3 + 8'h30;
                    message[29] = d2 + 8'h30;
                    message[30] = d1 + 8'h30;
                    message[31] = d0 + 8'h30;
                end
            end

            default: begin
            end
        endcase
    end

    // -----------------------------------------------------------------------
    // Temporizações para escrita de caracteres (clock de 50 MHz)
    // -----------------------------------------------------------------------
    localparam [31:0] DELAY_WRITE = 32'd2500; // ~50 us
    localparam [31:0] DELAY_PULSE = 32'd50;   // ~1 us

    // -----------------------------------------------------------------------
    // Estados da FSM principal do LCD
    // -----------------------------------------------------------------------
    localparam [3:0]
        S_WAIT_INIT  = 4'd0,
        S_PREPARE    = 4'd1,
        S_PULSE_E    = 4'd2,
        S_WAIT       = 4'd3,
        S_DONE       = 4'd4,
        S_LINHA2     = 4'd5,
        S_CMD_PULSE  = 4'd6,
        S_CMD_WAIT   = 4'd7,
        S_HOME       = 4'd8,
        S_HOME_PULSE = 4'd9,
        S_HOME_WAIT  = 4'd10;

    reg [3:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [4:0]  msg_index, next_msg_index;

    assign sinal = (state == S_DONE);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state     <= S_WAIT_INIT;
            delay_cnt <= 32'd0;
            msg_index <= 5'd0;
        end else begin
            state     <= next_state;
            delay_cnt <= next_delay_cnt;
            msg_index <= next_msg_index;
        end
    end

    always @(*) begin
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_msg_index = msg_index;

        case (state)
            S_WAIT_INIT: begin
                if (init_done) begin
                    next_state     = S_PREPARE;
                    next_msg_index = 5'd0;
                end
            end

            S_PREPARE: begin
                next_state     = S_PULSE_E;
                next_delay_cnt = DELAY_PULSE;
            end

            S_PULSE_E: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    if (msg_index == 5'd15) begin
                        next_state = S_LINHA2;
                    end else if (msg_index == MSG_LEN - 1) begin
                        next_state = S_DONE;
                    end else begin
                        next_msg_index = msg_index + 1;
                        next_state     = S_PREPARE;
                    end
                end
            end

            S_LINHA2: begin
                next_state     = S_CMD_PULSE;
                next_delay_cnt = DELAY_PULSE;
                next_msg_index = 5'd16;
            end

            S_CMD_PULSE: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_CMD_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            S_CMD_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state = S_PREPARE;
                end
            end

            S_DONE: begin
                next_state = S_HOME;
            end

            S_HOME: begin
                next_state     = S_HOME_PULSE;
                next_delay_cnt = DELAY_PULSE;
            end

            S_HOME_PULSE: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_HOME_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            S_HOME_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_PREPARE;
                    next_msg_index = 5'd0;
                end
            end

            default: begin
                next_state     = S_WAIT_INIT;
                next_delay_cnt = 32'd0;
                next_msg_index = 5'd0;
            end
        endcase
    end

    always @(*) begin
        start_init = (state == S_WAIT_INIT) ? 1'b1 : 1'b0;

        wr_data = 8'h00;
        wr_rs   = 1'b0;
        wr_rw   = 1'b0;
        wr_e    = 1'b0;

        case (state)
            S_PREPARE: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_PULSE_E: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1;
                wr_rw   = 1'b0;
                wr_e    = 1'b1;
            end

            S_WAIT: begin
                wr_data = message[msg_index];
                wr_rs   = 1'b1;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_LINHA2: begin
                wr_data = 8'hC0;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_CMD_PULSE: begin
                wr_data = 8'hC0;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b1;
            end

            S_CMD_WAIT: begin
                wr_data = 8'hC0;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_HOME: begin
                wr_data = 8'h80;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            S_HOME_PULSE: begin
                wr_data = 8'h80;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b1;
            end

            S_HOME_WAIT: begin
                wr_data = 8'h80;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end

            default: begin
                wr_data = 8'h00;
                wr_rs   = 1'b0;
                wr_rw   = 1'b0;
                wr_e    = 1'b0;
            end
        endcase
    end

endmodule