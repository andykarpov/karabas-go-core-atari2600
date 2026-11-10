module match_bytes (
	clk,
	reset,
	enable,
	stream,
	hasMatch
);
	input clk;
	input reset;
	input enable;
	input [63:0] stream;
	output reg hasMatch;
	parameter [7:0] num_bytes = 8'd1;
	parameter [(num_bytes * 8) - 1:0] pattern = 0;
	parameter [7:0] needmatches = 8'b00000001;
	reg [7:0] curMatch;
	always @(posedge clk) begin
		if (reset) begin
			curMatch <= 0;
			hasMatch <= 0;
		end
		if (enable) begin
			if (stream[(num_bytes * 8) - 1:0] == pattern) begin
				if (reset || !hasMatch) begin
					if (reset || (curMatch < needmatches))
						curMatch <= (reset ? 8'd0 : curMatch) + 8'd1;
					if ((reset ? 8'd0 : curMatch) >= (needmatches - 8'd1))
						hasMatch <= 1'b1;
				end
			end
		end
	end
endmodule
