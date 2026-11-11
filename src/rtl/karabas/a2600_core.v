`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_core.v

 The board independent part of the Atari 2600 core (the tops of the boards put the clocks, kg_mcu,
 the OSD, audio and HDMI / VGA around it; sim/sim_board.cpp runs it in Verilator):
 - the cartridge load stream: the ROM of the .kg (rom_*, once when the core starts) or the FL item
   (file_*, slot 0) into the SRAM (a2600_sram) and detect2600; the machine held in reset meanwhile
   and until a cartridge came;
 - the reset of the machine (areset, a load, the Reset item, F12, a new Mapper item), the TIA CE
   (a2600_ce), the controllers (a2600_hid, a2600_paddles), the console switches, atari2600_top;
 - the OSD options of Ф3: Mapper (sw_mapper: Auto or a forced one), Region (sw_region: Auto = the
   line count detection of the TIA, NTSC, PAL, SECAM: the TIA CE, the palette, the window of the
   frame buffer), Controller (sw_paddles: joysticks or paddles on the left port);
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
	input wire [3:0] sw_mapper,      // 0 Auto, 1.. the table mapper_code
	input wire [1:0] sw_region,      // 0 Auto, 1 NTSC, 2 PAL, 3 SECAM
	input wire sw_paddles,           // 0 joysticks, 1 paddles (left port)
	input wire [7:0] ms_x,
	input wire [2:0] ms_b,
	input wire ms_upd,
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
	output wire is_pal,              // the region in use (PAL or SECAM)
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

// the Mapper item: Auto or a BANK* number of detect2600 (FE, CTY, MC, 32-in-1 are not detected)
reg [5:0] mapper_code;
always @(*)
	case (sw_mapper)
		4'd1: mapper_code = 6'd3;    // FE
		4'd2: mapper_code = 6'd22;   // CTY
		4'd3: mapper_code = 6'd29;   // MC 2K
		4'd4: mapper_code = 6'd30;   // MC 4K
		4'd5: mapper_code = 6'd31;   // MC 8K
		4'd6: mapper_code = 6'd14;   // 32-in-1
		4'd7: mapper_code = 6'd4;    // E0
		4'd8: mapper_code = 6'd12;   // E7
		4'd9: mapper_code = 6'd16;   // 3E
		4'd10: mapper_code = 6'd5;   // 3F
		4'd11: mapper_code = 6'd11;  // UA
		4'd12: mapper_code = 6'd26;  // 0840
		4'd13: mapper_code = 6'd17;  // SB
		4'd14: mapper_code = 6'd18;  // WD
		4'd15: mapper_code = 6'd13;  // F0
		default: mapper_code = 6'd0; // Auto
	endcase
reg [5:0] mapper_force = 6'd0;
always @(posedge clk_sys)
	mapper_force <= mapper_code;
wire mapper_changed = mapper_force != mapper_code;

wire key_reset;
reg [7:0] rst_cnt = 8'hFF;
wire rst_req = areset || ld_active || load_end || !cart_ok || sw_reset || key_reset || mapper_changed;
always @(posedge clk_sys)
	if (rst_req)
		rst_cnt <= 8'hFF;
	else if (rst_cnt != 8'd0)
		rst_cnt <= rst_cnt - 8'd1;
assign machine_reset = rst_cnt != 8'd0;
assign ld_busy = ld_active;

// ------------------------------------------------------------------ the machine

// the region: Auto follows the line count detection of the TIA (NTSC or PAL; SECAM only by the item)
wire tia_pal;
reg region_pal = 1'b0, region_secam = 1'b0;
always @(posedge clk_sys) begin
	region_pal <= sw_region == 2'd0 ? tia_pal : sw_region[1];
	region_secam <= sw_region == 2'd3;
end
assign is_pal = region_pal;

wire tia_ce;
a2600_ce ce (
	.clk(clk_sys),
	.run(1'b1),
	.pal(region_pal),
	.ce(tia_ce)
);

wire [7:0] pa_hid;
wire [1:0] ilatch_hid;
wire sw_select_n, sw_reset_n;
wire p0_left, p0_right, p0_fire, p1_left, p1_right, p1_fire;
wire [3:0] alt_buttons;
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
	.pa_in(pa_hid),
	.ilatch(ilatch_hid),
	.p0_left_o(p0_left),
	.p0_right_o(p0_right),
	.p0_fire_o(p0_fire),
	.p1_left_o(p1_left),
	.p1_right_o(p1_right),
	.p1_fire_o(p1_fire),
	.alt_buttons(alt_buttons),
	.sw_select_n(sw_select_n),
	.sw_reset_n(sw_reset_n),
	.key_reset(key_reset)
);

// paddles on the left port (SWCHA D7 / D6 their fire, D5 / D4 unused); the right port stays a joystick
wire [3:0] tia_i_out, tia_i_read, idump;
wire pd_fire_a_n, pd_fire_b_n;
a2600_paddles paddles (
	.clk(clk_sys),
	.reset(machine_reset),
	.paddles(sw_paddles),
	.ms_x(ms_x),
	.ms_b(ms_b),
	.ms_upd(ms_upd),
	.a_left(p0_left),
	.a_right(p0_right),
	.a_fire(p0_fire),
	.b_left(p1_left),
	.b_right(p1_right),
	.b_fire(p1_fire),
	.alt_buttons(alt_buttons),
	.i_out(tia_i_out),
	.i_read(tia_i_read),
	.idump(idump),
	.fire_a_n(pd_fire_a_n),
	.fire_b_n(pd_fire_b_n)
);
wire [7:0] pa_in = sw_paddles ? { pd_fire_a_n, pd_fire_b_n, 2'b11, pa_hid[3:0] } : pa_hid;
wire [1:0] ilatch = sw_paddles ? { ilatch_hid[1], 1'b1 } : ilatch_hid;

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
	.mapper_force(mapper_force),
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
	.is_pal(tia_pal),
	.is_f1(),
	.use_stereo(1'b0),
	.audio_l(audio_l),
	.audio_r(audio_r),
	.pa_in(pa_in),
	.pa_out(),
	.pb_in(pb_in),
	.pb_out(),
	.idump(idump),
	.i_out(tia_i_out),
	.i_read(tia_i_read),
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
	.pal(region_pal),
	.secam(region_secam),
	.clk_pix(clk_pix),
	.rgb(fb_rgb),
	.hs(fb_hs),
	.vs(fb_vs),
	.de(fb_de)
);

endmodule
