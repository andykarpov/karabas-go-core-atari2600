module mos6502 (
	clk_sys,
	phi1_en,
	phi2_en,
	res_n,
	rdy,
	irq_n,
	nmi_n,
	so_n,
	data_in,
	data_out,
	data_oe,
	addr_out,
	rw_n,
	sync,
	phi1_out,
	phi2_out,
	jammed,
	dbg_a,
	dbg_x,
	dbg_y,
	dbg_s,
	dbg_p,
	dbg_ir,
	dbg_pc,
	dbg_t,
	dbg_hold,
	dbg_int_active,
	dbg_take_int,
	dbg_res_active,
	dbg_tg
);
	parameter [0:0] BCD_EN = 1'b1;
	input wire clk_sys;
	input wire phi1_en;
	input wire phi2_en;
	input wire res_n;
	input wire rdy;
	input wire irq_n;
	input wire nmi_n;
	input wire so_n;
	input wire [7:0] data_in;
	output wire [7:0] data_out;
	output wire data_oe;
	output wire [15:0] addr_out;
	output wire rw_n;
	output wire sync;
	output wire phi1_out;
	output wire phi2_out;
	output wire jammed;
	output wire [7:0] dbg_a;
	output wire [7:0] dbg_x;
	output wire [7:0] dbg_y;
	output wire [7:0] dbg_s;
	output wire [7:0] dbg_p;
	output wire [7:0] dbg_ir;
	output wire [15:0] dbg_pc;
	output wire [3:0] dbg_t;
	output wire dbg_hold;
	output wire dbg_int_active;
	output wire dbg_take_int;
	output wire dbg_res_active;
	output wire [15:0] dbg_tg;
	wire [75:0] c;
	wire sync_ctl;
	wire [7:0] ir;
	wire [7:0] a;
	wire [7:0] x;
	wire [7:0] y;
	wire [7:0] s;
	wire [7:0] p;
	wire [7:0] dl;
	wire [7:0] pcl;
	wire [7:0] pch;
	wire acr_now;
	mos6502_ctl #(.BCD_EN(BCD_EN)) ctl(
		.clk_sys(clk_sys),
		.phi1_en(phi1_en),
		.phi2_en(phi2_en),
		.res_n(res_n),
		.rdy(rdy),
		.irq_n(irq_n),
		.nmi_n(nmi_n),
		.so_n(so_n),
		.data_in(data_in),
		.p(p),
		.acr_now(acr_now),
		.dl(dl),
		.c(c),
		.ir(ir),
		.sync(sync_ctl),
		.jammed(jammed),
		.dbg_t(dbg_t),
		.dbg_hold(dbg_hold),
		.dbg_int_active(dbg_int_active),
		.dbg_take_int(dbg_take_int),
		.dbg_res_active(dbg_res_active),
		.dbg_tg(dbg_tg)
	);
	mos6502_dp #(.BCD_EN(BCD_EN)) dp(
		.clk_sys(clk_sys),
		.phi1_en(phi1_en),
		.phi2_en(phi2_en),
		.c(c),
		.ir(ir),
		.data_in(data_in),
		.a(a),
		.x(x),
		.y(y),
		.s(s),
		.p(p),
		.dl(dl),
		.addr_out(addr_out),
		.data_out(data_out),
		.acr_now(acr_now),
		.pcl(pcl),
		.pch(pch)
	);
	assign dbg_a = a;
	assign dbg_x = x;
	assign dbg_y = y;
	assign dbg_s = s;
	assign dbg_p = p;
	assign dbg_ir = ir;
	assign dbg_pc = {pch, pcl};
	reg phase2;
	always @(posedge clk_sys)
		if (phi1_en)
			phase2 <= 1'b0;
		else if (phi2_en)
			phase2 <= 1'b1;
	assign phi1_out = ~phase2;
	assign phi2_out = phase2;
	reg wr_pin;
	reg sync_pin;
	always @(posedge clk_sys)
		if (phi1_en) begin
			wr_pin <= c[0];
			sync_pin <= sync_ctl;
		end
	assign rw_n = ~wr_pin;
	assign sync = sync_pin;
	assign data_oe = wr_pin & phase2;
endmodule
