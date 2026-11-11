`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_core.v

 The board independent part of the Atari 2600 core (the tops of the boards put the clocks, kg_mcu,
 the OSD, audio and HDMI / VGA around it; sim/sim_board.cpp runs it in Verilator):
 - the cartridge load stream: the ROM of the .kg (rom_*, once when the core starts) or the FL item
   (file_*, slot 0) into the SRAM (a2600_sram) and detect2600; the machine held in reset meanwhile
   and until a cartridge came;
 - the reset of the machine (areset, a load, the Reset item, F12), the TIA CE (a2600_ce), the
   controllers (a2600_hid), the console switches, atari2600_top;
 - the frame buffer (a2600_fb): the 1024 x 768 picture on clk_pix (phase aligned 2 x clk_sys).
*/
module a2600_core (
	input wire clk_sys,
	input wire clk_pix,
	input wire areset,

	input wire rom_active,
	input wire rom_wr,
	input wire [31:0] rom_addr,
	input wire [7:0] rom_data,
	input wire file_active,
	input wire file_wr,
	input wire [7:0] file_slot,
	input wire [31:0] file_addr,
	input wire [7:0] file_data,

	input wire sw_reset,
	input wire sw_bw,
	input wire sw_diff_l,
	input wire sw_diff_r,
	input wire [7:0] kb_status,
	input wire [7:0] kb_dat0,
	input wire [7:0] kb_dat1,
	input wire [7:0] kb_dat2,
	input wire [7:0] kb_dat3,
	input wire [7:0] kb_dat4,
	input wire [7:0] kb_dat5,
	input wire [12:0] joy_l,
	input wire [12:0] joy_r,

	output wire [20:0] MA,
	input wire [15:0] MD_I,
	output wire [15:0] MD_O,
	output wire [15:0] MD_OE_N,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [23:0] fb_rgb,
	output wire fb_hs,
	output wire fb_vs,
	output wire fb_de,
	output wire [15:0] audio_l,
	output wire [15:0] audio_r,

	output reg cart_ok = 1'b0,
	output wire machine_reset,
	output wire ld_busy,
	output wire is_pal,
	output wire [5:0] mapper,
	output reg [31:0] cart_size = 32'd0
);

// ------------------------------------------------------------------ the cartridge load stream

// the ROM of the .kg (rom_*, once at the start of the core) and the FL item (file_*, slot 0): one
// stream for the SRAM and detect2600; load_start / load_end at the edges of the activity
wire fl_active = file_active && file_slot == 8'd0;
wire ld_active = rom_active | fl_active;
wire ld_wr = rom_active ? rom_wr : (fl_active & file_wr);
wire [31:0] ld_addr = rom_active ? rom_addr : file_addr;
wire [7:0] ld_data = rom_active ? rom_data : file_data;

reg ld_active_d = 1'b0;
reg load_start = 1'b0, load_end = 1'b0, load_valid = 1'b0;
reg [24:0] load_addr = 25'd0;
reg [7:0] load_data = 8'd0;
always @(posedge clk_sys) begin
	ld_active_d <= ld_active;
	load_start <= ld_active && !ld_active_d;
	load_end <= !ld_active && ld_active_d;
	load_valid <= ld_wr && ld_addr[31:19] == 13'd0;
	load_addr <= ld_addr[24:0];
	load_data <= ld_data;
	if (ld_active && !ld_active_d)
		cart_size <= 32'd0;
	else if (ld_wr && ld_addr[31:19] == 13'd0 && ld_addr + 32'd1 > cart_size)
		cart_size <= ld_addr + 32'd1;
	if (load_end && cart_size != 32'd0)
		cart_ok <= 1'b1;
end

// ------------------------------------------------------------------ reset

wire key_reset;
reg [7:0] rst_cnt = 8'hFF;
wire rst_req = areset || ld_active || load_end || !cart_ok || sw_reset || key_reset;
always @(posedge clk_sys)
	if (rst_req)
		rst_cnt <= 8'hFF;
	else if (rst_cnt != 8'd0)
		rst_cnt <= rst_cnt - 8'd1;
assign machine_reset = rst_cnt != 8'd0;
assign ld_busy = ld_active;

// ------------------------------------------------------------------ the machine

wire tia_ce;
a2600_ce ce (
	.clk(clk_sys),
	.run(1'b1),
	.pal(1'b0),
	.ce(tia_ce)
);

wire [7:0] pa_in;
wire [1:0] ilatch;
wire sw_select_n, sw_reset_n;
a2600_hid hid (
	.kb_status(kb_status),
	.kb_dat0(kb_dat0),
	.kb_dat1(kb_dat1),
	.kb_dat2(kb_dat2),
	.kb_dat3(kb_dat3),
	.kb_dat4(kb_dat4),
	.kb_dat5(kb_dat5),
	.joy_l(joy_l),
	.joy_r(joy_r),
	.pa_in(pa_in),
	.ilatch(ilatch),
	.sw_select_n(sw_select_n),
	.sw_reset_n(sw_reset_n),
	.key_reset(key_reset)
);

// SWCHB: 7 P1 difficulty, 6 P0 difficulty (1 = A), 3 colour (1) / B&W (0), 1 Select, 0 Reset
wire [7:0] pb_in = { sw_diff_r, sw_diff_l, 2'b11, ~sw_bw, 1'b1, sw_select_n, sw_reset_n };

wire [18:0] cart_rom_a;
wire [7:0] cart_rom_do;
wire [17:0] cartram_addr;
wire cartram_rd, cartram_wr;
wire [7:0] cartram_wrdata, cartram_data;
wire [5:0] mapper_detected;
wire video_ce, tia_hs, tia_vs, tia_hb, tia_vb;
wire [3:0] tia_col;
wire [2:0] tia_lum;

atari2600_top machine (
	.clk(clk_sys),
	.tia_ce(tia_ce),
	.reset(machine_reset),
	.load_start(load_start),
	.load_addr(load_addr),
	.load_valid(load_valid),
	.load_data(load_data),
	.load_end(load_end),
	.cart_size(cart_size),
	.mapper_force(6'd0),
	.mapper_detected(mapper_detected),
	.mapper(mapper),
	.cart_present(1'b1),
	.rom_a(cart_rom_a),
	.rom_read(),
	.rom_do(cart_rom_do),
	.cartram_addr(cartram_addr),
	.cartram_wr(cartram_wr),
	.cartram_rd(cartram_rd),
	.cartram_wrdata(cartram_wrdata),
	.cartram_data(cartram_data),
	.video_ce(video_ce),
	.col(tia_col),
	.lum(tia_lum),
	.hsync(tia_hs),
	.vsync(tia_vs),
	.hblank(tia_hb),
	.vblank(tia_vb),
	.stabilize(1'b0),
	.decomb(1'b0),
	.is_pal(is_pal),
	.is_f1(),
	.use_stereo(1'b0),
	.audio_l(audio_l),
	.audio_r(audio_r),
	.pa_in(pa_in),
	.pa_out(),
	.pb_in(pb_in),
	.pb_out(),
	.idump(4'h0),
	.i_out(),
	.i_read(),
	.ilatch(ilatch),
	.tape_in(2'b00),
	.fix_sc_cs(1'b0)
);

a2600_sram sram (
	.clk(clk_sys),
	.ld_wr(load_valid),
	.ld_addr(load_addr[18:0]),
	.ld_data(load_data),
	.rom_a(cart_rom_a),
	.rom_do(cart_rom_do),
	.cartram_addr(cartram_addr),
	.cartram_rd(cartram_rd),
	.cartram_wr(cartram_wr),
	.cartram_wrdata(cartram_wrdata),
	.cartram_data(cartram_data),
	.MA(MA),
	.MD_I(MD_I),
	.MD_O(MD_O),
	.MD_OE_N(MD_OE_N),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

// ------------------------------------------------------------------ video

a2600_fb fb (
	.clk_sys(clk_sys),
	.video_ce(video_ce),
	.col(tia_col),
	.lum(tia_lum),
	.hsync_i(tia_hs),
	.vsync_i(tia_vs),
	.blank_i(tia_hb | tia_vb),
	.clk_pix(clk_pix),
	.rgb(fb_rgb),
	.hs(fb_hs),
	.vs(fb_vs),
	.de(fb_de)
);

endmodule
