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

wire mcu_burst_ready;
assign MCU_IO[1] = mcu_burst_ready;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [12:0] joy_l, joy_r;
wire rom_active, rom_wr;
wire [31:0] rom_addr;
wire [7:0] rom_data;
wire file_active, file_wr;
wire [7:0] file_slot, file_data;
wire [31:0] file_addr;
wire [7:0] ms_x;
wire [2:0] ms_b;
wire ms_upd;
wire [15:0] softsw_command, osd_command;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [15:0] dbg_addr;
reg [15:0] dbg_data = 16'd0;

kg_mcu #(
	.BURST_MAX_MHZ(16),
	.CS_FILTER(3),
	.ENABLE_RTC(0),
	.ENABLE_UART(0),
	.ENABLE_MATRIX(0),
	.ENABLE_DEBUG(1),    // the state of the core (AT+KARABAS=debug:1, kg_board.py log)
	.ENABLE_IMG(0),
	.ENABLE_MIDI(0),
	.ENABLE_FILE(1),
	.FILE_CMDS(0),       // the ioctl commands of the FL items
	.FILE_WR_EACH(1),
	.FILE_TO_ROM(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_sys),
	.N_RESET(~areset),

	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SCK(mcu_sck),
	.MCU_SS(MCU_CS_N),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(MCU_IO[2]),
	.MCU_BURST_CS_N(MCU_IO[0]),
	.MCU_BURST_READY(mcu_burst_ready),

	.KB_STATUS(kb_status),
	.KB_DAT0(kb_dat0),
	.KB_DAT1(kb_dat1),
	.KB_DAT2(kb_dat2),
	.KB_DAT3(kb_dat3),
	.KB_DAT4(kb_dat4),
	.KB_DAT5(kb_dat5),
	.KB_SCANCODE(),
	.KB_SCANCODE_UPD(),
	.JOY_L(joy_l),
	.JOY_R(joy_r),
	.MS_X(ms_x),
	.MS_Y(),
	.MS_Z(),
	.MS_B(ms_b),
	.MS_UPD(ms_upd),

	.ROMLOADER_ACTIVE(rom_active),
	.ROMLOAD_ADDR(rom_addr),
	.ROMLOAD_DATA(rom_data),
	.ROMLOAD_WR(rom_wr),

	.FILELOAD_ACTIVE(file_active),
	.FILELOAD_ADDR(file_addr),
	.FILELOAD_DATA(file_data),
	.FILELOAD_WR(file_wr),
	.FILELOAD_SLOT(file_slot),

	.SOFTSW_COMMAND(softsw_command),
	.OSD_COMMAND(osd_command),
	.BUSY(mcu_busy),

	.FT_SPI_ON(ft_spi_on),
	.FT_CS_N(ft_cs_n),
	.FT_MOSI(ft_mosi),
	.FT_MISO(FT_SPI_MISO),
	.FT_SCK(),
	.SD2_CS_N(sd2_cs_n),
	.SD2_MOSI(sd2_mosi),
	.SD2_MISO(SD_DO),
	.SD2_SCK(),

	.DVI_ONLY(dvi_only),

	.MIDI_DATA(),
	.MIDI_WR(),
	.MIDI_LOST(),

	.PS2_COMMAND(16'h0000),
	.PS2_COMMAND_WR(1'b0),
	.RTC_A(8'h00),
	.RTC_DI(8'h00),
	.RTC_DO(),
	.RTC_CS(1'b0),
	.RTC_WR_N(1'b1),
	.UART_RX_DATA(),
	.UART_RX_IDX(),
	.UART_TX_DATA(8'h00),
	.UART_TX_WR(1'b0),
	.UART_TX_MODE(1'b0),
	.UART_DLM(8'h00),
	.UART_DLL(8'h00),
	.UART_DLM_WR(1'b0),
	.UART_DLL_WR(1'b0),
	.MATRIX_CMD(24'h000000),
	.MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(dbg_addr),
	.DEBUG_DATA(dbg_data),
	.IMG_MOUNTED(),
	.IMG_SIZE(),
	.IMG_WP(),
	.IMG_DATA_WR(),
	.IMG_DATA_ADDR(),
	.IMG_DATA(),
	.IMG_RESULT_WR(),
	.IMG_RESULT(),
	.IMG_SUM(),
	.IMG_Q_WR(1'b0),
	.IMG_Q_DI(24'h000000),
	.IMG_Q_ACK(),
	.ESP_UART_RX_DATA(8'h00),
	.ESP_UART_RX_WR(1'b0),
	.FLASHBOOT_START(1'b0),
	.FLASHBOOT_COREID(5'd0),
	.FDD_CHNG_REQ(1'b0),
	.FDD_CHNG_DS(2'b00),
	.PRN_DATA(8'h00),
	.PRN_WR(1'b0)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches

wire [8*8-1:0] sw;
kg_soft_switches #(.N(8)) soft_switches (
	.clk(clk_sys),
	.command(softsw_command),
	.regs(sw),
	.upd()
);
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

// the OSD of the mcu on the 1024 x 768 output (as core-macplus): a line of 1344 clocks under H_DIV4_WIDTH =
// a step per 2 (512 wide), 806 lines under V_DIV4_HEIGHT = a step per 2 (416 high); the counters start at
// the hsync / vsync leading edge, the picture 296 clocks / 35 lines later: centred at (296 + 256) / 2 = 276,
// (35 + 176) / 2 = 105
reg [15:0] osd_cmd = 16'd0;
always @(posedge clk_pix)
	osd_cmd <= osd_command;
wire [23:0] osd_rgb;
kg_osd_overlay #(.H_OFFSET(276), .V_OFFSET(105), .H_DIV4_WIDTH(1400), .V_DIV4_HEIGHT(900)) osd (
	.clk(clk_pix),
	.rgb_i(fb_rgb),
	.rgb_o(osd_rgb),
	.hsync_i(fb_hs),
	.vsync_i(fb_vs),
	.v_offset(11'd0),
	.h_offset(11'd0),
	.osd_command(osd_cmd)
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
	hdmi_hs <= ~fb_hs;
	hdmi_vs <= ~fb_vs;
	hdmi_de <= fb_de;
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
