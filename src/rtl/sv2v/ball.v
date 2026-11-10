module ball (
	clk,
	reset,
	clkp,
	motck,
	blec,
	blre,
	blen,
	blen_o,
	blvd,
	blsiz,
	bl
);
	input clk;
	input reset;
	input clkp;
	input motck;
	input blec;
	input blre;
	input blen;
	input blen_o;
	input blvd;
	input [1:0] blsiz;
	output wire bl;
	wire [4:0] objclk;
	wire [1:0] d1l_1;
	wire [1:0] d1l_2;
	wire [5:0] lfsr;
	wire fc1_qn;
	wire q_or_res;
	wire object_tick;
	wire object_reset = ((lfsr == 6'b111111) || (lfsr == 6'b101101)) || q_or_res;
	object_tick bl_tick(
		.clk(clk),
		.reset(reset),
		.motck(motck),
		.ec(blec),
		.tick(object_tick)
	);
	f_counter_ll object_counter(
		.clk(clk),
		.reset(blre),
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
		.reset(~d1l_1[1]),
		.sys_reset(reset),
		.lfsr(lfsr)
	);
	wire gr1 = ~((~blvd && blen) || (blvd && blen_o));
	wire gr2a = ~(((~blsiz[1] || ~blsiz[0]) || d1l_2[1]) || gr1);
	wire gr2b = ~(~blsiz[0] || fc1_qn);
	wire gr3 = ~((blsiz[1] || gr2b) || objclk[1]);
	wire gr4 = ~((gr1 || gr3) || d1l_1[1]);
	wire gr5 = ~(gr2a || gr4);
	f_cell ball_out(
		.clk(clk),
		.reset(reset),
		.tick(clkp),
		.s_n(gr5),
		.r_n(~gr5),
		.q(bl),
		.q_n()
	);
	d_cell obj_1(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(~object_reset),
		.out(d1l_1[1])
	);
	d_cell obj_2(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(d1l_1[1]),
		.out(d1l_2[1])
	);
endmodule
