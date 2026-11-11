`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_ce.v

 The TIA clock enable of atari2600_top: twice the colour clock, one clk wide, from a fractional
 accumulator (ce when acc + N wraps at D). At clk_sys 32.5 MHz (a2600_clocks):
   NTSC 7.159091 MHz = 2 x 315 / 88 MHz          N / D = 63 / 286 exactly
   PAL  7.093790 MHz = 2 x 4.43361875 * 4 / 5    N / D = 12446 / 57021 (+0.001 ppm)
 run = 0 holds the CE low: the whole machine stops (pause, the load of a cartridge).
*/
module a2600_ce #(
	parameter [15:0] N_NTSC = 16'd63,
	parameter [15:0] D_NTSC = 16'd286,
	parameter [15:0] N_PAL = 16'd12446,
	parameter [15:0] D_PAL = 16'd57021
) (
	input wire clk,
	input wire run,
	input wire pal,
	output reg ce = 1'b0
);

reg [15:0] acc = 16'd0;
wire [15:0] n = pal ? N_PAL : N_NTSC;
wire [15:0] d = pal ? D_PAL : D_NTSC;
wire [16:0] sum = {1'b0, acc} + {1'b0, n};

always @(posedge clk) begin
	ce <= 1'b0;
	if (run) begin
		if (sum >= {1'b0, d}) begin
			acc <= sum[15:0] - d;
			ce <= 1'b1;
		end else
			acc <= sum[15:0];
	end
end

endmodule
