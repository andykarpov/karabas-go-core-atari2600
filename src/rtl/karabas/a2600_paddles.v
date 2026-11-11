`timescale 1ns / 1ps
`default_nettype wire
/*
 a2600_paddles.v

 Two paddles on the left port (INPT0 = paddle A, pin 9; INPT1 = paddle B, pin 5; their fire buttons
 SWCHA D7 / D6), from the mouse and the joysticks:
   paddle A: the mouse X, and left / right of P0 (keyboard arrows, the left pad); fire = the left
             mouse button or the fire of P0
   paddle B: left / right of P1 (the right pad); fire = the right mouse button or the fire of P1
 A position is 0..255 (0 = turned fully to the left). The pot of a paddle is 1 MOhm at the left
 end: kohms = 255 - position. The charge of the capacitor is paddle_timer of k7800 (paddles.sv
 through sv2v): it measures the window in which the game reads INPTx and spreads the 256 steps over
 it, so every game sees the full range.
 Joystick mode (paddles = 0): the second / third buttons of a pad (B, C; keyboard Left Alt) close
 pin 9 / pin 5 (a charged INPTx), as the trigger / booster of the Booster Grip.
*/
module a2600_paddles #(
	parameter NS_PER_TICK = 33'd3077      // one clk in ns x 100 (32.5 MHz)
) (
	input wire clk,
	input wire reset,
	input wire paddles,                  // 1: the left port has paddles

	input wire [7:0] ms_x,               // kg_mcu: the X move of the mouse (signed)
	input wire [2:0] ms_b,               // 0 left, 1 right
	input wire ms_upd,                   // toggles with a mouse report

	input wire a_left, a_right, a_fire,  // P0 of a2600_hid (active high)
	input wire b_left, b_right, b_fire,  // P1
	input wire [3:0] alt_buttons,        // joystick mode: {P1 pin 5, P1 pin 9, P0 pin 5, P0 pin 9}

	input wire [3:0] i_out,              // TIA: 1 = the dump transistors off (VBLANK D7 = 0)
	input wire [3:0] i_read,             // TIA: a read of INPT0..3
	output wire [3:0] idump,             // TIA I0..I3: 1 = charged
	output wire fire_a_n,                // SWCHA D7 / D6 in paddle mode (active low)
	output wire fire_b_n
);

reg [7:0] pos_a = 8'd128, pos_b = 8'd128;
reg upd_d = 1'b0;
reg [15:0] tick = 16'd0;      // the joystick move: a step per 2 ms (a sweep in 0.5 s)

wire [8:0] mouse_sum = {1'b0, pos_a} + {ms_x[7], ms_x};
always @(posedge clk) begin
	upd_d <= ms_upd;
	tick <= tick + 16'd1;
	if (ms_upd != upd_d) begin
		// signed add with clamping at 0 / 255: bit 8 of the 9-bit sum = out of 0..255 (below 0 for a
		// move to the left, above 255 for one to the right)
		if (mouse_sum[8])
			pos_a <= ms_x[7] ? 8'd0 : 8'd255;
		else
			pos_a <= mouse_sum[7:0];
	end else if (tick == 16'd0) begin
		if (a_left && !a_right && pos_a != 8'd0) pos_a <= pos_a - 8'd1;
		if (a_right && !a_left && pos_a != 8'd255) pos_a <= pos_a + 8'd1;
	end
	if (tick == 16'd0) begin
		if (b_left && !b_right && pos_b != 8'd0) pos_b <= pos_b - 8'd1;
		if (b_right && !b_left && pos_b != 8'd255) pos_b <= pos_b + 8'd1;
	end
end

wire charged_a, charged_b;
paddle_timer #(.NS_PER_TICK(NS_PER_TICK)) timer_a (
	.clk(clk),
	.ce(1'b1),
	.reset(reset | !paddles),
	.kohms({2'b00, ~pos_a}),
	.clear(~i_out[0]),
	.read(i_read[0]),
	.charged(charged_a),
	.difference()
);
paddle_timer #(.NS_PER_TICK(NS_PER_TICK)) timer_b (
	.clk(clk),
	.ce(1'b1),
	.reset(reset | !paddles),
	.kohms({2'b00, ~pos_b}),
	.clear(~i_out[1]),
	.read(i_read[1]),
	.charged(charged_b),
	.difference()
);

assign idump = paddles ? {2'b00, charged_b, charged_a} : alt_buttons;
assign fire_a_n = ~(a_fire | ms_b[0]);
assign fire_b_n = ~(b_fire | ms_b[1]);

endmodule
