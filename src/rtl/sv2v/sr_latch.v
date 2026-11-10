module sr_latch (
	clk,
	reset,
	r,
	s,
	q,
	q_n
);
	input clk;
	input reset;
	input r;
	input s;
	output wire q;
	output wire q_n;
	reg sr_val;
	wire i_val = (r ? 1'd0 : (s ? 1'd1 : sr_val));
	wire sr_val_n;
	assign q_n = (r & s ? 1'd0 : ~q);
	assign q = i_val;
	always @(posedge clk) begin
		sr_val <= i_val;
		if (reset)
			sr_val <= 1'd0;
	end
endmodule
