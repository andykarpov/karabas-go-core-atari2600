module priority_encoder (
	clk,
	p0,
	m0,
	p1,
	m1,
	pf,
	bl,
	blank,
	cntd,
	pfp,
	score,
	col_select
);
	input clk;
	input p0;
	input m0;
	input p1;
	input m1;
	input pf;
	input bl;
	input blank;
	input cntd;
	input pfp;
	input score;
	output wire [3:0] col_select;
	wire rs_q;
	wire rs_qn;
	sr_latch center_delayed(
		.clk(clk),
		.reset(),
		.r(blank),
		.s(cntd),
		.q(rs_q),
		.q_n(rs_qn)
	);
	wire score_n = ~score;
	wire pfp_n = ~pfp;
	wire pf_n = ~pf;
	wire pf_nor_bl = ~(pf || bl);
	wire pr_1a = ~((rs_q || pf_n) || score_n);
	wire pr_1b = ~((pf_n || score_n) || rs_qn);
	wire pr_2a = ~((p0 || m0) || pr_1a);
	wire pr_2b = ~((p1 || m1) || pr_1b);
	wire pr_2c = ~(pf_nor_bl || pfp_n);
	wire sel_p0 = ~((blank || pr_2a) || pr_2c);
	wire sel_p1 = ~(((blank || pr_2b) || pr_2c) || sel_p0);
	wire sel_pf = ~(((blank || pf_nor_bl) || sel_p1) || sel_p0);
	wire sel_bk = ~(((blank || sel_pf) || sel_p1) || sel_p0);
	assign col_select = {sel_bk, sel_pf, sel_p1, sel_p0};
endmodule
