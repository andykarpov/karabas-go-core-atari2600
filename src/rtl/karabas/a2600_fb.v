`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_fb.v

 The frame buffer of the TIA picture and the 1024 x 768 at 60 Hz output (VESA DMT: 65 MHz, 1344 x 806,
 hsync 1048..1183, vsync lines 771..776; hs / vs here are high in the sync, the top makes them negative).

 Capture (clk_sys, one pixel per video_ce = one colour clock): x counts colour clocks from the rising
 hsync, y lines from the rising vsync (as sim/sim_a2600.cpp). The window is 160 x 240: x X0..X0+159
 (the visible part of a line starts 50 colour clocks after the hsync rise), y Y0..Y0+239 (NTSC games
 show lines 40..231: Y0 16 puts them in the middle). A pixel is {0, col, lum}, 0 (black) while blanked.
 Memory: 5 banks of 8K x 8 (20 RAMB16), address y * 160 + x (38400 bytes).

 Output (clk_pix): the 160 x 240 picture x6 / x3 = 960 x 720 in the middle of 1024 x 768 (32 black
 columns each side, 24 lines above and below), the NWARM palette of k7800 (256 entries, index {col, lum, 0}). One buffer: the
 output reads while the machine writes, at 59.92 against 60.004 Hz a seam can cross a moving picture slowly.
 Pipeline: address (clock 0), memory (1), bank mux / palette address (2), palette (3): the syncs and de
 are delayed by 3 clocks.
*/
module a2600_fb #(
	parameter [7:0] X0 = 8'd50,
	parameter [8:0] Y0 = 9'd16
) (
	input wire clk_sys,
	input wire video_ce,
	input wire [3:0] col,
	input wire [2:0] lum,
	input wire hsync_i,
	input wire vsync_i,
	input wire blank_i,

	input wire clk_pix,
	output reg [23:0] rgb = 24'd0,
	output reg hs = 1'b0,
	output reg vs = 1'b0,
	output reg de = 1'b0
);

// ---------------------------------------------------------------- capture (clk_sys)

reg [7:0] cx = 8'd0;
reg [8:0] cy = 9'd0;
reg old_hs = 1'b0, old_vs = 1'b0;
reg [15:0] line_base = 16'd0;  // (cy - Y0) * 160
reg we = 1'b0;
reg [15:0] wa = 16'd0;
reg [7:0] wd = 8'd0;

// as sim_a2600.cpp: the colour clock of the hsync rise is x 0 of a new line (y + 1), a vsync rise
// makes the line y 0 at once (also when both come in one colour clock)
wire hs_rise = hsync_i && !old_hs;
wire vs_rise = vsync_i && !old_vs;
wire [7:0] x_now = hs_rise ? 8'd0 : cx;
wire [8:0] y_now = vs_rise ? 9'd0 : hs_rise ? (cy == 9'h1FF ? cy : cy + 9'd1) : cy;
wire [15:0] base_now = (vs_rise || y_now <= Y0) ? 16'd0 : hs_rise ? line_base + 16'd160 : line_base;

always @(posedge clk_sys) begin
	we <= 1'b0;
	if (video_ce) begin
		old_hs <= hsync_i;
		old_vs <= vsync_i;
		cx <= (x_now == 8'hFF) ? x_now : x_now + 8'd1;
		cy <= y_now;
		line_base <= base_now;
		if (x_now >= X0 && x_now < X0 + 8'd160 && y_now >= Y0 && y_now < Y0 + 9'd240) begin
			we <= 1'b1;
			wa <= base_now + {8'd0, x_now - X0};
			wd <= blank_i ? 8'd0 : {1'b0, col, lum};
		end
	end
end

// ---------------------------------------------------------------- memory: 5 banks of 8K x 8

reg [7:0] bank0 [0:8191];
reg [7:0] bank1 [0:8191];
reg [7:0] bank2 [0:8191];
reg [7:0] bank3 [0:8191];
reg [7:0] bank4 [0:8191];

always @(posedge clk_sys) if (we && wa[15:13] == 3'd0) bank0[wa[12:0]] <= wd;
always @(posedge clk_sys) if (we && wa[15:13] == 3'd1) bank1[wa[12:0]] <= wd;
always @(posedge clk_sys) if (we && wa[15:13] == 3'd2) bank2[wa[12:0]] <= wd;
always @(posedge clk_sys) if (we && wa[15:13] == 3'd3) bank3[wa[12:0]] <= wd;
always @(posedge clk_sys) if (we && wa[15:13] == 3'd4) bank4[wa[12:0]] <= wd;

reg [15:0] ra = 16'd0;
reg [7:0] q0 = 8'd0, q1 = 8'd0, q2 = 8'd0, q3 = 8'd0, q4 = 8'd0;
always @(posedge clk_pix) begin
	q0 <= bank0[ra[12:0]];
	q1 <= bank1[ra[12:0]];
	q2 <= bank2[ra[12:0]];
	q3 <= bank3[ra[12:0]];
	q4 <= bank4[ra[12:0]];
end

// ---------------------------------------------------------------- palette (k7800 NWARM)

// in LUTs: a 256 x 24 ROM would be a RAMB8BWER, whose initial data bitgen warns about (AR 39999)
(* ram_style = "distributed" *) reg [23:0] palette [0:255];
initial $readmemh("rtl/k7800/palettes/NWARM.hex", palette);

// ---------------------------------------------------------------- output timing (clk_pix)

reg [10:0] h = 11'd0;
reg [9:0] v = 10'd0;
reg [2:0] sub_x = 3'd0;     // 0..5
reg [1:0] sub_y = 2'd0;     // 0..2
reg [7:0] sx = 8'd0;        // source x 0..159
reg [15:0] src_line = 16'd0; // source y * 160
reg in_pic = 1'b0;          // clock 0: a picture pixel
reg [2:0] bank_1 = 3'd0, bank_2 = 3'd0;
reg pic_1 = 1'b0, pic_2 = 1'b0;
reg [2:0] hs_d = 3'b000, vs_d = 3'b000, de_d = 3'b000;
reg [7:0] pidx = 8'd0;

wire h_act = h < 11'd1024;
wire v_act = v < 10'd768;
wire h_pic = h >= 11'd32 && h < 11'd992;
wire v_pic = v >= 10'd24 && v < 10'd744;

always @(posedge clk_pix) begin
	// counters
	if (h == 11'd1343) begin
		h <= 11'd0;
		if (v == 10'd805) begin
			v <= 10'd0;
			sub_y <= 2'd0;
			src_line <= 16'd0;
		end else begin
			v <= v + 10'd1;
			if (!v_pic) begin
				sub_y <= 2'd0;
				src_line <= 16'd0;
			end else if (sub_y == 2'd2) begin
				sub_y <= 2'd0;
				src_line <= src_line + 16'd160;
			end else
				sub_y <= sub_y + 2'd1;
		end
	end else
		h <= h + 11'd1;

	if (!h_pic) begin
		sub_x <= 3'd0;
		sx <= 8'd0;
	end else if (sub_x == 3'd5) begin
		sub_x <= 3'd0;
		sx <= sx + 8'd1;
	end else
		sub_x <= sub_x + 3'd1;

	// clock 0: the address
	ra <= src_line + {8'd0, sx};
	in_pic <= h_pic && v_pic;
	// clock 1: the memory read, clock 2: the bank of it
	bank_1 <= ra[15:13];
	pic_1 <= in_pic;
	bank_2 <= bank_1;
	pic_2 <= pic_1;
	case (bank_1)
		3'd0: pidx <= {q0[6:0], 1'b0};
		3'd1: pidx <= {q1[6:0], 1'b0};
		3'd2: pidx <= {q2[6:0], 1'b0};
		3'd3: pidx <= {q3[6:0], 1'b0};
		default: pidx <= {q4[6:0], 1'b0};
	endcase
	// clock 3: the colour
	rgb <= pic_2 ? palette[pidx] : 24'd0;

	hs_d <= {hs_d[1:0], h >= 11'd1048 && h < 11'd1184};
	vs_d <= {vs_d[1:0], v >= 10'd771 && v < 10'd777};
	de_d <= {de_d[1:0], h_act && v_act};
	hs <= hs_d[2];
	vs <= vs_d[2];
	de <= de_d[2];
end

endmodule
