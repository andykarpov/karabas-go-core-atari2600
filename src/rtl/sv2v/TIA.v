module TIA (
	clk,
	phi0,
	phi2,
	phi1,
	RW_n,
	rdy,
	addr,
	d_in,
	d_out,
	d_out_oe,
	i,
	i_out,
	i4,
	i5,
	aud0,
	aud1,
	col,
	lum,
	BLK_n,
	sync,
	cs0_n,
	cs2_n,
	rst,
	ce,
	video_ce,
	vblank,
	hblank,
	hgap,
	vsync,
	hsync,
	phi1_in,
	phi0_gen,
	phi1_gen,
	is_7800,
	decomb,
	cart_ce,
	row,
	column,
	is_pal,
	is_f1,
	stabilize,
	paddle_read
);
	reg _sv2v_0;
	input clk;
	output wire phi0;
	input phi2;
	output wire phi1;
	input RW_n;
	output wire rdy;
	input [5:0] addr;
	input [7:0] d_in;
	output reg [7:0] d_out;
	output reg [7:0] d_out_oe;
	input [3:0] i;
	output reg [3:0] i_out;
	input i4;
	input i5;
	output wire [3:0] aud0;
	output wire [3:0] aud1;
	output reg [3:0] col;
	output reg [2:0] lum;
	output wire BLK_n;
	output wire sync;
	input cs0_n;
	input cs2_n;
	input rst;
	input ce;
	output wire video_ce;
	output wire vblank;
	output wire hblank;
	output wire hgap;
	output wire vsync;
	output wire hsync;
	input phi1_in;
	output wire phi0_gen;
	output wire phi1_gen;
	input is_7800;
	input decomb;
	output wire cart_ce;
	output reg [9:0] row;
	output reg [9:0] column;
	output wire is_pal;
	output wire is_f1;
	input stabilize;
	output reg [3:0] paddle_read;
	reg [511:0] wreg;
	reg [127:0] rreg;
	wire cs;
	reg wsync;
	reg rsync;
	reg resp0;
	reg resp1;
	reg resm0;
	reg resm1;
	reg resbl;
	reg hmove;
	reg hmclr;
	reg cxclr;
	wire [3:0] color_select;
	wire p0;
	wire p1;
	wire m0;
	wire m1;
	wire bl;
	wire pf;
	wire aclk0;
	wire aclk1;
	wire rhb;
	wire shb;
	wire cnt;
	wire cntd;
	wire sec;
	wire hblank_o;
	wire vblank_o;
	wire vsync_o;
	wire hgap_o;
	wire msrst0;
	wire msrst1;
	wire p0ec;
	wire p1ec;
	wire m0ec;
	wire m1ec;
	wire blec;
	wire rsynl;
	wire rsynd;
	wire motck;
	wire clkp;
	reg hblank_d;
	wire blank;
	reg phi2_delay;
	reg old_hblank;
	reg old_vsync;
	wire [1:0] vsync_count;
	wire hgap_1;
	wire [4:0] hclk;
	wire [4:0] pclk;
	wire [4:0] oclk;
	assign phi0 = pclk[3];
	assign phi1 = pclk[4];
	assign cs = ~cs0_n && ~cs2_n;
	assign video_ce = oclk[3];
	assign BLK_n = blank;
	assign sync = ~(hsync || vsync);
	assign vsync_o = wreg[505];
	assign vblank_o = wreg[497];
	assign cart_ce = oclk[3];
	assign motck = ~oclk[0] & ~hblank_d;
	assign clkp = ~oclk[0];
	f_cell hgap1_out(
		.clk(clk),
		.reset(rst),
		.tick(oclk[2]),
		.s_n(~hgap_o),
		.r_n(hgap_o),
		.q(hgap_1),
		.q_n()
	);
	f_cell hgap_out(
		.clk(clk),
		.reset(rst),
		.tick(oclk[2]),
		.s_n(~hgap_1),
		.r_n(hgap_1),
		.q(hgap),
		.q_n()
	);
	f_cell hblank_out(
		.clk(clk),
		.reset(rst),
		.tick(oclk[2]),
		.s_n(~hblank_o),
		.r_n(hblank_o),
		.q(hblank),
		.q_n()
	);
	f_cell blank_out(
		.clk(clk),
		.reset(rst),
		.tick(oclk[2]),
		.s_n(~(~hblank_o && ~vblank_o)),
		.r_n(~hblank_o && ~vblank_o),
		.q(),
		.q_n(blank)
	);
	video_stabilize stab(
		.clk(clk),
		.reset(rst),
		.oclk(oclk),
		.mode(stabilize),
		.vsync_in(vsync_o),
		.vblank_in(vblank_o),
		.hsync_in(hsync),
		.hblank_in(hgap),
		.vsync(vsync),
		.vblank(vblank),
		.auto_pal(is_pal),
		.f1(is_f1)
	);
	always @(posedge clk) begin
		old_hblank <= hblank_o;
		old_vsync <= vsync_o;
		hblank_d <= hblank_o;
		if (oclk[4])
			column <= column + 1'd1;
		if (old_hblank && !hblank_o) begin
			column <= 0;
			row <= row + 1'd1;
		end
		if (old_vsync && !vsync_o)
			row <= 0;
	end
	always @(posedge clk) begin
		phi2_delay <= pclk[1];
		i_out <= {4 {~wreg[503]}};
		if (pclk[3] || pclk[1]) begin
			if ((cs && ~RW_n) && (addr <= 6'h2c)) begin
				wreg[(63 - addr) * 8+:8] <= d_in;
				if (addr == 6'h1b)
					wreg[0+:8] <= wreg[280+:8];
				if (addr == 6'h1c) begin
					wreg[8+:8] <= wreg[288+:8];
					wreg[16+:8] <= wreg[256+:8];
				end
			end
		end
		{hmclr, cxclr} <= 1'sb0;
		if ((~RW_n && phi2_delay) && cs)
			case (addr)
				6'h2b: hmclr <= 1;
				6'h2c: cxclr <= 1;
				default:
					;
			endcase
		if (hmclr) begin
			wreg[248+:8] <= 0;
			wreg[240+:8] <= 0;
			wreg[232+:8] <= 0;
			wreg[224+:8] <= 0;
			wreg[216+:8] <= 0;
		end
		if (rst) begin
			wreg <= {64 {8'h00}};
			wreg[497] <= 1;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		d_out = 8'h00;
		d_out_oe = 8'h00;
		if (cs && RW_n) begin
			if ((addr[3:0] == 4'hc) && ~wreg[502]) begin
				d_out[7] = i4;
				d_out_oe = 8'b10000000;
			end
			else if ((addr[3:0] == 4'hd) && ~wreg[502]) begin
				d_out[7] = i5;
				d_out_oe = 8'b10000000;
			end
			else if (~&addr[3:1]) begin
				if (addr[3] || (addr[3:0] == 4'h6)) begin
					d_out[7] = rreg[((15 - addr[3:0]) * 8) + 7];
					d_out_oe = 8'b10000000;
				end
				else begin
					d_out[7:6] = rreg[((15 - addr[3:0]) * 8) + 7-:2];
					d_out_oe = 8'b11000000;
				end
			end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		{wsync, rsync, resp0, resp1, resm0, resm1, resbl, hmove} = 1'sb0;
		if ((~RW_n && pclk[1]) && cs)
			case (addr)
				6'h02: wsync = 1;
				6'h03: rsync = 1;
				6'h10: resp0 = 1;
				6'h11: resp1 = 1;
				6'h12: resm0 = 1;
				6'h13: resm1 = 1;
				6'h14: resbl = 1;
				6'h2a: hmove = 1;
				default:
					;
			endcase
		paddle_read = 1'sb0;
		if ((RW_n && pclk[1]) && cs) begin
			paddle_read[0] = addr[3:0] == 4'h8;
			paddle_read[1] = addr[3:0] == 4'h9;
			paddle_read[2] = addr[3:0] == 4'ha;
			paddle_read[3] = addr[3:0] == 4'hb;
		end
	end
	clockgen clockgen(
		.clk(clk),
		.is_7800(is_7800),
		.ce(ce),
		.reset(rst),
		.rsync(rsync),
		.rsynd(rsynd),
		.rsynl(rsynl),
		.pext_1(phi1_in),
		.pext_2(phi2),
		.pclk(pclk),
		.hclk(hclk),
		.oclk(oclk),
		.phi0_ll(),
		.pclk_gen_edge_p1(phi1_gen),
		.pclk_gen_edge_p2(phi0_gen)
	);
	horiz_gen h_gen(
		.clk(clk),
		.rst(rst),
		.hclk(hclk),
		.rsynl(rsynl),
		.rsynd(rsynd),
		.sec(sec),
		.hsync(hsync),
		.hgap(hgap_o),
		.hblank(hblank_o),
		.cntd(cntd),
		.cnt(cnt),
		.aud0(aclk0),
		.aud1(aclk1),
		.shb(shb),
		.rhb(rhb),
		.CB()
	);
	playfield playfield(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.hclk(hclk),
		.rhb(rhb),
		.reflect(wreg[424]),
		.cnt(cnt),
		.pfc({wreg[384+:8], wreg[392+:8], wreg[407-:4]}),
		.pf(pf)
	);
	hmove_gen hmv(
		.clk(clk),
		.reset(rst),
		.sec(sec),
		.hclk(hclk),
		.oclk(oclk),
		.pclk(pclk),
		.hmove(hmove),
		.hblank(hblank_o),
		.p0_m((hmclr ? 4'd0 : wreg[255-:4])),
		.p1_m((hmclr ? 4'd0 : wreg[247-:4])),
		.m0_m((hmclr ? 4'd0 : wreg[239-:4])),
		.m1_m((hmclr ? 4'd0 : wreg[231-:4])),
		.bl_m((hmclr ? 4'd0 : wreg[223-:4])),
		.p0_mclk(p0ec),
		.p1_mclk(p1ec),
		.m0_mclk(m0ec),
		.m1_mclk(m1ec),
		.bl_mclk(blec)
	);
	player pl1(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.motck(motck),
		.pec(p0ec),
		.pre(resp0),
		.pvdel(wreg[208]),
		.m2pr(wreg[185]),
		.pref(wreg[419]),
		.nusiz(wreg[477-:6]),
		.grpnew(wreg[288+:8]),
		.grpold(wreg[8+:8]),
		.msrst(msrst0),
		.p(p0)
	);
	player pl2(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.motck(motck),
		.pec(p1ec),
		.pre(resp1),
		.pvdel(wreg[200]),
		.m2pr(wreg[177]),
		.pref(wreg[411]),
		.nusiz(wreg[469-:6]),
		.grpnew(wreg[280+:8]),
		.grpold(wreg[0+:8]),
		.msrst(msrst1),
		.p(p1)
	);
	missile mis0(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.motck(motck),
		.mec(m0ec),
		.mre(resm0 || (wreg[185] && msrst0)),
		.men(wreg[273] && ~wreg[185]),
		.nusiz(wreg[477-:6]),
		.m(m0)
	);
	missile mis1(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.motck(motck),
		.mec(m1ec),
		.mre(resm1 || (wreg[177] && msrst1)),
		.men(wreg[265] && ~wreg[177]),
		.nusiz(wreg[469-:6]),
		.m(m1)
	);
	ball bal(
		.clk(clk),
		.reset(rst),
		.clkp(clkp),
		.motck(motck),
		.blec(blec),
		.blre(resbl),
		.blen(wreg[257]),
		.blen_o(wreg[17]),
		.blvd(wreg[192]),
		.blsiz(wreg[429-:2]),
		.bl(bl)
	);
	priority_encoder prior(
		.clk(clk),
		.p0(p0),
		.m0(m0),
		.p1(p1),
		.m1(m1),
		.bl(bl),
		.pf(pf),
		.cntd(cntd),
		.blank(blank),
		.pfp(wreg[426]),
		.score(wreg[425]),
		.col_select(color_select)
	);
	audio_channel audio0(
		.clk(clk),
		.reset(rst),
		.aud0(aclk0),
		.aud1(aclk1),
		.volume(wreg[307-:4]),
		.freq(wreg[324-:5]),
		.audc(wreg[339-:4]),
		.audio(aud0)
	);
	audio_channel audio1(
		.clk(clk),
		.reset(rst),
		.aud0(aclk0),
		.aud1(aclk1),
		.volume(wreg[299-:4]),
		.freq(wreg[316-:5]),
		.audc(wreg[331-:4]),
		.audio(aud1)
	);
	always @(posedge clk)
		if (oclk[4]) begin
			if (hblank || vblank_o)
				{col, lum} <= (decomb ? wreg[439-:7] : 7'h00);
			else
				case (color_select)
					4'b0001: {col, lum} <= wreg[463-:7];
					4'b0010: {col, lum} <= wreg[455-:7];
					4'b0100: {col, lum} <= wreg[447-:7];
					4'b1000: {col, lum} <= wreg[439-:7];
					default: {col, lum} <= 7'd0;
				endcase
		end
	wire rdy_q;
	assign rdy = ~rdy_q;
	sr_latch in_sr(
		.clk(clk),
		.reset(rst),
		.r(shb),
		.s(wsync),
		.q(rdy_q),
		.q_n()
	);
	always @(posedge clk) begin : read_reg_block
		if (cxclr)
			{rreg[127-:2], rreg[119-:2], rreg[111-:2], rreg[103-:2], rreg[95-:2], rreg[87-:2], rreg[79-:2], rreg[71-:2]} <= 1'sb0;
		else if (oclk[1] && ~vblank_o) begin
			rreg[127-:2] <= rreg[127-:2] | {m0 && p1, m0 && p0};
			rreg[119-:2] <= rreg[119-:2] | {m1 && p0, m1 && p1};
			rreg[111-:2] <= rreg[111-:2] | {p0 && pf, p0 && bl};
			rreg[103-:2] <= rreg[103-:2] | {p1 && pf, p1 && bl};
			rreg[95-:2] <= rreg[95-:2] | {m0 && pf, m0 && bl};
			rreg[87-:2] <= rreg[87-:2] | {m1 && pf, m1 && bl};
			rreg[79-:2] <= rreg[79-:2] | {bl && pf, 1'b0};
			rreg[71-:2] <= rreg[71-:2] | {p0 && p1, m0 && m1};
		end
		begin : sv2v_autoblock_1
			reg [2:0] x;
			for (x = 0; x < 4; x = x + 1'd1)
				rreg[((15 - {2'b10, x[1:0]}) * 8) + 7] <= (wreg[503] ? 1'b0 : i[x[1:0]]);
		end
		if (~wreg[502])
			{rreg[31], rreg[23]} <= 1'sb1;
		else begin
			if (~i4)
				rreg[31] <= 0;
			if (~i5)
				rreg[23] <= 0;
		end
		if ((pclk[3] && cs) && ~RW_n) begin
			if ((addr == 6'h01) && d_in[6])
				{rreg[31], rreg[23]} <= 1'sb1;
		end
		if (rst)
			rreg <= {16 {8'h00}};
	end
	initial _sv2v_0 = 0;
endmodule
