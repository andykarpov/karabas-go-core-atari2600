`timescale 1ns / 1ps
`default_nettype wire

/*
 Atari 2600 VCS core for Karabas Mini rev.G (HDMI, PCM5102): atari2600_top (the 2600 part of k7800
 through sv2v, rtl/karabas) with the karabas parts and the board glue of karabas-go-modules.

 Clocks (a2600_clocks): one PLL on CLK_50MHZ (VCO 650 MHz): clk_hdmi / clk_hdmi_n 325 MHz (the HDMI
 serialiser), clk_pix 65 MHz (1024 x 768 at 60 Hz), clk_sys 32.5 MHz (the machine with the TIA CE
 63 / 286 = 7.159 MHz, the MCU link, the SRAM, audio), clk_8 8.02 MHz (FT_CLK_OUT). clk_pix and
 clk_sys are phase aligned: the paths between them are timed (frame buffer, OSD).

 Cartridge: in the SRAM (a2600_sram: ROM at 0, RAM at 1 MB). It comes from the FL item Cartridge
 (slot 0) or, when the core starts, from the ROM of the .kg (roms/: the default cartridge, a free
 homebrew); both as the load stream of detect2600 (mapper autodetect), the machine held in reset.

 Video: the TIA picture into the frame buffer (a2600_fb, 160 x 240), out as 1024 x 768 (x6 / x3,
 960 x 720 in the middle) with the OSD. Audio: the TIA mix (k7800 table) to the PCM5102 and HDMI.

 Controllers (a2600_hid, a2600_paddles): USB pads (left = P0, right = P1; B / C = Fire 2 / 3, the
 Booster Grip), the keyboard arrows + Space / Left Ctrl (P0, Left Alt = Fire 2), F1 Select, F2 Game
 Reset, F12 reset of the machine; paddles (Controller item): the mouse and the pads.

 Soft switches (the index of the item in the osd of core.json, file items included):
   0 Cartridge (FL 0)   1 Reset   2 TV Type (0 Color, 1 B&W)   3 Left Difficulty (0 B, 1 A)
   4 Right Difficulty (0 B, 1 A)   5 Mapper (0 Auto, 1.. see a2600_core)
   6 Region (0 Auto, 1 NTSC, 2 PAL, 3 SECAM)   7 Controller (0 Joystick, 1 Paddles)
*/

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;

assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;
assign MIDI_TX = 1'b1;

// the SDRAM is not used: no clock, deselected by its commands (NOP: RAS / CAS / WE high)
assign SDR_A = 13'd0;
assign SDR_BA = 2'b00;
assign SDR_CLK = 1'b0;
assign SDR_DQM = 2'b11;
assign SDR_WE_N = 1'b1;
assign SDR_CAS_N = 1'b1;
assign SDR_RAS_N = 1'b1;
assign SDR_DQ = 16'bz;

// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board): always selected
assign FLASH_CS_N = 1'b0;
assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_pix, clk_hdmi, clk_hdmi_n, clk_sys, clk_8, pll_locked;
a2600_clocks clocks (
	.clk_in(CLK_50MHZ),
	.clk_pix(clk_pix),
	.clk_hdmi(clk_hdmi),
	.clk_hdmi_n(clk_hdmi_n),
	.clk_sys(clk_sys),
	.clk_8(clk_8),
	.locked(pll_locked)
);
(* KEEP = "TRUE" *) wire areset_async = ~pll_locked;
// the reset in each clock: synchronised (the locked flag of the PLL is not of these clocks; the ucf takes
// the path into the first stage out of the timing)
wire areset, areset_pix;
kg_sync #(.W(1), .STAGES(2), .INIT(1'b1)) sync_areset (.clk(clk_sys), .d(areset_async), .q(areset));
kg_sync #(.W(1), .STAGES(2), .INIT(1'b1)) sync_areset_pix (.clk(clk_pix), .d(areset_async), .q(areset_pix));

// the clock of the FT812
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

// karabas: MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [15:0] joy_l16, joy_r16;
wire [12:0] joy_l = joy_l16[12:0], joy_r = joy_r16[12:0];
wire [7:0] ms_x, ms_b8;
wire [2:0] ms_b = ms_b8[2:0];
wire ms_wr;
// the mouse report as the toggle of v1 (a2600_paddles takes a change of it; MS_WR of link v2 is a pulse)
reg ms_upd = 1'b0;
always @(posedge clk_sys)
	if (ms_wr)
		ms_upd <= ~ms_upd;
wire [1:0] ld_kind;
wire [7:0] ld_slot, ld_data;
wire [31:0] ld_addr;
wire ld_active, ld_wr;
wire [8*8-1:0] sw;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [15:0] dbg_addr;
reg [15:0] dbg_data = 16'd0;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

kg_mcu2 #(
	.SW_N(8),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(0),
	.ENABLE_AUX(1),      // DEBUG_*: the state of the core (AT+KARABAS=debug:1, kg_board.py log)
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_sys),
	.N_RESET(~areset),

	.MCU_SCK(mcu_sck),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(mcu_busy), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD({ kb_dat5, kb_dat4, kb_dat3, kb_dat2, kb_dat1, kb_dat0, kb_status }), .KBD_WR(),
	.PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(ms_x), .MS_Y(), .MS_Z(), .MS_B(ms_b8), .MS_WR(ms_wr),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(ld_kind), .LD_SLOT(ld_slot), .LD_SIZE(), .LD_START(), .LD_ACTIVE(ld_active), .LD_END(),
	.LD_ADDR(ld_addr), .LD_DATA(ld_data), .LD_WR(ld_wr), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

	.SDC_IMG_MOUNTED(), .SDC_IMG_SIZE(), .SDC_RD(8'd0), .SDC_WR(8'd0), .SDC_SECTOR(32'd0), .SDC_BUSY(),
	.SDC_DONE(), .SDC_ERROR(), .SDC_SLOT(), .SDC_BYTE_IN_STROBE(), .SDC_BYTE_ADDR(), .SDC_BYTE_IN_DATA(),
	.SDC_BYTE_OUT_DATA(8'd0), .IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0), .IMG_ACTIVE(),
	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(8'd0), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .MATRIX_CMD(24'd0), .MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(dbg_addr), .DEBUG_DATA(dbg_data), .RTC_DO(),

	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(ft_mosi), .FT_MISO(FT_SPI_MISO),
	.FT_CS_N(ft_cs_n),
	.SD2_SCK(), .SD2_MOSI(sd2_mosi), .SD2_MISO(SD_DO), .SD2_CS_N(sd2_cs_n)
);

// the loads of link v2: the roms of the core file (LD kind 0) and the FL items (kind 2) on the
// rom / file signals of a2600_core
wire rom_active = ld_active && ld_kind == 2'd0;
wire rom_wr = ld_wr && ld_kind == 2'd0;
wire [31:0] rom_addr = ld_addr;
wire [7:0] rom_data = ld_data;
wire file_active = ld_active && ld_kind == 2'd2;
wire file_wr = ld_wr && ld_kind == 2'd2;
wire [7:0] file_slot = ld_slot, file_data = ld_data;
wire [31:0] file_addr = ld_addr;

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches

// the switches: the SW registers of kg_mcu2 (index = the "index" of core.json)
wire sw_reset = sw[1*8];
wire sw_bw = sw[2*8];
wire sw_diff_l = sw[3*8];
wire sw_diff_r = sw[4*8];
wire [3:0] sw_mapper = sw[5*8 +: 4];
wire [1:0] sw_region = sw[6*8 +: 2];
wire sw_paddles = sw[7*8];

// ------------------------------------------------------------------ the core (a2600_core)

wire [23:0] fb_rgb;
wire fb_hs, fb_vs, fb_de;
wire [15:0] audio_l, audio_r;
wire [15:0] sram_md_o, sram_md_oe_n;
wire cart_ok, machine_reset, ld_busy, is_pal;
wire [5:0] mapper;
wire [31:0] cart_size;

a2600_core core (
	.clk_sys(clk_sys),
	.clk_pix(clk_pix),
	.areset(areset),
	.rom_active(rom_active),
	.rom_wr(rom_wr),
	.rom_addr(rom_addr),
	.rom_data(rom_data),
	.file_active(file_active),
	.file_wr(file_wr),
	.file_slot(file_slot),
	.file_addr(file_addr),
	.file_data(file_data),
	.sw_reset(sw_reset),
	.sw_bw(sw_bw),
	.sw_diff_l(sw_diff_l),
	.sw_diff_r(sw_diff_r),
	.sw_mapper(sw_mapper),
	.sw_region(sw_region),
	.sw_paddles(sw_paddles),
	.ms_x(ms_x),
	.ms_b(ms_b),
	.ms_upd(ms_upd),
	.kb_status(kb_status),
	.kb_dat0(kb_dat0),
	.kb_dat1(kb_dat1),
	.kb_dat2(kb_dat2),
	.kb_dat3(kb_dat3),
	.kb_dat4(kb_dat4),
	.kb_dat5(kb_dat5),
	.joy_l(joy_l),
	.joy_r(joy_r),
	.MA(MA),
	.MD_I(MD),
	.MD_O(sram_md_o),
	.MD_OE_N(sram_md_oe_n),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N),
	.fb_rgb(fb_rgb),
	.fb_hs(fb_hs),
	.fb_vs(fb_vs),
	.fb_de(fb_de),
	.audio_l(audio_l),
	.audio_r(audio_r),
	.cart_ok(cart_ok),
	.machine_reset(machine_reset),
	.ld_busy(ld_busy),
	.is_pal(is_pal),
	.mapper(mapper),
	.cart_size(cart_size)
);

genvar md_i;
generate
	for (md_i = 0; md_i < 16; md_i = md_i + 1) begin : md_pins
		assign MD[md_i] = sram_md_oe_n[md_i] ? 1'bz : sram_md_o[md_i];
	end
endgenerate

// the bitmap OSD of link v2 (kg_l2_osd_overlay): centred in de, the scale from its size,
// 2 clocks of latency with its syncs and de
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(clk_sys),
	.osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.icon_on(8'd0), .icon_act(8'd0),
	.clk(clk_pix),
	.rgb_i(fb_rgb), .hs_i(fb_hs), .vs_i(fb_vs), .de_i(fb_de),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
);

// ------------------------------------------------------------------ audio

// the TIA mix is unsigned (0 .. 7FFF): as a positive two's complement value
kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 4.06 MHz, 127 kHz
	.clk(clk_sys),
	.reset(areset),
	.left(audio_l),
	.right(audio_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// 48 kHz for hdmi_tx on clk_pix: + 48 per clock of 65 MHz, modulo 65000 (exact)
reg [16:0] aud_acc = 17'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_pix) begin
	aud_stb <= 1'b0;
	if (aud_acc >= 17'd65000 - 17'd48) begin
		aud_acc <= aud_acc + 17'd48 - 17'd65000;
		aud_stb <= 1'b1;
		hdmi_l <= { audio_l, 8'd0 };
		hdmi_r <= { audio_r, 8'd0 };
	end
	else
		aud_acc <= aud_acc + 17'd48;
end

// ------------------------------------------------------------------ HDMI

reg dvi_only_p = 1'b0;
always @(posedge clk_pix)
	dvi_only_p <= dvi_only;

// 1024 x 768 at 60 Hz: negative syncs (VESA)
reg hdmi_hs = 1'b1, hdmi_vs = 1'b1, hdmi_de = 1'b0;
reg [23:0] hdmi_rgb = 24'd0;
always @(posedge clk_pix) begin
	hdmi_hs <= ~osd_hs;
	hdmi_vs <= ~osd_vs;
	hdmi_de <= osd_de;
	hdmi_rgb <= osd_rgb;
end

hdmi_tx #(.SAMPLE_FREQ(48000)) hdmi (
	.clk(clk_pix),
	.sclk(clk_hdmi),
	.sclk_n(clk_hdmi_n),
	.reset(areset_pix),
	.rgb(hdmi_rgb),
	.vsync(hdmi_vs),
	.hsync(hdmi_hs),
	.de(hdmi_de),
	.audio_en(~dvi_only_p),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

// ------------------------------------------------------------------ debug

// DEBUG_ADDR: { cart_ok, machine_reset, loading, is_pal, 6'd0, mapper }
// DEBUG_DATA: the size of the last cartridge / 16 (bytes, up to 1 MB)
assign dbg_addr = { cart_ok, machine_reset, ld_busy, is_pal, 6'd0, mapper };
always @(posedge clk_sys)
	dbg_data <= cart_size[19:4];

endmodule
