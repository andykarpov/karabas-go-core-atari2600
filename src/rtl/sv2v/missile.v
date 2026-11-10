module missile (
	clk,
	reset,
	clkp,
	motck,
	mec,
	mre,
	men,
	nusiz,
	m
);
	input clk;
	input reset;
	input clkp;
	input motck;
	input mec;
	input mre;
	input men;
	input [5:0] nusiz;
	output wire m;
	wire [4:0] objclk;
	wire [1:0] d1l_1;
	wire [1:0] d1l_2;
	wire [5:0] lfsr;
	wire fc1_qn;
	wire or_d;
	wire object_tick;
	wire [1:0] m_size_n = ~nusiz[5:4];
	wire [2:0] ns_sel = nusiz[2:0];
	wire q_or_res;
	wire object_reset = ((lfsr == 6'b111111) || (lfsr == 6'b101101)) || q_or_res;
	wire object_draw = (((lfsr == 6'b101101) || ((lfsr == 6'b111000) && ((ns_sel == 3'b001) || (ns_sel == 3'b011)))) || ((lfsr == 6'b101111) && (((ns_sel == 3'b011) || (ns_sel == 3'b010)) || (ns_sel == 3'b110)))) || ((lfsr == 6'b111001) && ((ns_sel == 3'b100) || (ns_sel == 3'b110)));
	object_tick m_tick(
		.clk(clk),
		.reset(reset),
		.motck(motck),
		.ec(mec),
		.tick(object_tick)
	);
	f_counter_ll object_counter(
		.clk(clk),
		.reset(mre),
		.sys_reset(reset),
		.tick(object_tick),
		.clock(objclk),
		.f1_qn(fc1_qn),
		.f1_q_l(q_or_res)
	);
	lfsr_6 object_lfsr(
		.clk(clk),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.reset(or_d),
		.sys_reset(reset),
		.lfsr(lfsr)
	);
	wire mg1 = ~(fc1_qn || m_size_n[0]);
	wire mg2a = ~((mg1 || objclk[1]) || ~m_size_n[1]);
	wire mg2b = ~(((~men || m_size_n[1]) || d1l_2[1]) || m_size_n[0]);
	wire mg3 = ~((mg2a || ~men) || d1l_1[1]);
	wire mg4 = ~(mg3 || mg2b);
	f_cell mis_out(
		.clk(clk),
		.reset(reset),
		.tick(clkp),
		.s_n(mg4),
		.r_n(~mg4),
		.q(m),
		.q_n()
	);
	d_cell obj_1(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(object_reset),
		.out(or_d)
	);
	d_cell obj_2(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(~object_draw),
		.out(d1l_1[1])
	);
	d_cell obj_3(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(d1l_1[1]),
		.out(d1l_2[1])
	);
endmodule
