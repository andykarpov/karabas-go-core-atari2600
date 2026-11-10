module sally (
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
	halt_n,
	addr_oe,
	rw_oe,
	is_halted,
	jammed,
	dbg_a,
	dbg_x,
	dbg_y,
	dbg_s,
	dbg_p,
	dbg_ir,
	dbg_pc
);
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
	input wire halt_n;
	output wire addr_oe;
	output wire rw_oe;
	output wire is_halted;
	output wire jammed;
	output wire [7:0] dbg_a;
	output wire [7:0] dbg_x;
	output wire [7:0] dbg_y;
	output wire [7:0] dbg_s;
	output wire [7:0] dbg_p;
	output wire [7:0] dbg_ir;
	output wire [15:0] dbg_pc;
	reg halt_s;
	reg halt_bus;
	always @(posedge clk_sys)
		if (!res_n) begin
			halt_s <= 1'b0;
			halt_bus <= 1'b0;
		end
		else if (phi2_en) begin
			halt_s <= ~halt_n;
			halt_bus <= halt_s;
		end
	wire core_data_oe;
	wire bus_off;
	assign bus_off = halt_bus;
	assign addr_oe = ~bus_off;
	assign rw_oe = ~bus_off;
	assign data_oe = core_data_oe & ~bus_off;
	assign is_halted = bus_off;
	wire core_phi1_en;
	wire core_phi2_en;
	assign core_phi1_en = phi1_en & ~bus_off;
	assign core_phi2_en = phi2_en & ~bus_off;
	reg phase2;
	always @(posedge clk_sys)
		if (phi1_en)
			phase2 <= 1'b0;
		else if (phi2_en)
			phase2 <= 1'b1;
	assign phi1_out = ~phase2;
	assign phi2_out = phase2;
	mos6502 #(.BCD_EN(1'b1)) core(
		.clk_sys(clk_sys),
		.phi1_en(core_phi1_en),
		.phi2_en(core_phi2_en),
		.res_n(res_n),
		.rdy(rdy),
		.irq_n(irq_n),
		.nmi_n(nmi_n),
		.so_n(so_n),
		.data_in(data_in),
		.data_out(data_out),
		.data_oe(core_data_oe),
		.addr_out(addr_out),
		.rw_n(rw_n),
		.sync(sync),
		.phi1_out(),
		.phi2_out(),
		.jammed(jammed),
		.dbg_a(dbg_a),
		.dbg_x(dbg_x),
		.dbg_y(dbg_y),
		.dbg_s(dbg_s),
		.dbg_p(dbg_p),
		.dbg_ir(dbg_ir),
		.dbg_pc(dbg_pc),
		.dbg_t(),
		.dbg_hold(),
		.dbg_int_active(),
		.dbg_take_int(),
		.dbg_res_active(),
		.dbg_tg()
	);
endmodule
