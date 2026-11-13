#!/usr/bin/env python3
"""Makes rtl/karabas_mini_top.v and rtl/karabas_go_top.v from rtl/karabas_minig_top.v, and the timing
part of karabas_mini.ucf / karabas_go.ucf from that of karabas_minig.ucf (as core-macplus).

The three tops share everything but the board: change the Mini G top, then run this (every
replacement must match once, else it stops). The pin parts of the Mini / Go ucf (above the timing
mark) are kept; the ports are those of core-macplus / core-atarist.

Mini (before rev.G): MCU_SCK not on a clock pin (no BUFG), 4 MCU_IO,
  sigma-delta audio on AUDIO_L / AUDIO_R instead of the PCM5102, FT_RESET, the ESP pins.
Go: VGA 8:8:8 with V_CLK (clk_pix) instead of HDMI, the FT812 off the video bus (FT_OE_N = 1), the
  MCU link on MCU_SPI_*, DAC_LRCK / DAC_MUTE, the floppy connector unused (its outputs 0), the SDRAM
  /CS hard wired (FLASH_CS_N = 1: the flash chip), no FT_CLK_OUT.
Both: the SAM2695 synth held in reset (MIDI_RESET_N = 0, no MIDI_CLK).
"""
import os
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RTL = os.path.join(SRC, "rtl")


def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("mktops.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)


def cut(s, a_mark, b_mark, new, what):
    if s.count(a_mark) != 1 or s.count(b_mark) != 1:
        sys.exit("mktops.py: %s: marks %r / %r" % (what, a_mark[:40], b_mark[:40]))
    a = s.index(a_mark)
    b = s.index(b_mark, a)
    return s[:a] + new + s[b:]


def ports(s, body):
    a = s.index("module karabas_minig_top (")
    b = s.index("\n);\n", a) + 4
    return s[:a] + body + s[b:]


COMMON_PORTS_HEAD = """	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,

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
"""

FLASH_PORTS = """	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);
"""

MINI_PORTS = "module karabas_mini_top (\n" + COMMON_PORTS_HEAD + """
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
	input wire FT_AUDIO,
	input wire FT_DISP,
	output wire FT_RESET,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire AUDIO_L,
	output wire AUDIO_R,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [3:0] MCU_IO, // [1] INT of link v2, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

""" + FLASH_PORTS

GO_PORTS = "module karabas_go_top (\n" + COMMON_PORTS_HEAD + """
	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B,
	output wire VGA_HS,
	output wire VGA_VS,
	output wire V_CLK,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	output wire FT_OE_N,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	input wire FDC_INDEX,
	output wire [1:0] FDC_DRIVE,
	output wire FDC_MOTOR,
	output wire FDC_DIR,
	output wire FDC_STEP,
	output wire FDC_WDATA,
	output wire FDC_WGATE,
	input wire FDC_TR00,
	input wire FDC_WPRT,
	input wire FDC_RDATA,
	output wire FDC_SIDE_N,

	output wire TAPE_OUT,
	input wire TAPE_IN,
	output wire BEEPER,

	output wire DAC_LRCK,
	output wire DAC_DAT,
	output wire DAC_BCK,
	output wire DAC_MUTE,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	input wire MCU_SPI_FT_CS_N,
	input wire MCU_SPI_SD2_CS_N,
	inout wire [1:0] MCU_SPI_IO, // [0] INT of link v2 (firmware IO1, GPIO2), [1] unused (IO0, GPIO14)

	output wire MIDI_TX,
	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

""" + FLASH_PORTS

HEADER_G = (" Atari 2600 VCS core for Karabas Mini rev.G (HDMI, PCM5102): atari2600_top (the 2600 part of k7800\n"
            " through sv2v, rtl/karabas) with the karabas parts and the board glue of karabas-go-modules.\n")

MCU_SCK_G = """wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));
"""
MCU_SCK_OLD = """// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;
"""

UNUSED_SYNTH = """assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, not used
assign MIDI_RESET_N = 1'b0;
"""

PCM = """kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 4.06 MHz, 127 kHz
	.clk(clk_sys),
	.reset(areset),
	.left(audio_l),
	.right(audio_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);
"""


def common(s):
    s = sub(s, "assign ESP32_SPI_CS_N = 1'b1;\n", "", "ESP32_SPI_CS_N")
    s = sub(s, "assign MIDI_TX = 1'b1;\n", "assign MIDI_TX = 1'b1;\n" + UNUSED_SYNTH, "unused")
    s = sub(s, MCU_SCK_G, MCU_SCK_OLD, "MCU_SCK")
    return s


def mini(s):
    s = sub(s, HEADER_G,
            " Atari 2600 VCS core for Karabas Mini before rev.G (HDMI, sigma-delta audio). Made by\n"
            " tools/mktops.py from karabas_minig_top.v (do not edit: change that one and run it): the same\n"
            " except the pins, the MCU link (MCU_SCK not on a clock pin) and the audio (AUDIO_L / AUDIO_R).\n"
            " atari2600_top (the 2600 part of k7800 through sv2v, rtl/karabas) with the karabas parts and the\n"
            " board glue of karabas-go-modules.\n", "header")
    s = ports(s, MINI_PORTS)
    s = common(s)
    s = sub(s, "assign MIDI_RESET_N = 1'b0;\n", "assign MIDI_RESET_N = 1'b0;\nassign FT_RESET = 1'b1;\n", "FT_RESET")
    s = sub(s, "assign MCU_IO[5:2] = 4'bzzzz;\n", "assign MCU_IO[3:2] = 2'bzz;\n", "MCU_IO")
    s = sub(s, PCM, "// no I2S DAC on this board: sigma-delta outputs into an RC filter (offset binary: the mix\n"
               "// 0 .. 7FFF as the full range)\n"
               "kg_sigma_delta_dac dac_l (.clk(clk_sys), .reset(areset), .din({ audio_l[14:0], 1'b0 }), .dout(AUDIO_L));\n"
               "kg_sigma_delta_dac dac_r (.clk(clk_sys), .reset(areset), .din({ audio_r[14:0], 1'b0 }), .dout(AUDIO_R));\n",
            "audio")
    return s


def go(s):
    s = sub(s, HEADER_G,
            " Atari 2600 VCS core for Karabas Go (VGA, PCM5102). Made by tools/mktops.py from\n"
            " karabas_minig_top.v (do not edit: change that one and run it): the same except the pins, the MCU\n"
            " link (MCU_SCK not on a clock pin) and the video: 24 bit RGB to the VGA DAC with its pixel clock on\n"
            " V_CLK (clk_pix), the FT812 off that bus (FT_OE_N = 1), no HDMI. The floppy connector is not used\n"
            " (its outputs 0). atari2600_top (the 2600 part of k7800 through sv2v, rtl/karabas) with the\n"
            " karabas parts and the board glue of karabas-go-modules.\n", "header")
    s = ports(s, GO_PORTS)
    s = common(s)
    s = sub(s, "assign ADC_CLK = 1'b0;\nassign ADC_BCK = 1'bz;\nassign ADC_LRCK = 1'bz;\n",
            "assign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC\n"
            "assign BEEPER = 1'b0;\n"
            "assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on\n\n"
            "// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)\n"
            "assign FDC_DRIVE = 2'b00;\nassign FDC_MOTOR = 1'b0;\nassign FDC_DIR = 1'b0;\nassign FDC_STEP = 1'b0;\n"
            "assign FDC_WDATA = 1'b0;\nassign FDC_WGATE = 1'b0;\nassign FDC_SIDE_N = 1'b0;\n", "unused Go")
    s = sub(s, "// the clock of the FT812\n"
               "ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
            "// the pixel clock of the VGA DAC\n"
            "ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_pix), .C1(~clk_pix), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
            "V_CLK")
    s = sub(s, "assign MCU_IO[1] = mcu_int;\nassign MCU_IO[0] = 1'bz;\nassign MCU_IO[5:2] = 4'bzzzz;\n",
            "assign MCU_SPI_IO[0] = mcu_int;   // INT of link v2 on N9 (IO1 of the firmware)\nassign MCU_SPI_IO[1] = 1'bz;\n", "MCU_IO")
    s = sub(s, "	.MCU_SPI_FT_SS(MCU_IO[3]),\n	.MCU_SPI_SD2_SS(MCU_IO[2]),\n",
            "	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),\n	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),\n", "MCU SS")
    s = sub(s, "	.lrck(DAC_WS)\n", "	.lrck(DAC_LRCK)\n", "DAC_LRCK")
    s = sub(s, "// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board): always selected\n"
               "assign FLASH_CS_N = 1'b0;\n",
            "// the flash chip (the SDRAM /CS is hard wired on Go): not selected\n"
            "assign FLASH_CS_N = 1'b1;\n", "FLASH_CS_N")
    s = cut(s, "// 48 kHz for hdmi_tx on clk_pix", "// ------------------------------------------------------------------ debug",
            """// ------------------------------------------------------------------ VGA

// 1024 x 768 at 60 Hz: negative syncs (VESA); the OSD output is registered with them
reg vga_hs = 1'b1, vga_vs = 1'b1;
reg [23:0] vga_rgb = 24'd0;
always @(posedge clk_pix) begin
	vga_hs <= ~fb_hs;
	vga_vs <= ~fb_vs;
	vga_rgb <= osd_rgb;
end
assign VGA_R = vga_rgb[23:16];
assign VGA_G = vga_rgb[15:8];
assign VGA_B = vga_rgb[7:0];
assign VGA_HS = vga_hs;
assign VGA_VS = vga_vs;

""", "HDMI")
    return s


MARK = "# ------------------------------------------------------------------------------------------------------------\n# Timing constraints"
TMDS_AG_MARK = "\n\n# the TMDS serialisers (325 MHz)"


def ucf(board):
    g = open(os.path.join(SRC, "karabas_minig.ucf")).read()
    if g.count(MARK) != 1:
        sys.exit("mktops.py: no timing mark in karabas_minig.ucf")
    timing = g[g.index(MARK):]
    timing = sub(timing, "karabas_minig_top.v", "karabas_%s_top.v" % board, "ucf top")
    if board == "mini":
        timing = sub(timing, "#   clk_8 (/81, 8.02 MHz): FT_CLK_OUT only (an ODDR2)\n",
                     "#   clk_8 (/81, 8.02 MHz): FT_CLK_OUT only (an ODDR2)\n"
                     "# MCU_SCK is not on a clock pin before rev.G (local routing, bursts at the link clock).\n",
                     "ucf mini")
    if board == "go":
        timing = sub(timing, "#   clk_hdmi / clk_hdmi_n (/2, 325 MHz, 0 / 180 degrees): the TMDS serialiser\n",
                     "#   clk_hdmi / clk_hdmi_n (/2): not used on Go (no HDMI)\n", "ucf go hdmi")
        timing = sub(timing, "the 1024 x 768 output, the frame buffer read side, the OSD, HDMI audio\n",
                     "the 1024 x 768 output (VGA, V_CLK), the frame buffer read side, the OSD\n", "ucf go pix")
        timing = sub(timing, "#   clk_8 (/81, 8.02 MHz): FT_CLK_OUT only (an ODDR2)\n",
                     "#   clk_8 (/81): not used on Go (no FT_CLK_OUT)\n", "ucf go clk_8")
        timing = sub(timing, 'NET "clk_hdmi" TNM_NET = "TG_CLK_HDMI";\n', "", "ucf go TG_CLK_HDMI")
        timing = sub(timing, "# zhdmi takes its words from clk_pix registers into the x5 clock (the serialiser of hdmi_tx)\n"
                     'TIMESPEC "TS_PIX_TO_HDMI" = FROM "TG_CLK_PIX" TO "TG_CLK_HDMI" TIG;\n', "", "ucf go TS_PIX_TO_HDMI")
        if timing.count(TMDS_AG_MARK) != 1:
            sys.exit("mktops.py: ucf go: no TMDS area group")
        timing = timing[:timing.index(TMDS_AG_MARK)] + "\n"
    path = os.path.join(SRC, "karabas_%s.ucf" % board)
    pins = open(path).read()
    pins = pins[:pins.index(MARK)] if MARK in pins else pins.rstrip("\n") + "\n\n"
    open(path, "w").write(pins + timing)
    print(os.path.normpath(path))


src = open(os.path.join(RTL, "karabas_minig_top.v")).read()
for name, f in (("karabas_mini_top.v", mini), ("karabas_go_top.v", go)):
    out = os.path.join(RTL, name)
    open(out, "w").write(f(src))
    print(os.path.normpath(out))
for board in ("mini", "go"):
    ucf(board)
