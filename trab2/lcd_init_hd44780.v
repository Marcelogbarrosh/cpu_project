module lcd_init_hd44780 (
    input  wire       clk,
    input  wire       rst,    // reset assíncrono, ativo em '0'
    input  wire       start,
    output reg        done,

    output reg  [7:0] lcd_data,
    output reg        lcd_rs,
    output reg        lcd_rw,
    output reg        lcd_e
);

    localparam [7:0] CMD_FUNCTION_SET  = 8'h38; // 8 bits, 2 linhas, 5x8
    localparam [7:0] CMD_DISPLAY_ON    = 8'h0C; // display ON, cursor OFF, blink OFF
    localparam [7:0] CMD_DISPLAY_CLEAR = 8'h01; // clear display
    localparam [7:0] CMD_ENTRY_MODE    = 8'h06; // entry mode: incrementa cursor, sem shift

    localparam integer NUM_CMDS = 4;

    localparam [31:0] DELAY_POWER_ON  = 32'd750_000; // ~15 ms @ 50 MHz
    localparam [31:0] DELAY_STD_CMD   = 32'd2_500;   // ~50 us
    localparam [31:0] DELAY_CLEAR_CMD = 32'd100_000; // ~2 ms
    localparam [31:0] DELAY_PULSE_E   = 32'd50;      // ~1 us

    localparam [2:0]
        S_IDLE       = 3'd0,
        S_POWER_WAIT = 3'd1,
        S_SETUP      = 3'd2,
        S_PULSE      = 3'd3,
        S_WAIT       = 3'd4,
        S_DONE       = 3'd5;

    reg [2:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [2:0]  cmd_idx, next_cmd_idx;
    reg [7:0]  current_cmd;

    reg [7:0]  cmd_rom       [0:NUM_CMDS-1];
    reg [31:0] cmd_delay_rom [0:NUM_CMDS-1];

    initial begin
        cmd_rom[0] = CMD_FUNCTION_SET;
        cmd_rom[1] = CMD_DISPLAY_ON;
        cmd_rom[2] = CMD_DISPLAY_CLEAR;
        cmd_rom[3] = CMD_ENTRY_MODE;

        cmd_delay_rom[0] = DELAY_STD_CMD;
        cmd_delay_rom[1] = DELAY_STD_CMD;
        cmd_delay_rom[2] = DELAY_CLEAR_CMD;
        cmd_delay_rom[3] = DELAY_STD_CMD;
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state     <= S_IDLE;
            delay_cnt <= 32'd0;
            cmd_idx   <= 3'd0;
        end else begin
            state     <= next_state;
            delay_cnt <= next_delay_cnt;
            cmd_idx   <= next_cmd_idx;
        end
    end

    always @(*) begin
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_cmd_idx   = cmd_idx;

        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state     = S_POWER_WAIT;
                    next_delay_cnt = DELAY_POWER_ON;
                    next_cmd_idx   = 3'd0;
                end
            end

            S_POWER_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state = S_SETUP;
                end
            end

            S_SETUP: begin
                if (cmd_idx < NUM_CMDS) begin
                    next_state     = S_PULSE;
                    next_delay_cnt = DELAY_PULSE_E;
                end else begin
                    next_state = S_DONE;
                end
            end

            S_PULSE: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = cmd_delay_rom[cmd_idx];
                end
            end

            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_cmd_idx = cmd_idx + 1;
                    next_state   = S_SETUP;
                end
            end

            S_DONE: begin
                next_state = S_DONE;
            end

            default: begin
                next_state     = S_IDLE;
                next_delay_cnt = 32'd0;
                next_cmd_idx   = 3'd0;
            end
        endcase
    end

    always @(*) begin
        lcd_data = 8'h00;
        lcd_rs   = 1'b0;
        lcd_rw   = 1'b0;
        lcd_e    = 1'b0;
        done     = 1'b0;

        if (cmd_idx < NUM_CMDS)
            current_cmd = cmd_rom[cmd_idx];
        else
            current_cmd = 8'h00;

        case (state)
            S_SETUP: begin
                lcd_data = current_cmd;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end

            S_PULSE: begin
                lcd_data = current_cmd;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b1;
            end

            S_WAIT: begin
                lcd_data = current_cmd;
                lcd_rs   = 1'b0;
                lcd_rw   = 1'b0;
                lcd_e    = 1'b0;
            end

            S_DONE: begin
                done   = 1'b1;
                lcd_e  = 1'b0;
                lcd_rw = 1'b0;
                lcd_rs = 1'b0;
            end

            default: begin
            end
        endcase
    end

endmodule