module module_mini_cpu (
    input [17:0]  data,
    input         button_on,
    input         button_send,
    input         clk,

    // Saídas para o LCD
    output  [7:0] lcd_data,
    output        lcd_rs,
    output        lcd_rw,
    output        lcd_e
);

    parameter OFF = 8, DECODE = 9, EXECUTE = 10, LCD_FETCH = 11, WAIT = 12, WAIT_LCD = 16;
    parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7;
    
    reg [15:0]  ram [15:0];
    wire [15:0] ram_reg;    
    reg [3:0]   state = WAIT;
    
    reg [2:0]   opcode = 3'd0;
    reg [3:0]   reg1 = 0;
    reg [3:0]   reg2 = 0;
    reg [3:0]   reg3 = 0;
    reg [7:0]   imm = 0;
    reg [7:0]   n2 = 0;
    reg         we = 0;
    
    wire [15:0] to_storage; 
    wire        finish;     
    reg         start = 0;  
    wire        done;       
    
    // Detectores de borda (Debounce limpo para não pular estados)
    reg button_on_bef = 1'b1;
    reg button_send_bef = 1'b1;
    always @(posedge clk) begin
        button_on_bef <= button_on;
        button_send_bef <= button_send;
    end
    wire soltou_on = (!button_on_bef && button_on);
    wire soltou_send = (!button_send_bef && button_send);
    
    reg system_on = 1'b0;
    integer i;

    // =========================================================
    // MÁQUINA DE ESTADOS DA CPU GLOBAL
    // =========================================================
    always@(posedge clk) begin
        if (soltou_on) begin
            if (system_on) begin
                // DESLIGA O SISTEMA E ZERA TUDO 
                system_on <= 1'b0;
                state <= WAIT;
                start <= 0;
                opcode <= 3'd0;
                reg1 <= 0; reg2 <= 0; reg3 <= 0;
                imm <= 0; n2 <= 0; we <= 0;
                for(i=0; i<16; i=i+1) ram[i] <= 16'd0;
            end else begin
                // LIGA O SISTEMA
                system_on <= 1'b1;
                state <= WAIT;
            end
        end 
        else if (system_on) begin
            case(state)
                WAIT: begin     
                    if(soltou_send) begin 
                        state <= DECODE;
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
                    if(finish) begin
                        start <= 0;
                        state <= LCD_FETCH;
                    end
                    else begin
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
                    end else begin
                        ram[reg1] <= ram_reg;
                        start <= 0;
                        state <= WAIT_LCD; 
                    end
                end
                
                WAIT_LCD: begin
                    if(done == 1'b1) begin 
                        state <= WAIT;
                    end
                end
                
                default: state <= WAIT;
            endcase
        end
    end
    
    ula alu (
        .state      (state),
        .n1         (ram[reg2]),
        .n2         (n2),
        .op         (opcode),
        .result     (to_storage)
    );
    
    memory mem (
        .state      (state),
        .addr       (reg1),
        .data       (to_storage),
        .we         (we),
        .clk        (start),
        .op         (opcode),
        .q          (ram_reg),
        .finish     (finish)
    );
    
    lcd_controller_top controller (
        .clk                    (clk),
        .rst                    (1'b1),
        .opcode                 (opcode),
        .destino                (reg1),
        .valor_destino          (ram_reg),
        .button_on              (button_on),
        .button_send            (button_send),
        .lcd_data               (lcd_data),
        .lcd_rs                 (lcd_rs),
        .lcd_rw                 (lcd_rw),
        .lcd_e                  (lcd_e),
        .sinal                  (done)
    );

endmodule