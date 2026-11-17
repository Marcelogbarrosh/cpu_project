module module_mini_cpu (
    input  wire [17:0] data,
    input  wire        button_on,
    input  wire        button_send,
    input  wire        clk,

    // Saídas para o LCD
    output wire [7:0]  lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    // -----------------------------------------------------------------------
    // Reset interno de Power-On (ativo em '0' nos primeiros ciclos)
    // -----------------------------------------------------------------------
    reg [3:0] por_cnt = 4'd0;
    wire rst_n = (por_cnt == 4'd15);

    always @(posedge clk) begin
        if (!rst_n)
            por_cnt <= por_cnt + 4'd1;
    end

    // -----------------------------------------------------------------------
    // Sincronização e detecção de borda de soltura dos botões (KEY ativo em '0')
    // -----------------------------------------------------------------------
    reg [2:0] on_sync;
    reg [2:0] send_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            on_sync   <= 3'b111;
            send_sync <= 3'b111;
        end else begin
            on_sync   <= {on_sync[1:0], button_on};
            send_sync <= {send_sync[1:0], button_send};
        end
    end

    // Pulso de 1 ciclo quando o botão é solto (transição 0 -> 1)
    wire on_released   = (on_sync[2] == 1'b0)   && (on_sync[1] == 1'b1);
    wire send_released = (send_sync[2] == 1'b0) && (send_sync[1] == 1'b1);

    // -----------------------------------------------------------------------
    // Opcodes e Estados da CPU
    // -----------------------------------------------------------------------
    localparam [2:0]
        LOAD    = 3'd0,
        ADD     = 3'd1,
        ADDI    = 3'd2,
        SUB     = 3'd3,
        SUBI    = 3'd4,
        MUL     = 3'd5,
        CLEAR   = 3'd6,
        DISPLAY = 3'd7;

    localparam [2:0]
        S_OFF        = 3'd0,
        S_IDLE       = 3'd1,
        S_DECODE     = 3'd2,
        S_FETCH      = 3'd3,
        S_EXECUTE    = 3'd4,
        S_STORE      = 3'd5,
        S_UPDATE_LCD = 3'd6;

    localparam [1:0]
        LCD_OFF   = 2'd0,
        LCD_TRACO = 2'd1,
        LCD_ON    = 2'd2;

    reg [2:0]  state;
    reg [17:0] instr_reg;

    // Campos decodificados
    reg [2:0]  opcode;
    reg [3:0]  reg1;       // Destino (D1) ou registrador do DISPLAY
    reg [3:0]  reg2;       // Fonte 1 (Src1)
    reg [3:0]  reg3;       // Fonte 2 (Src2)
    reg [15:0] imm_signed; // Imediato convertido de Sinal+Módulo para 16 bits
    reg [15:0] alu_n2;

    // Conversão Sinal (bit 6) + Módulo (bits 5:0) -> Complemento de 2 (16 bits)
    wire [15:0] imm_mag  = {10'd0, instr_reg[5:0]};
    wire [15:0] imm_conv = instr_reg[6] ? (~imm_mag + 16'd1) : imm_mag;

    // Sinais de controle da Memória
    reg         mem_start;
    reg         mem_we;
    reg         mem_clear;
    wire [15:0] mem_qa;
    wire [15:0] mem_qb;
    wire [15:0] mem_qdest;
    wire        mem_finish;

    // Sinais de controle da ULA
    reg         alu_start;
    wire [15:0] alu_result;
    wire        alu_done;

    // Sinais enviados ao controlador do LCD
    reg  [1:0]  lcd_mode;
    reg  [2:0]  lcd_opcode;
    reg  [3:0]  lcd_dest;
    reg  [15:0] lcd_val;
    wire        lcd_done;

    // -----------------------------------------------------------------------
    // Máquina de Estados Principal (Control Unit)
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_OFF;
            instr_reg  <= 18'd0;
            opcode     <= 3'd0;
            reg1       <= 4'd0;
            reg2       <= 4'd0;
            reg3       <= 4'd0;
            imm_signed <= 16'd0;
            alu_n2     <= 16'd0;
            mem_start  <= 1'b0;
            mem_we     <= 1'b0;
            mem_clear  <= 1'b1; // Garante RAM zerada ao iniciar
            alu_start  <= 1'b0;
            lcd_mode   <= LCD_OFF;
            lcd_opcode <= 3'd0;
            lcd_dest   <= 4'd0;
            lcd_val    <= 16'd0;
        end else begin
            // Padrão: pulsos de controle duram 1 ciclo
            mem_start <= 1'b0;
            mem_clear <= 1'b0;
            alu_start <= 1'b0;

            // Se o botão LIGAR for pressionado e solto com o sistema ligado,
            // desliga o display e zera todos os registradores imediatamente.
            if (state != S_OFF && on_released) begin
                state     <= S_OFF;
                lcd_mode  <= LCD_OFF;
                mem_clear <= 1'b1;
                mem_start <= 1'b1;
                mem_we    <= 1'b0;
            end else begin
                case (state)
                    // -------------------------------------------------------
                    // Sistema desligado: ignora instruções e mantém tela apagada
                    // -------------------------------------------------------
                    S_OFF: begin
                        lcd_mode <= LCD_OFF;
                        if (on_released) begin
                            mem_clear <= 1'b1;
                            mem_start <= 1'b1;
                            mem_we    <= 1'b0;
                            lcd_mode  <= LCD_TRACO;
                            state     <= S_IDLE;
                        end
                    end

                    // -------------------------------------------------------
                    // Sistema ligado e aguardando o botão ENVIAR
                    // -------------------------------------------------------
                    S_IDLE: begin
                        if (send_released) begin
                            instr_reg <= data;
                            state     <= S_DECODE;
                        end
                    end

                    // -------------------------------------------------------
                    // Decodifica os campos da instrução de 18 bits
                    // -------------------------------------------------------
                    S_DECODE: begin
                        opcode     <= instr_reg[17:15];
                        reg1       <= instr_reg[14:11];
                        reg2       <= instr_reg[10:7];
                        reg3       <= instr_reg[6:3];
                        imm_signed <= imm_conv;

                        // Dispara leitura dos registradores na memória (Fetch)
                        mem_we     <= 1'b0;
                        mem_clear  <= 1'b0;
                        mem_start  <= 1'b1;
                        state      <= S_FETCH;
                    end

                    // -------------------------------------------------------
                    // Aguarda leitura dos operandos na RAM
                    // -------------------------------------------------------
                    S_FETCH: begin
                        if (mem_finish) begin
                            case (instr_reg[17:15])
                                ADD, SUB:                  alu_n2 <= mem_qb;
                                LOAD, ADDI, SUBI, MUL:     alu_n2 <= imm_signed;
                                default:                   alu_n2 <= 16'd0;
                            endcase
                            alu_start <= 1'b1;
                            state     <= S_EXECUTE;
                        end
                    end

                    // -------------------------------------------------------
                    // Aguarda cálculo da ULA
                    // -------------------------------------------------------
                    S_EXECUTE: begin
                        if (alu_done) begin
                            case (opcode)
                                CLEAR: begin
                                    mem_clear <= 1'b1;
                                    mem_we    <= 1'b0;
                                    mem_start <= 1'b1;
                                end
                                DISPLAY: begin
                                    mem_clear <= 1'b0;
                                    mem_we    <= 1'b0;
                                    mem_start <= 1'b1;
                                end
                                default: begin // LOAD, ADD, ADDI, SUB, SUBI, MUL
                                    mem_clear <= 1'b0;
                                    mem_we    <= 1'b1;
                                    mem_start <= 1'b1;
                                end
                            endcase
                            state <= S_STORE;
                        end
                    end

                    // -------------------------------------------------------
                    // Aguarda escrita/atualização na RAM
                    // -------------------------------------------------------
                    S_STORE: begin
                        if (mem_finish) begin
                            state <= S_UPDATE_LCD;
                        end
                    end

                    // -------------------------------------------------------
                    // Atualiza dados exibidos no display LCD
                    // -------------------------------------------------------
                    S_UPDATE_LCD: begin
                        lcd_opcode <= opcode;
                        lcd_dest   <= reg1;
                        lcd_val    <= mem_qdest;
                        lcd_mode   <= LCD_ON;
                        state      <= S_IDLE;
                    end

                    default: state <= S_OFF;
                endcase
            end
        end
    end

    // -----------------------------------------------------------------------
    // Instância da ULA (module_alu)
    // -----------------------------------------------------------------------
    ula alu (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (alu_start),
        .op     (opcode),
        .n1     (mem_qa),
        .n2     (alu_n2),
        .result (alu_result),
        .done   (alu_done)
    );

    // -----------------------------------------------------------------------
    // Instância da Memória RAM 16x16 (memory)
    // -----------------------------------------------------------------------
    memory mem (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (mem_start),
        .we      (mem_we),
        .clear   (mem_clear),
        .addr_w  (reg1),
        .addr_a  (reg2),
        .addr_b  (reg3),
        .data_in (alu_result),
        .q_a     (mem_qa),
        .q_b     (mem_qb),
        .q_dest  (mem_qdest),
        .finish  (mem_finish)
    );

    // -----------------------------------------------------------------------
    // Instância do Controlador do LCD (lcd_controller_top)
    // -----------------------------------------------------------------------
    lcd_controller_top controller (
        .clk           (clk),
        .rst           (rst_n),
        .screen_mode   (lcd_mode),
        .opcode        (lcd_opcode),
        .destino       (lcd_dest),
        .valor_destino (lcd_val),
        .lcd_data      (lcd_data),
        .lcd_rs        (lcd_rs),
        .lcd_rw        (lcd_rw),
        .lcd_e         (lcd_e),
        .sinal         (lcd_done)
    );

endmodule