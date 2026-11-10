module playfield (
	clk,
	reset,
	clkp,
	hclk,
	reflect,
	cnt,
	rhb,
	pfc,
	pf
);
	input clk;
	input reset;
	input wire clkp;
	input wire [4:0] hclk;
	input reflect;
	input cnt;
	input rhb;
	input [19:0] pfc;
	output wire pf;
	wire [4:0] pf_index;
	wire [4:0] pf_next;
	reg [4:0] pf_latch2;
	reg [4:0] pf_latch1;
	wire pf_1;
	wire pf_2;
	wire pf_3;
	wire [104:0] index_lut;
	wire pf_reset = rhb || (cnt && ~reflect);
	wire pf_reflect = cnt && reflect;
	assign index_lut = 105'h000886b525073148c6b9f08ca74;
	wire [4:0] pf_latch;
	wire dir;
	localparam PF_EMPTY = 5'd20;
	wire [20:0] pf_bits = {1'b0, pfc};
	assign pf_index = (pf_reset ? 1'd0 : (hclk[1] ? pf_latch1 : pf_latch2));
	assign pf_next = (pf_index == PF_EMPTY ? PF_EMPTY : (dir ? (|pf_index ? pf_index - 1'd1 : PF_EMPTY) : (pf_index < 19 ? pf_index + 1'd1 : (reflect ? 5'd19 : PF_EMPTY))));
	assign pf_1 = pf_bits[index_lut[(20 - pf_index) * 5+:5]];
	f_cell pf_out(
		.clk(clk),
		.reset(reset),
		.tick(clkp),
		.s_n(~pf_3),
		.r_n(pf_3),
		.q(pf),
		.q_n()
	);
	sr_latch dir_l(
		.clk(clk),
		.reset(reset),
		.r(pf_reset),
		.s(pf_reflect),
		.q(dir),
		.q_n()
	);
	inverter_reg pf1_ir(
		.clk(clk),
		.reset(reset),
		.set(hclk[2]),
		.in(pf_1),
		.out(pf_2)
	);
	inverter_reg pf2_ir(
		.clk(clk),
		.reset(reset),
		.set(hclk[1]),
		.in(pf_2),
		.out(pf_3)
	);
	always @(posedge clk) begin : pf_block
		if (hclk[2])
			pf_latch1 <= pf_next;
		if (hclk[1])
			pf_latch2 <= pf_latch1;
	end
endmodule
