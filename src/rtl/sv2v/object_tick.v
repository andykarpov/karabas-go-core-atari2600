module object_tick (
	clk,
	reset,
	motck,
	ec,
	tick
);
	input clk;
	input reset;
	input motck;
	input ec;
	output wire tick;
	reg old_motck;
	reg old_ec;
	wire edge_miss = (old_motck && ~motck) && (~old_ec && ec);
	assign tick = (motck || ec) && ~edge_miss;
	always @(posedge clk) begin
		old_motck <= motck;
		old_ec <= ec;
		if (reset) begin
			old_motck <= 0;
			old_ec <= 0;
		end
	end
endmodule
