module f_cell (
	clk,
	reset,
	tick,
	r_n,
	s_n,
	q_n,
	q
);
	input wire clk;
	input wire reset;
	input wire tick;
	input wire r_n;
	input wire s_n;
	output wire q_n;
	output wire q;
	reg master;
	reg slave;
	assign q = (reset ? 1'd0 : (tick ? ~master : slave));
	assign q_n = ~q;
	always @(posedge clk) begin
		if (tick)
			slave <= ~master;
		else
			master <= (~s_n ? 1'd0 : (~r_n ? 1'd1 : master));
		if (reset) begin
			master <= 1'd0;
			slave <= 1'd0;
		end
	end
endmodule
