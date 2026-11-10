module mos6502_dp (
	clk_sys,
	phi1_en,
	phi2_en,
	c,
	ir,
	data_in,
	a,
	x,
	y,
	s,
	p,
	dl,
	addr_out,
	data_out,
	acr_now,
	pcl,
	pch
);
	reg _sv2v_0;
	parameter [0:0] BCD_EN = 1'b1;
	input wire clk_sys;
	input wire phi1_en;
	input wire phi2_en;
	input wire [75:0] c;
	input wire [7:0] ir;
	input wire [7:0] data_in;
	output reg [7:0] a;
	output reg [7:0] x;
	output reg [7:0] y;
	output wire [7:0] s;
	output wire [7:0] p;
	output reg [7:0] dl;
	output wire [15:0] addr_out;
	output wire [7:0] data_out;
	output wire acr_now;
	output reg [7:0] pcl;
	output reg [7:0] pch;
	reg [7:0] s_in;
	reg [7:0] s_out;
	reg [7:0] pcls;
	reg [7:0] pchs;
	reg [7:0] abl;
	reg [7:0] abh;
	reg [7:0] dor;
	reg [7:0] ai;
	reg [7:0] bi;
	reg [7:0] add;
	reg acr;
	reg avr;
	reg p_n;
	reg p_v;
	reg p_d;
	reg p_i;
	reg p_z;
	reg p_c;
	wire [7:0] p_out;
	reg [7:0] db;
	reg [7:0] sb;
	reg [7:0] adl;
	reg [7:0] adh;
	reg [7:0] db_raw;
	reg [7:0] sb_raw;
	reg [7:0] adh_raw;
	always @(*) begin
		if (_sv2v_0)
			;
		db_raw = 8'hff;
		if (c[75])
			db_raw = db_raw & dl;
		if (c[72])
			db_raw = db_raw & pcl;
		if (c[70])
			db_raw = db_raw & pch;
		if (c[63])
			db_raw = db_raw & a;
		if (c[59])
			db_raw = db_raw & p_out;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		sb_raw = 8'hff;
		if (c[68])
			sb_raw = sb_raw & s_out;
		if (c[66])
			sb_raw = sb_raw & x;
		if (c[65])
			sb_raw = sb_raw & y;
		if (c[64])
			sb_raw = sb_raw & a;
		if (c[62])
			sb_raw[6:0] = sb_raw[6:0] & add[6:0];
		if (c[61])
			sb_raw[7] = sb_raw[7] & add[7];
	end
	always @(*) begin
		if (_sv2v_0)
			;
		adl = 8'hff;
		if (c[74])
			adl = adl & dl;
		if (c[71])
			adl = adl & pcl;
		if (c[67])
			adl = adl & s_out;
		if (c[60])
			adl = adl & add;
		if (c[58])
			adl[0] = 1'b0;
		if (c[57])
			adl[1] = 1'b0;
		if (c[56])
			adl[2] = 1'b0;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		adh_raw = 8'hff;
		if (c[73])
			adh_raw = adh_raw & dl;
		if (c[69])
			adh_raw = adh_raw & pch;
		if (c[55])
			adh_raw[0] = 1'b0;
		if (c[54])
			adh_raw[7:1] = 7'b0000000;
	end
	always @(*) begin : sv2v_autoblock_1
		reg [7:0] merged;
		if (_sv2v_0)
			;
		merged = sb_raw;
		if (c[53])
			merged = merged & db_raw;
		if (c[52])
			merged = merged & adh_raw;
		sb = merged;
		db = (c[53] ? merged : db_raw);
		adh = (c[52] ? merged : adh_raw);
	end
	wire [7:0] alu_res;
	wire [7:0] a_next;
	wire alu_acr;
	wire alu_avr;
	wire alu_hc;
	wire alu_active;
	assign alu_active = (((c[33] | c[32]) | c[31]) | c[30]) | c[29];
	reg hc_held;
	mos6502_alu #(.BCD_EN(BCD_EN)) alu(
		.ai(ai),
		.bi(bi),
		.cin(c[28]),
		.sums(c[33]),
		.ands(c[32]),
		.eors(c[31]),
		.ors(c[30]),
		.srs(c[29]),
		.daa(c[27]),
		.res(alu_res),
		.acr(alu_acr),
		.avr(alu_avr),
		.hc(alu_hc)
	);
	wire [7:0] daa_out;
	mos6502_daa #(.BCD_EN(BCD_EN)) adjust(
		.sb(sb),
		.daa(c[27]),
		.dsa(c[26]),
		.hc(hc_held),
		.acr(acr),
		.out(daa_out)
	);
	reg arr_lo_q;
	reg arr_hi_q;
	reg [7:0] arr_fix;
	always @(*) begin
		if (_sv2v_0)
			;
		arr_fix = sb;
		if (arr_lo_q)
			arr_fix[3:0] = sb[3:0] + 4'd6;
		if (arr_hi_q)
			arr_fix[7:4] = sb[7:4] + 4'd6;
	end
	assign a_next = (c[23] ? arr_fix : daa_out);
	wire pc_carry;
	wire [7:0] pcl_next;
	wire [7:0] pch_next;
	assign {pc_carry, pcl_next} = {1'b0, pcls} + {8'b00000000, c[22]};
	assign pch_next = pchs + {7'b0000000, pc_carry};
	assign p = {p_n, p_v, 2'b00, p_d, p_i, p_z, p_c};
	assign p_out = {p_n, p_v | c[10], 1'b1, c[1], p_d, p_i, p_z, p_c};
	always @(posedge clk_sys) begin
		if (phi1_en) begin
			if (c[51])
				x <= sb;
			if (c[50])
				y <= sb;
			if (c[45])
				a <= a_next;
			if (c[49])
				s_in <= sb;
			else if (c[47])
				s_in <= s_out + 8'd1;
			else if (c[46])
				s_in <= s_out - 8'd1;
			if (c[44])
				ai <= sb;
			if (c[43])
				ai <= 8'h00;
			if (c[42])
				bi <= db;
			if (c[41])
				bi <= ~db;
			if (c[40])
				bi <= adl;
			if (c[39])
				pcls <= adl;
			else
				pcls <= pcl;
			if (c[37])
				pchs <= adh;
			else
				pchs <= pch;
			if (c[35])
				abl <= adl;
			if (c[34])
				abh <= adh;
			dor <= db;
			if (c[10])
				p_v <= 1'b1;
			if (c[2]) begin
				p_z <= db[1];
				p_i <= db[2];
				p_d <= db[3];
			end
			if (c[21])
				p_c <= db[0];
			if (c[20])
				p_c <= ir[5];
			if (c[19])
				p_c <= acr;
			if (c[18])
				p_n <= db[7];
			if (c[17])
				p_z <= db == 8'h00;
			if (c[16])
				p_i <= ir[5];
			if (c[7])
				p_i <= 1'b1;
			if (c[15])
				p_d <= ir[5];
			if (c[14])
				p_v <= db[6];
			if (c[9])
				p_c <= db[7];
			if (c[8]) begin
				p_c <= (c[23] ? arr_hi_q : db[6]);
				p_v <= db[6] ^ db[5];
			end
			if (c[13])
				p_v <= avr;
			if (c[12])
				p_v <= 1'b1;
			if (c[11])
				p_v <= 1'b0;
		end
		if (phi2_en) begin
			if (c[24]) begin
				arr_lo_q <= (ai[3:0] & bi[3:0]) >= 4'd5;
				arr_hi_q <= (ai[7:4] & bi[7:4]) >= 4'd5;
			end
			if (c[25])
				add <= 8'hff;
			else if (alu_active) begin
				add <= alu_res;
				acr <= alu_acr;
				avr <= alu_avr;
				hc_held <= alu_hc;
			end
			dl <= data_in;
			if (c[6])
				p_n <= alu_res[7];
			if (c[5])
				p_z <= alu_res == 8'h00;
			if (c[4])
				p_c <= alu_acr;
			if (c[3])
				p_v <= alu_avr;
			pcl <= pcl_next;
			pch <= pch_next;
			s_out <= (c[48] ? s_out : s_in);
		end
	end
	assign acr_now = alu_acr;
	assign s = s_out;
	assign addr_out = {abh, abl};
	assign data_out = dor;
	initial _sv2v_0 = 0;
endmodule
