module f_counter_ll (
	clk,
	reset,
	sys_reset,
	tick,
	clock,
	f1_qn,
	f1_q_l
);
	input wire clk;
	input wire reset;
	input wire sys_reset;
	input wire tick;
	output wire [4:0] clock;
	output wire f1_qn;
	output wire f1_q_l;
	wire q_left;
	wire q_left_n;
	wire q_right;
	wire q_right_n;
	wire f1_q_l_l;
	assign clock[0] = 0;
	assign clock[4] = 0;
	assign clock[3] = 0;
	assign clock[2] = ~(q_left || q_right);
	assign clock[1] = ~(q_left_n || q_right_n);
	assign f1_qn = q_right_n;
	f_cell f_left(
		.clk(clk),
		.reset(reset || sys_reset),
		.tick(tick),
		.s_n(q_right),
		.r_n(q_right_n),
		.q(q_left),
		.q_n(q_left_n)
	);
	f_cell f_right(
		.clk(clk),
		.reset(reset || sys_reset),
		.tick(tick),
		.s_n(q_left_n),
		.r_n(q_left),
		.q(q_right),
		.q_n(q_right_n)
	);
	sr_latch q_1l(
		.clk(clk),
		.reset(sys_reset),
		.r(~q_right_n),
		.s(reset),
		.q(f1_q_l),
		.q_n()
	);
endmodule
