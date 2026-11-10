module player (
	clk,
	reset,
	clkp,
	motck,
	pec,
	pre,
	pvdel,
	m2pr,
	pref,
	nusiz,
	grpnew,
	grpold,
	msrst,
	p
);
	input clk;
	input reset;
	input clkp;
	input motck;
	input pec;
	input pre;
	input pvdel;
	input m2pr;
	input pref;
	input [5:0] nusiz;
	input [7:0] grpnew;
	input [7:0] grpold;
	output wire msrst;
	output wire p;
	wire [4:0] objclk;
	wire [1:0] d1l_1;
	wire [1:0] d1l_2;
	wire [5:0] lfsr;
	wire fstob;
	wire fc1_qn;
	wire ena_n;
	wire start_n;
	wire f_psc1_q;
	wire f_psc1_q_n;
	wire f_psc2_q;
	wire f_psc2_q_n;
	wire f_psc3_q;
	wire f_psc3_q_n;
	wire go_n;
	wire or_d;
	wire [2:0] gs;
	wire object_tick;
	wire [2:0] ns_sel = nusiz[2:0];
	wire q_or_res;
	wire object_reset = ((lfsr == 6'b111111) || (lfsr == 6'b101101)) || q_or_res;
	wire object_fstob = (((lfsr == 6'b111000) && ((ns_sel == 3'b001) || (ns_sel == 3'b011))) || ((lfsr == 6'b101111) && (((ns_sel == 3'b011) || (ns_sel == 3'b010)) || (ns_sel == 3'b110)))) || ((lfsr == 6'b111001) && ((ns_sel == 3'b100) || (ns_sel == 3'b110)));
	wire object_draw = (lfsr == 6'b101101) || object_fstob;
	wire pns = ~(~nusiz[0] || ~nusiz[2]);
	wire pns2 = objclk[2] && ~nusiz[1];
	wire count_n = ~((~pns || pns2) || objclk[1]);
	wire stop = ~((f_psc1_q_n || f_psc2_q_n) || f_psc3_q_n);
	wire start_stop = ~(start_n && stop);
	wire newgrp = grpnew[gs];
	wire oldgrp = grpold[gs];
	assign msrst = ~((((((fstob || ena_n) || object_tick) || f_psc3_q) || f_psc2_q) || f_psc1_q_n) || ~m2pr);
	assign gs[0] = ~((pref && f_psc1_q_n) || (~pref && f_psc1_q));
	assign gs[1] = ~((pref && f_psc2_q_n) || (~pref && f_psc2_q));
	assign gs[2] = ~((pref && f_psc3_q_n) || (~pref && f_psc3_q));
	object_tick p_tick(
		.clk(clk),
		.reset(reset),
		.motck(motck),
		.ec(pec),
		.tick(object_tick)
	);
	f_counter_ll object_counter(
		.clk(clk),
		.reset(pre),
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
	wire pl_1a = ~((go_n || ~oldgrp) || ~pvdel);
	wire pl_1b = ~((go_n || ~newgrp) || pvdel);
	wire pl_2 = ~(pl_1a || pl_1b);
	f_cell pl_out(
		.clk(clk),
		.reset(reset),
		.tick(clkp),
		.s_n(pl_2),
		.r_n(~pl_2),
		.q(p),
		.q_n()
	);
	d_cell obj_reset(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(object_reset),
		.out(or_d)
	);
	d_cell obj_start(
		.clk(clk),
		.reset(reset),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(~object_draw),
		.out(start_n)
	);
	d_cell obj_fstob(
		.clk(clk),
		.reset(reset || or_d),
		.phi1(objclk[2]),
		.phi2(objclk[1]),
		.in(fstob || object_fstob),
		.out(fstob)
	);
	f_cell f_ena(
		.clk(clk),
		.reset(reset),
		.tick(object_tick),
		.s_n(count_n),
		.r_n(~count_n),
		.q(),
		.q_n(ena_n)
	);
	f_cell f_go(
		.clk(clk),
		.reset(reset),
		.tick(object_tick),
		.s_n(ena_n || start_n),
		.r_n(ena_n || start_stop),
		.q(),
		.q_n(go_n)
	);
	wire ena_n_or_go_n = ena_n || go_n;
	f_cell f_psc1(
		.clk(clk),
		.reset(reset),
		.tick(object_tick),
		.s_n(ena_n_or_go_n || f_psc1_q),
		.r_n(ena_n_or_go_n || f_psc1_q_n),
		.q(f_psc1_q),
		.q_n(f_psc1_q_n)
	);
	wire ena_n_or_go_2 = ena_n_or_go_n || f_psc1_q_n;
	f_cell f_psc2(
		.clk(clk),
		.reset(reset),
		.tick(object_tick),
		.s_n(ena_n_or_go_2 || f_psc2_q),
		.r_n(ena_n_or_go_2 || f_psc2_q_n),
		.q(f_psc2_q),
		.q_n(f_psc2_q_n)
	);
	wire ena_n_or_go_3 = ena_n_or_go_2 || f_psc2_q_n;
	f_cell f_psc3(
		.clk(clk),
		.reset(reset),
		.tick(object_tick),
		.s_n(ena_n_or_go_3 || f_psc3_q),
		.r_n(ena_n_or_go_3 || f_psc3_q_n),
		.q(f_psc3_q),
		.q_n(f_psc3_q_n)
	);
endmodule
