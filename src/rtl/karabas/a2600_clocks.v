`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_clocks.v

 The clocks of 1024 x 768 at 60 Hz (VESA: 65 MHz) from CLK_50MHZ (the pin): one PLL, VCO 50 x 13 =
 650 MHz:
   clk_hdmi / clk_hdmi_n /2  325 MHz, 0 and 180 degrees: the TMDS serialiser
   clk_pix               /10 65 MHz: the video output, the frame buffer read side, the OSD, HDMI audio
   clk_sys               /20 32.5 MHz: the machine, the MCU link, the SRAM, the DAC (phase aligned to
                             clk_pix: the paths between them are timed)
   clk_8                 /81 8.02 MHz: FT_CLK_OUT
 (1280 x 720 at 74.25 MHz was tried first: its 371 MHz serialiser and the HDMI island encoder at
 74 MHz did not meet the timing on the -2 part.)
 The TIA CE of the machine comes from clk_sys: 2 x the NTSC colour clock = 7.159091 MHz = clk_sys *
 63 / 286 exactly (a2600_ce).
*/
module a2600_clocks (
	input wire clk_in,       // CLK_50MHZ, the pin
	output wire clk_pix,
	output wire clk_hdmi,
	output wire clk_hdmi_n,
	output wire clk_sys,
	output wire clk_8,
	output wire locked
);

wire [5:0] pll_clk;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(13),
	.CLKOUT0_DIVIDE(2),
	.CLKOUT1_DIVIDE(2),
	.CLKOUT1_PHASE(180.0),
	.CLKOUT2_DIVIDE(10),
	.CLKOUT3_DIVIDE(20),
	.CLKOUT4_DIVIDE(81),
	.IBUFG(1),
	.BUFG_MASK(6'b011111)
) pll (
	.clk_in(clk_in),
	.rst(1'b0),
	.clk_out(pll_clk),
	.locked(locked)
);
assign clk_hdmi = pll_clk[0];
assign clk_hdmi_n = pll_clk[1];
assign clk_pix = pll_clk[2];
assign clk_sys = pll_clk[3];
assign clk_8 = pll_clk[4];

endmodule
