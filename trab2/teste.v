module teste(
	input	wire			clk,
	input wire			button_on,
	input wire			button_send,
	
	output wire  [7:0] lcd_data,
   output wire        lcd_rs,
   output wire        lcd_rw,
   output wire        lcd_e,
	output wire			  sinal
);

	wire apertado = (button_on && button_send);

	lcd_controller_top controller (
		.clk						(clk),
		.rst						(apertado),
		.opcode					(1'b0),
		.destino					(1'b0),
		.valor_destino			(1'b0),
		.button_on				(button_on),
		.button_send			(button_send),
    // Saídas para o LCD
		.lcd_data				(lcd_data),
		.lcd_rs					(lcd_rs),
		.lcd_rw					(lcd_rw),
		.lcd_e					(lcd_e),
		.sinal					(sinal)
	);

endmodule