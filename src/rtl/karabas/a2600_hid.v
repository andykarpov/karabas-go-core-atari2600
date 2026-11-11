`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_hid.v

 The USB devices of the mcu link (kg_mcu) as the controllers and console switches of the 2600.

 Joysticks: kg_mcu JOY bits 1 up, 2 down, 3 left, 4 right, 5 start, 6 A, 7 B, 8 C, 9 X, 12 mode.
 joy_l is the left (P0) joystick, joy_r the right (P1); the keyboard is P0 too: the arrows, fire =
 Space or Left Ctrl, Fire 2 = Left Alt. Fire = A; Fire 2 = B (pin 9 of the port: INPT0 / INPT2),
 Fire 3 = C (pin 5: INPT1 / INPT3), the trigger and booster of the Booster Grip (alt_buttons, through
 a2600_paddles in joystick mode).
   RIOT port A (SWCHA, active low): 7 P0 right, 6 P0 left, 5 P0 down, 4 P0 up, 3..0 the same of P1
   TIA I4 / I5 (INPT4 / INPT5, active low): the fire buttons of P0 / P1
 Console (as the keys of Stella): F1 Select, F2 Game Reset; a pad: Start = Game Reset, Mode or X =
 Select. F12 is the reset of the machine (key_reset, the rule of the cores), not the Game Reset.
 The difficulty and TV type switches are OSD items (the top puts them into SWCHB).

 Keyboard report: kb_status = the modifier bits (0 Left Ctrl, 2 Left Alt), kb_dat0..5 = USB HID usage codes
 (bit 7 = no key).
*/
module a2600_hid (
	input wire [7:0] kb_status,
	input wire [7:0] kb_dat0,
	input wire [7:0] kb_dat1,
	input wire [7:0] kb_dat2,
	input wire [7:0] kb_dat3,
	input wire [7:0] kb_dat4,
	input wire [7:0] kb_dat5,
	input wire [12:0] joy_l,
	input wire [12:0] joy_r,

	output wire [7:0] pa_in,
	output wire [1:0] ilatch,
	output wire p0_left_o, p0_right_o, p0_fire_o,   // for the paddles
	output wire p1_left_o, p1_right_o, p1_fire_o,
	output wire [3:0] alt_buttons,  // {P1 pin 5, P1 pin 9, P0 pin 5, P0 pin 9}: 1 = pressed
	output wire sw_select_n,   // SWCHB bit 1
	output wire sw_reset_n,    // SWCHB bit 0
	output wire key_reset      // F12
);

function in_report;
	input [6:0] c;
	in_report = (!kb_dat0[7] && kb_dat0[6:0] == c) || (!kb_dat1[7] && kb_dat1[6:0] == c) ||
	            (!kb_dat2[7] && kb_dat2[6:0] == c) || (!kb_dat3[7] && kb_dat3[6:0] == c) ||
	            (!kb_dat4[7] && kb_dat4[6:0] == c) || (!kb_dat5[7] && kb_dat5[6:0] == c);
endfunction

wire k_right = in_report(7'h4F);
wire k_left = in_report(7'h50);
wire k_down = in_report(7'h51);
wire k_up = in_report(7'h52);
wire k_fire = in_report(7'h2C) || kb_status[0];
wire k_f1 = in_report(7'h3A);
wire k_f2 = in_report(7'h3B);
wire k_f12 = in_report(7'h45);

wire p0_right = joy_l[4] | k_right;
wire p0_left = joy_l[3] | k_left;
wire p0_down = joy_l[2] | k_down;
wire p0_up = joy_l[1] | k_up;
wire p0_fire = joy_l[6] | k_fire;
wire p1_fire = joy_r[6];

assign pa_in = ~{ p0_right, p0_left, p0_down, p0_up, joy_r[4], joy_r[3], joy_r[2], joy_r[1] };
assign ilatch = ~{ p1_fire, p0_fire };
assign p0_left_o = p0_left;
assign p0_right_o = p0_right;
assign p0_fire_o = p0_fire;
assign p1_left_o = joy_r[3];
assign p1_right_o = joy_r[4];
assign p1_fire_o = p1_fire;
assign alt_buttons = { joy_r[8], joy_r[7], joy_l[8], joy_l[7] | kb_status[2] };
assign sw_select_n = ~(k_f1 | joy_l[12] | joy_l[9] | joy_r[12] | joy_r[9]);
assign sw_reset_n = ~(k_f2 | joy_l[5] | joy_r[5]);
assign key_reset = k_f12;

endmodule
