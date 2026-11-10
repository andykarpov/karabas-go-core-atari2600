module inverter_reg (
	clk,
	reset,
	set,
	in,
	out
);
	input clk;
	input reset;
	input set;
	input in;
	output wire out;
	reg inv_latch = 0;
	assign out = inv_latch;
	always @(posedge clk) begin
		if (set)
			inv_latch <= in;
		if (reset)
			inv_latch <= 0;
	end
endmodule
