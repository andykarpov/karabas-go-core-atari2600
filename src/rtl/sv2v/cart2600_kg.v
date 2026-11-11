module cart2600_kg (
	d_out,
	d_in,
	a_in,
	rw,
	clk,
	reset,
	ce,
	phi1,
	phi2,
	oe,
	sc,
	mapper,
	mapper_revision,
	rom_do,
	rom_size,
	load_start,
	rom_a,
	rom_read,
	cartram_addr,
	cartram_wr,
	cartram_rd,
	cartram_wrdata,
	cartram_data,
	tape_audio,
	tape_in,
	fix_sc_cs
);
	reg _sv2v_0;
	output reg [7:0] d_out;
	input [7:0] d_in;
	input [12:0] a_in;
	input rw;
	input clk;
	input reset;
	input ce;
	input phi1;
	input phi2;
	output reg [7:0] oe;
	input sc;
	input [5:0] mapper;
	input [2:0] mapper_revision;
	input [7:0] rom_do;
	input [31:0] rom_size;
	input load_start;
	output wire [18:0] rom_a;
	output wire rom_read;
	output wire [17:0] cartram_addr;
	output wire cartram_wr;
	output wire cartram_rd;
	output wire [7:0] cartram_wrdata;
	input [7:0] cartram_data;
	output wire tape_audio;
	input [1:0] tape_in;
	input fix_sc_cs;
	wire [18:0] rom_addr [0:6'd33 - 1];
	wire [7:0] direct_do [0:6'd33 - 1];
	wire [15:0] flags_out [0:6'd33 - 1];
	wire [7:0] out_en [0:6'd33 - 1];
	wire ram_rw [0:6'd33 - 1];
	wire ram_sel [0:6'd33 - 1];
	wire [17:0] ram_a [0:6'd33 - 1];
	reg [12:0] old_ain;
	wire [7:0] bg_data;
	wire ar_read;
	wire [7:0] cr_do;
	wire [18:0] sel_rom_addr;
	wire [7:0] sel_direct_do;
	wire [15:0] sel_flags_out;
	wire [7:0] sel_out_en;
	wire sel_ram_rw;
	wire sel_ram_sel;
	wire [17:0] sel_ram_a;
	wire [18:0] rom_mask;
	assign rom_mask = rom_size[18:0] - 1'd1;
	wire address_change = old_ain != a_in;
	assign rom_read = (mapper == 6'd15 ? ar_read : ~address_change);
	wire is_bad_game = (((mapper == 6'd32) || (mapper == 6'd24)) || (mapper == 6'd21)) || (mapper == 6'd23);
	spram #(
		.addr_width(11),
		.mem_init_file("ooo.mif"),
		.sim_init_file("rtl/k7800/ooo.hex")
	) badgame_ram(
		.clock(clk),
		.address(a_in[10:0]),
		.data(8'd0),
		.wren(1'b0),
		.cs(1'b1),
		.q(bg_data)
	);
	assign sel_flags_out = flags_out[mapper];
	assign sel_direct_do = direct_do[mapper];
	assign sel_out_en = out_en[mapper];
	assign sel_ram_rw = ram_rw[mapper];
	assign sel_ram_sel = ram_sel[mapper];
	assign sel_ram_a = ram_a[mapper];
	assign rom_a = rom_addr[mapper] & ((((((mapper == 6'd12) || (mapper == 6'd5)) || (mapper == 6'd17)) || (mapper == 6'd16)) || (mapper == 6'd27)) || (mapper == 6'd28) ? rom_mask : {19 {1'b1}});
	always @(*) begin
		if (_sv2v_0)
			;
		d_out = 8'h00;
		oe = 8'h00;
		if (is_bad_game) begin
			d_out = bg_data;
			oe = 8'hff;
		end
		else if (|sel_out_en) begin
			if (sel_flags_out[0]) begin
				d_out = sel_direct_do;
				oe = sel_out_en;
			end
			else if (sel_flags_out[1]) begin
				d_out = sel_direct_do & rom_do;
				oe = sel_out_en;
			end
			else if (sel_ram_sel) begin
				if (sel_ram_rw) begin
					d_out = cr_do;
					oe = sel_out_en;
				end
			end
			else begin
				d_out = rom_do;
				oe = sel_out_en;
			end
		end
	end
	reg access_taken;
	always @(posedge clk)
		if ((reset || address_change) || phi1)
			access_taken <= 1'b0;
		else if (phi2)
			access_taken <= 1'b1;
	always @(posedge clk) begin : reset_2600_cart
		old_ain <= a_in;
	end
	mapper_CTY mapper_CTY(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd22]),
		.flags_out(flags_out[6'd22]),
		.oe(out_en[6'd22]),
		.ram_sel(ram_sel[6'd22]),
		.ram_rw(ram_rw[6'd22]),
		.ram_a(ram_a[6'd22]),
		.rom_a(rom_addr[6'd22]),
		.ce(ce),
		.rom_do(rom_do)
	);
	wire fa2_nvram_request_raw;
	wire fa2_nvram_write_raw;
	wire fa2_nvram_dirty_raw;
	wire [7:0] fa2_nvram_addr_raw;
	wire [7:0] fa2_nvram_wdata_raw;
	wire [7:0] fa2_nvram_rdata = 8'hff;
	wire fa2_nvram_ready = 1'b1;
	assign direct_do[6'd32] = bg_data;
	assign flags_out[6'd32] = 16'd1;
	assign out_en[6'd32] = 8'hff;
	assign ram_sel[6'd32] = 0;
	assign ram_rw[6'd32] = 1;
	assign ram_a[6'd32] = 1'sb0;
	assign rom_addr[6'd32] = 1'sb0;
	assign direct_do[6'd21] = bg_data;
	assign flags_out[6'd21] = 16'd1;
	assign out_en[6'd21] = 8'hff;
	assign ram_sel[6'd21] = 0;
	assign ram_rw[6'd21] = 1;
	assign ram_a[6'd21] = 1'sb0;
	assign rom_addr[6'd21] = 1'sb0;
	assign direct_do[6'd23] = bg_data;
	assign flags_out[6'd23] = 16'd1;
	assign out_en[6'd23] = 8'hff;
	assign ram_sel[6'd23] = 0;
	assign ram_rw[6'd23] = 1;
	assign ram_a[6'd23] = 1'sb0;
	assign rom_addr[6'd23] = 1'sb0;
	assign direct_do[6'd24] = bg_data;
	assign flags_out[6'd24] = 16'd1;
	assign out_en[6'd24] = 8'hff;
	assign ram_sel[6'd24] = 0;
	assign ram_rw[6'd24] = 1;
	assign ram_a[6'd24] = 1'sb0;
	assign rom_addr[6'd24] = 1'sb0;
	assign cartram_addr = sel_ram_a;
	assign cartram_wr = (((sel_ram_sel && ~sel_ram_rw) && ~phi1) && ~address_change) && ~access_taken;
	assign cartram_rd = ((sel_ram_sel && sel_ram_rw) && ~phi1) && ~address_change;
	assign cartram_wrdata = d_in;
	assign cr_do = cartram_data;
	mapper_none mapper_none(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd0]),
		.flags_out(flags_out[6'd0]),
		.oe(out_en[6'd0]),
		.ram_sel(ram_sel[6'd0]),
		.ram_rw(ram_rw[6'd0]),
		.ram_a(ram_a[6'd0]),
		.rom_a(rom_addr[6'd0])
	);
	mapper_F8 mapper_F8(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd1]),
		.flags_out(flags_out[6'd1]),
		.oe(out_en[6'd1]),
		.ram_sel(ram_sel[6'd1]),
		.ram_rw(ram_rw[6'd1]),
		.ram_a(ram_a[6'd1]),
		.rom_a(rom_addr[6'd1])
	);
	mapper_F6 mapper_F6(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd2]),
		.flags_out(flags_out[6'd2]),
		.oe(out_en[6'd2]),
		.ram_sel(ram_sel[6'd2]),
		.ram_rw(ram_rw[6'd2]),
		.ram_a(ram_a[6'd2]),
		.rom_a(rom_addr[6'd2])
	);
	mapper_FE mapper_FE(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd3]),
		.flags_out(flags_out[6'd3]),
		.oe(out_en[6'd3]),
		.ram_sel(ram_sel[6'd3]),
		.ram_rw(ram_rw[6'd3]),
		.ram_a(ram_a[6'd3]),
		.rom_a(rom_addr[6'd3]),
		.ce(phi1)
	);
	mapper_E0 mapper_E0(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd4]),
		.flags_out(flags_out[6'd4]),
		.oe(out_en[6'd4]),
		.ram_sel(ram_sel[6'd4]),
		.ram_rw(ram_rw[6'd4]),
		.ram_a(ram_a[6'd4]),
		.rom_a(rom_addr[6'd4])
	);
	mapper_3F mapper_3F(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd5]),
		.flags_out(flags_out[6'd5]),
		.oe(out_en[6'd5]),
		.ram_sel(ram_sel[6'd5]),
		.ram_rw(ram_rw[6'd5]),
		.ram_a(ram_a[6'd5]),
		.rom_a(rom_addr[6'd5])
	);
	mapper_F4 mapper_F4(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd6]),
		.flags_out(flags_out[6'd6]),
		.oe(out_en[6'd6]),
		.ram_sel(ram_sel[6'd6]),
		.ram_rw(ram_rw[6'd6]),
		.ram_a(ram_a[6'd6]),
		.rom_a(rom_addr[6'd6])
	);
	mapper_P2 mapper_P2(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd7]),
		.flags_out(flags_out[6'd7]),
		.oe(out_en[6'd7]),
		.ram_sel(ram_sel[6'd7]),
		.ram_rw(ram_rw[6'd7]),
		.ram_a(ram_a[6'd7]),
		.rom_a(rom_addr[6'd7]),
		.ce(ce)
	);
	mapper_FA mapper_FA(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd8]),
		.flags_out(flags_out[6'd8]),
		.oe(out_en[6'd8]),
		.ram_sel(ram_sel[6'd8]),
		.ram_rw(ram_rw[6'd8]),
		.ram_a(ram_a[6'd8]),
		.rom_a(rom_addr[6'd8])
	);
	mapper_fa2 mapper_FA2(
		.clk(clk),
		.reset(reset || (mapper != 6'd25)),
		.ce(ce),
		.phi1(phi1),
		.a_change(address_change),
		.a_in(a_in),
		.d_in(d_in),
		.rom_data(rom_do),
		.rom_size(rom_size),
		.d_out(direct_do[6'd25]),
		.flags_out(flags_out[6'd25]),
		.oe(out_en[6'd25]),
		.rom_a(rom_addr[6'd25]),
		.nvram_request(fa2_nvram_request_raw),
		.nvram_write(fa2_nvram_write_raw),
		.nvram_addr(fa2_nvram_addr_raw),
		.nvram_wdata(fa2_nvram_wdata_raw),
		.nvram_rdata(fa2_nvram_rdata),
		.nvram_ready(fa2_nvram_ready),
		.nvram_dirty(fa2_nvram_dirty_raw)
	);
	assign ram_sel[6'd25] = 1'b0;
	assign ram_rw[6'd25] = 1'b1;
	assign ram_a[6'd25] = 18'd0;
	mapper_CV mapper_CV(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd9]),
		.flags_out(flags_out[6'd9]),
		.oe(out_en[6'd9]),
		.ram_sel(ram_sel[6'd9]),
		.ram_rw(ram_rw[6'd9]),
		.ram_a(ram_a[6'd9]),
		.rom_a(rom_addr[6'd9])
	);
	mapper_2K mapper_2K(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd10]),
		.flags_out(flags_out[6'd10]),
		.oe(out_en[6'd10]),
		.ram_sel(ram_sel[6'd10]),
		.ram_rw(ram_rw[6'd10]),
		.ram_a(ram_a[6'd10]),
		.rom_a(rom_addr[6'd10])
	);
	mapper_UA mapper_UA(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd11]),
		.flags_out(flags_out[6'd11]),
		.oe(out_en[6'd11]),
		.ram_sel(ram_sel[6'd11]),
		.ram_rw(ram_rw[6'd11]),
		.ram_a(ram_a[6'd11]),
		.rom_a(rom_addr[6'd11]),
		.swapped(mapper_revision[0])
	);
	mapper_E7 mapper_E7(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd12]),
		.flags_out(flags_out[6'd12]),
		.oe(out_en[6'd12]),
		.ram_sel(ram_sel[6'd12]),
		.ram_rw(ram_rw[6'd12]),
		.ram_a(ram_a[6'd12]),
		.rom_a(rom_addr[6'd12])
	);
	mapper_F0 mapper_F0(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd13]),
		.flags_out(flags_out[6'd13]),
		.oe(out_en[6'd13]),
		.ram_sel(ram_sel[6'd13]),
		.ram_rw(ram_rw[6'd13]),
		.ram_a(ram_a[6'd13]),
		.rom_a(rom_addr[6'd13])
	);
	mapper_32 mapper_32(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd14]),
		.flags_out(flags_out[6'd14]),
		.oe(out_en[6'd14]),
		.ram_sel(ram_sel[6'd14]),
		.ram_rw(ram_rw[6'd14]),
		.ram_a(ram_a[6'd14]),
		.rom_a(rom_addr[6'd14]),
		.cold_reset((mapper != 6'd14) || load_start)
	);
	mapper_AR mapper_AR(
		.clk(clk),
		.reset(reset || (mapper != 6'd15)),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd15]),
		.flags_out(flags_out[6'd15]),
		.oe(out_en[6'd15]),
		.ram_sel(ram_sel[6'd15]),
		.ram_rw(ram_rw[6'd15]),
		.ram_a(ram_a[6'd15]),
		.rom_a(rom_addr[6'd15]),
		.ce(ce),
		.ar_read(ar_read),
		.rom_do(rom_do),
		.rom_size(rom_size[18:0]),
		.audio_data(tape_audio),
		.tape_in(tape_in),
		.fix_sc_cs(fix_sc_cs)
	);
	mapper_WD mapper_WD(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd18]),
		.flags_out(flags_out[6'd18]),
		.oe(out_en[6'd18]),
		.ram_sel(ram_sel[6'd18]),
		.ram_rw(ram_rw[6'd18]),
		.ram_a(ram_a[6'd18]),
		.rom_a(rom_addr[6'd18]),
		.swapped(mapper_revision[0])
	);
	mapper_3E mapper_3E(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd16]),
		.flags_out(flags_out[6'd16]),
		.oe(out_en[6'd16]),
		.ram_sel(ram_sel[6'd16]),
		.ram_rw(ram_rw[6'd16]),
		.ram_a(ram_a[6'd16]),
		.rom_a(rom_addr[6'd16]),
		.rom_size(rom_size[18:0])
	);
	mapper_SB mapper_SB(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd17]),
		.flags_out(flags_out[6'd17]),
		.oe(out_en[6'd17]),
		.ram_sel(ram_sel[6'd17]),
		.ram_rw(ram_rw[6'd17]),
		.ram_a(ram_a[6'd17]),
		.rom_a(rom_addr[6'd17])
	);
	mapper_EF mapper_EF(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd19]),
		.flags_out(flags_out[6'd19]),
		.oe(out_en[6'd19]),
		.ram_sel(ram_sel[6'd19]),
		.ram_rw(ram_rw[6'd19]),
		.ram_a(ram_a[6'd19]),
		.rom_a(rom_addr[6'd19])
	);
	mapper_0840 mapper_0840(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd26]),
		.flags_out(flags_out[6'd26]),
		.oe(out_en[6'd26]),
		.ram_sel(ram_sel[6'd26]),
		.ram_rw(ram_rw[6'd26]),
		.ram_a(ram_a[6'd26]),
		.rom_a(rom_addr[6'd26])
	);
	mapper_FC mapper_FC(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd27]),
		.flags_out(flags_out[6'd27]),
		.oe(out_en[6'd27]),
		.ram_sel(ram_sel[6'd27]),
		.ram_rw(ram_rw[6'd27]),
		.ram_a(ram_a[6'd27]),
		.rom_a(rom_addr[6'd27]),
		.rom_size(rom_size)
	);
	mapper_DF mapper_DF(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd28]),
		.flags_out(flags_out[6'd28]),
		.oe(out_en[6'd28]),
		.ram_sel(ram_sel[6'd28]),
		.ram_rw(ram_rw[6'd28]),
		.ram_a(ram_a[6'd28]),
		.rom_a(rom_addr[6'd28]),
		.big(rom_size[18])
	);
	mapper_MC #(.SLICE(0)) mapper_MC_MC2K(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd29]),
		.flags_out(flags_out[6'd29]),
		.oe(out_en[6'd29]),
		.ram_sel(ram_sel[6'd29]),
		.ram_rw(ram_rw[6'd29]),
		.ram_a(ram_a[6'd29]),
		.rom_a(rom_addr[6'd29]),
		.load_start(load_start),
		.rom_size(rom_size)
	);
	mapper_MC #(.SLICE(1)) mapper_MC_MC4K(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd30]),
		.flags_out(flags_out[6'd30]),
		.oe(out_en[6'd30]),
		.ram_sel(ram_sel[6'd30]),
		.ram_rw(ram_rw[6'd30]),
		.ram_a(ram_a[6'd30]),
		.rom_a(rom_addr[6'd30]),
		.load_start(load_start),
		.rom_size(rom_size)
	);
	mapper_MC #(.SLICE(2)) mapper_MC_MC8K(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd31]),
		.flags_out(flags_out[6'd31]),
		.oe(out_en[6'd31]),
		.ram_sel(ram_sel[6'd31]),
		.ram_rw(ram_rw[6'd31]),
		.ram_a(ram_a[6'd31]),
		.rom_a(rom_addr[6'd31]),
		.load_start(load_start),
		.rom_size(rom_size)
	);
	mapper_JANE mapper_JANE(
		.clk(clk),
		.reset(reset),
		.a_change(address_change),
		.sc(sc),
		.a_in(a_in),
		.d_in(d_in),
		.d_out(direct_do[6'd20]),
		.flags_out(flags_out[6'd20]),
		.oe(out_en[6'd20]),
		.ram_sel(ram_sel[6'd20]),
		.ram_rw(ram_rw[6'd20]),
		.ram_a(ram_a[6'd20]),
		.rom_a(rom_addr[6'd20])
	);
	initial _sv2v_0 = 0;
endmodule
