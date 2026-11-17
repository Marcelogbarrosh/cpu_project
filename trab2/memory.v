module memory (
    input [3:0] state,
    input [3:0] addr,
    input [15:0] data,
    input we,
    input clk,
    input [2:0] op,
    output reg [15:0] q,
    output finish
);

    reg [15:0] ram [15:0];
    
    always @(posedge clk) begin
        case(op)
            0: begin // LOAD
                if(we) ram[addr] <= data;
                q <= ram[addr];
            end
            6: begin // CLEAR
                ram[0] <= 0; ram[1] <= 0; ram[2] <= 0; ram[3] <= 0;
                ram[4] <= 0; ram[5] <= 0; ram[6] <= 0; ram[7] <= 0;
                ram[8] <= 0; ram[9] <= 0; ram[10] <= 0; ram[11] <= 0;
                ram[12] <= 0; ram[13] <= 0; ram[14] <= 0; ram[15] <= 0;
                q <= 0;
            end
            default: begin 
                // ADD, ADDI, SUB, SUBI, MUL, DISPLAY
                if(we) ram[addr] <= data;
                q <= ram[addr];
            end
        endcase
		  
    end
	 assign finish = clk;
	 
endmodule