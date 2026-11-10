module lfsr_6 (
	clk,
	phi1,
	phi2,
	reset,
	sys_reset,
	lfsr
);
	input clk;
	input phi1;
	input phi2;
	input reset;
	input sys_reset;
	output wire [5:0] lfsr;
	reg [5:0] lfsr_latch1;
	reg [5:0] lfsr_next;
	assign lfsr = (reset ? 6'd0 : (phi2 ? lfsr_next : lfsr_latch1));
	always @(posedge clk) begin
		if (phi1)
			lfsr_next <= {~((lfsr_latch1[1] && ~lfsr_latch1[0]) || ~(lfsr_latch1[1] || ~lfsr_latch1[0])), lfsr_latch1[5:1]};
		if (phi2)
			lfsr_latch1 <= lfsr;
		if (reset || sys_reset)
			lfsr_latch1 <= 0;
	end
endmodule
