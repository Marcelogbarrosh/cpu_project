module ula (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  op,
    input  wire [15:0] n1,
    input  wire [15:0] n2,
    output reg  [15:0] result,
    output reg         done
);

    localparam [2:0]
        LOAD    = 3'd0,
        ADD     = 3'd1,
        ADDI    = 3'd2,
        SUB     = 3'd3,
        SUBI    = 3'd4,
        MUL     = 3'd5,
        CLEAR   = 3'd6,
        DISPLAY = 3'd7;

    localparam [1:0]
        S_IDLE = 2'd0,
        S_CALC = 2'd1,
        S_DONE = 2'd2;

    reg [1:0] state;
    wire signed [31:0] mult_full = $signed(n1) * $signed(n2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= S_IDLE;
            result <= 16'd0;
            done   <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_CALC;
                    end
                end

                S_CALC: begin
                    case (op)
                        LOAD:    result <= n2;
                        ADD:     result <= n1 + n2;
                        ADDI:    result <= n1 + n2;
                        SUB:     result <= n1 - n2;
                        SUBI:    result <= n1 - n2;
                        MUL:     result <= mult_full[15:0];
                        CLEAR:   result <= 16'd0;
                        DISPLAY: result <= n1;
                        default: result <= 16'd0;
                    endcase
                    done  <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    done  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule