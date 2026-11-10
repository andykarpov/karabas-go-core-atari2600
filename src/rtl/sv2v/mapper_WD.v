module mapper_WD (
	clk,
	reset,
	a_change,
	sc,
	a_in,
	d_in,
	d_out,
	flags_out,
	oe,
	ram_sel,
	ram_rw,
	ram_a,
	rom_a,
	swapped
);
	input clk;
	input reset;
	input a_change;
	input sc;
	input [12:0] a_in;
	input [7:0] d_in;
	output wire [7:0] d_out;
	output wire [15:0] flags_out;
	output wire [7:0] oe;
	output wire ram_sel;
	output wire ram_rw;
	output wire [17:0] ram_a;
	output wire [18:0] rom_a;
	input swapped;
	reg [2:0] bank_config;
	reg [3:0] pending_switch;
	reg [11:0] banks;
	wire [11:0] bank_lut [0:7];
	assign bank_lut[0] = 12'h00b;
	assign bank_lut[1] = 12'h053;
	assign bank_lut[2] = 12'h977;
	assign bank_lut[3] = 12'hf13;
	assign bank_lut[4] = 12'h037;
	assign bank_lut[5] = 12'h07e;
	assign bank_lut[6] = 12'h4e5;
	assign bank_lut[7] = 12'hc29;
	wire [2:0] bank_raw;
	wire [2:0] bank_out;
	assign bank_raw = banks[(3 - a_in[11:10]) * 3+:3];
	assign bank_out = (swapped && (bank_raw[2:1] == 2'b01) ? {bank_raw[2:1], ~bank_raw[0]} : bank_raw);
	assign flags_out = 16'd0;
	assign d_out = 8'd0;
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : 8'hff) : 8'h00);
	assign ram_sel = a_in[12] && ~|a_in[11:7];
	assign ram_a = {12'd0, a_in[5:0]};
	assign ram_rw = ~a_in[6] || ~ram_sel;
	assign rom_a = {6'd0, bank_out, a_in[9:0]};
	always @(posedge clk) begin
		if (a_change) begin
			pending_switch <= {pending_switch[2:0], 1'b0};
			if (pending_switch[3])
				banks <= bank_lut[bank_config];
			if (a_in[12:4] == 9'h003) begin
				pending_switch <= 3'd1;
				bank_config <= a_in[2:0];
			end
		end
		if (reset) begin
			bank_config <= 0;
			pending_switch <= 0;
			banks <= bank_lut[0];
		end
	end
endmodule
