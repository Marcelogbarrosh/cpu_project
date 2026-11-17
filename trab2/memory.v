module memory (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        we,
    input  wire        clear,
    input  wire [3:0]  addr_w,   // Registrador de destino (D1)
    input  wire [3:0]  addr_a,   // Registrador fonte 1 (Src1)
    input  wire [3:0]  addr_b,   // Registrador fonte 2 (Src2)
    input  wire [15:0] data_in,  // Dado a ser escrito em D1
    output reg  [15:0] q_a,      // Valor lido de Src1
    output reg  [15:0] q_b,      // Valor lido de Src2
    output reg  [15:0] q_dest,   // Valor atualizado de D1 (para exibição)
    output reg         finish
);

    localparam [1:0]
        S_IDLE = 2'd0,
        S_DONE = 2'd1;

    reg [1:0]  state;
    reg [15:0] ram [0:15];
    integer    i;

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            ram[i] = 16'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= S_IDLE;
            q_a    <= 16'd0;
            q_b    <= 16'd0;
            q_dest <= 16'd0;
            finish <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                ram[i] <= 16'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    finish <= 1'b0;
                    if (start) begin
                        if (clear) begin
                            for (i = 0; i < 16; i = i + 1) begin
                                ram[i] <= 16'd0;
                            end
                            q_a    <= 16'd0;
                            q_b    <= 16'd0;
                            q_dest <= 16'd0;
                        end else begin
                            // Leitura dos operandos fonte
                            q_a <= ram[addr_a];
                            q_b <= ram[addr_b];

                            // Escrita no destino (se habilitada) e saída para o LCD
                            if (we) begin
                                ram[addr_w] <= data_in;
                                q_dest      <= data_in;
                            end else begin
                                q_dest      <= ram[addr_w];
                            end
                        end
                        finish <= 1'b1;
                        state  <= S_DONE;
                    end
                end

                S_DONE: begin
                    finish <= 1'b0;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule