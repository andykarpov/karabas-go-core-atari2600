module d_cell (
	clk,
	reset,
	phi1,
	phi2,
	in,
	out
);
	input wire clk;
	input wire reset;
	input wire phi1;
	input wire phi2;
	input wire in;
	output wire out;
	reg out_next;
	reg out_latch;
	assign out = (reset ? 1'd0 : (phi2 ? out_next : out_latch));
	always @(posedge clk) begin
		if (phi1)
			out_next <= in;
		if (phi2)
			out_latch <= out_next;
		if (reset) begin
			out_latch <= 0;
			out_next <= 0;
		end
	end
endmodule
