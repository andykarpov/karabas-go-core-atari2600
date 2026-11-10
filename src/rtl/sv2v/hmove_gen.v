module hmove_gen (
	clk,
	reset,
	hclk,
	oclk,
	pclk,
	hmove,
	hblank,
	p0_m,
	p1_m,
	m0_m,
	m1_m,
	bl_m,
	sec,
	p0_mclk,
	p1_mclk,
	m0_mclk,
	m1_mclk,
	bl_mclk
);
	input wire clk;
	input wire reset;
	input wire [4:0] hclk;
	input wire [4:0] oclk;
	input wire [4:0] pclk;
	input wire hmove;
	input wire hblank;
	input wire [3:0] p0_m;
	input wire [3:0] p1_m;
	input wire [3:0] m0_m;
	input wire [3:0] m1_m;
	input wire [3:0] bl_m;
	output wire sec;
	output wire p0_mclk;
	output wire p1_mclk;
	output wire m0_mclk;
	output wire m1_mclk;
	output wire bl_mclk;
	reg [1:0] p0ec;
	reg [1:0] p1ec;
	reg [1:0] m0ec;
	reg [1:0] m1ec;
	reg [1:0] blec;
	reg [3:0] hmove_cnt;
	wire sec_1;
	wire sec_0;
	wire hmove_latch;
	wire [3:0] hmc_uns = {~hmove_cnt[3], hmove_cnt[2:0]};
	assign p0_mclk = p0ec[1] && hclk[2];
	assign p1_mclk = p1ec[1] && hclk[2];
	assign m0_mclk = m0ec[1] && hclk[2];
	assign m1_mclk = m1ec[1] && hclk[2];
	assign bl_mclk = blec[1] && hclk[2];
	sr_latch hmove_l(
		.clk(clk),
		.reset(reset),
		.r(sec_1),
		.s(hmove),
		.q(hmove_latch),
		.q_n()
	);
	inverter_reg s0_ir(
		.clk(clk),
		.reset(reset),
		.set(hclk[2]),
		.in(hmove_latch),
		.out(sec_0)
	);
	inverter_reg sec_ir(
		.clk(clk),
		.reset(reset),
		.set(hclk[1]),
		.in(sec_0),
		.out(sec)
	);
	inverter_reg sec1_ir(
		.clk(clk),
		.reset(reset),
		.set(hclk[2]),
		.in(sec),
		.out(sec_1)
	);
	always @(posedge clk) begin : hmove_block
		if (hclk[3]) begin
			if (sec || |hmove_cnt)
				hmove_cnt <= hmove_cnt + 1'd1;
			{p0ec[1], p1ec[1], m0ec[1], m1ec[1], blec[1]} <= {p0ec[0], p1ec[0], m0ec[0], m1ec[0], blec[0]};
		end
		if (hclk[2]) begin
			if (sec && ~sec_1)
				{p0ec[0], p1ec[0], m0ec[0], m1ec[0], blec[0]} <= 5'b11111;
			if (p0_m[3:0] == hmc_uns)
				p0ec[0] <= 0;
			if (p1_m[3:0] == hmc_uns)
				p1ec[0] <= 0;
			if (m0_m[3:0] == hmc_uns)
				m0ec[0] <= 0;
			if (m1_m[3:0] == hmc_uns)
				m1ec[0] <= 0;
			if (bl_m[3:0] == hmc_uns)
				blec[0] <= 0;
		end
		if (reset) begin
			{p0ec, p1ec, m0ec, m1ec, blec} <= 10'd0;
			hmove_cnt <= 0;
		end
	end
endmodule
