module horiz_gen (
	clk,
	rst,
	hclk,
	rsynl,
	sec,
	hsync,
	CB,
	cntd,
	cnt,
	hblank,
	hgap,
	aud0,
	aud1,
	shb,
	rhb,
	rsynd
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire [4:0] hclk;
	input wire rsynl;
	input wire sec;
	output wire hsync;
	output wire CB;
	output wire cntd;
	output reg cnt;
	output wire hblank;
	output wire hgap;
	output wire aud0;
	output wire aud1;
	output wire shb;
	output reg rhb;
	output wire rsynd;
	wire [5:0] lfsr;
	wire sec_latch;
	wire sec_latch_n;
	reg err;
	reg rhs;
	reg rcb;
	reg shs;
	reg lrhb;
	reg ehb;
	wire aud1_l;
	wire aud2_l;
	wire rhs_d;
	wire hblank_n;
	wire hgap_n;
	assign aud0 = aud1_l;
	assign aud1 = aud2_l;
	wire eer = (ehb || rsynl) || err;
	lfsr_6 timing_lfsr(
		.clk(clk),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.reset(shb || rst),
		.sys_reset(rst),
		.lfsr(lfsr)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		{err, rhs, ehb, cnt, shs, lrhb, rhb, rcb} = 1'sb0;
		case (lfsr)
			6'b111111: err = 1;
			6'b010100: ehb = 1;
			6'b110111: rhs = 1;
			6'b101100: cnt = 1;
			6'b001111: rcb = 1;
			6'b111100: shs = 1;
			6'b011100: rhb = 1;
			6'b010111: lrhb = 1;
			default:
				;
		endcase
	end
	sr_latch sec_l(
		.clk(clk),
		.reset(rst),
		.r(sec),
		.s(shb),
		.q(sec_latch),
		.q_n(sec_latch_n)
	);
	inverter_reg rsynd_ir(
		.clk(clk),
		.reset(rst),
		.set(hclk[2]),
		.in(eer),
		.out(rsynd)
	);
	inverter_reg shb_ir(
		.clk(clk),
		.reset(rst),
		.set(hclk[1]),
		.in(rsynd),
		.out(shb)
	);
	d_cell aud1_d(
		.clk(clk),
		.reset(rst),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(shb || lrhb),
		.out(aud1_l)
	);
	d_cell aud2_d(
		.clk(clk),
		.reset(rst),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(rhs || cnt),
		.out(aud2_l)
	);
	d_cell rhs_db(
		.clk(clk),
		.reset(rst),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(rhs),
		.out(rhs_d)
	);
	d_cell hsync_dl(
		.clk(clk),
		.reset(rst || rhs_d),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(hsync || shs),
		.out(hsync)
	);
	wire hb_1a = sec_latch && rhb;
	wire hb_1b = sec_latch_n && lrhb;
	d_cell hblank_dl(
		.clk(clk),
		.reset(rst || shb),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in((hblank_n || hb_1a) || hb_1b),
		.out(hblank_n)
	);
	assign hblank = ~hblank_n;
	d_cell hgap_dl(
		.clk(clk),
		.reset(rst || shb),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(hgap_n || rhb),
		.out(hgap_n)
	);
	assign hgap = ~hgap_n;
	d_cell cb_dl(
		.clk(clk),
		.reset(rst || rhs_d),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(CB || rcb),
		.out(CB)
	);
	d_cell cnt_d(
		.clk(clk),
		.reset(rst),
		.phi1(hclk[2]),
		.phi2(hclk[1]),
		.in(cnt),
		.out(cntd)
	);
	initial _sv2v_0 = 0;
endmodule
