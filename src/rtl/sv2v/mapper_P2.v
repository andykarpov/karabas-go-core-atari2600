module mapper_P2 (
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
	ce
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
	input ce;
	wire direct_en;
	wire rom_en;
	wire and_do_en;
	wire music_en;
	reg bank;
	reg [87:0] counters;
	reg [2:0] music_modes;
	reg [63:0] tops;
	reg [63:0] bottoms;
	reg [63:0] flags;
	reg [7:0] rand_val;
	wire dpc_oe;
	reg [9:0] music_div;
	reg [15:0] music_clock;
	reg [18:0] rom_a_next;
	wire [63:0] amplitude_lut = 64'h00040509060a0b0f;
	wire [2:0] dpc_addr = a_in[5:3];
	wire [2:0] index = a_in[2:0];
	wire [2:0] music_amp_index = {music_modes[2] & flags[0], music_modes[1] & flags[8], music_modes[0] & flags[16]};
	wire [7:0] rom_do_i = (~|dpc_addr ? (~music_en ? rand_val : amplitude_lut[(7 - music_amp_index) * 8+:8]) : ((dpc_addr == 3'd7) || (dpc_addr == 3'd2) ? flags[(7 - index) * 8+:8] : 8'd0));
	assign flags_out = {13'd0, dpc_oe && and_do_en, dpc_oe && direct_en};
	assign oe = (a_in[12] ? (~ram_rw && ram_sel ? 8'h00 : (dpc_oe ? 8'hff : 8'h00)) : 8'h00);
	assign ram_sel = (sc ? a_in[12:8] == 5'b10000 : 1'd0);
	assign ram_a = (sc ? {11'd0, a_in[6:0]} : 18'd0);
	assign ram_rw = (sc ? a_in[7] : 1'd1);
	assign d_out = rom_do_i;
	wire is_dpc = ~|a_in[11:7];
	wire dpc_rw = ~a_in[6];
	wire [2:0] ain_minus_5 = index - 3'd5;
	assign rom_en = (is_dpc && dpc_rw) && (dpc_addr == 3'd1);
	assign and_do_en = (is_dpc && dpc_rw) && (dpc_addr == 3'd2);
	assign direct_en = (is_dpc && dpc_rw) && ~(rom_en || and_do_en);
	assign music_en = (is_dpc && (dpc_addr == 3'b000)) && a_in[2];
	assign dpc_oe = ~is_dpc || (is_dpc && dpc_rw);
	assign rom_a = rom_a_next;
	reg [23:0] music_rem;
	always @(posedge clk) begin
		if (a_change) begin
			rom_a_next <= (is_dpc && ((dpc_addr == 1) || (dpc_addr == 2)) ? {8'b00000100, ~counters[(7 - index) * 11+:11]} : {6'd0, bank, a_in[11:0]});
			if (a_in[12]) begin
				rand_val <= {rand_val[6:0], ~(((rand_val[7] ^ rand_val[5]) ^ rand_val[4]) ^ rand_val[3])};
				if (is_dpc) begin
					if (dpc_rw) begin
						if ((index < 5) || !music_modes[ain_minus_5[1:0]])
							counters[(7 - index) * 11+:11] <= counters[(7 - index) * 11+:11] - 1'd1;
						if (counters[((7 - index) * 11) + 7-:8] == tops[(7 - index) * 8+:8])
							flags[(7 - index) * 8+:8] <= 8'hff;
						else if (counters[((7 - index) * 11) + 7-:8] == bottoms[(7 - index) * 8+:8])
							flags[(7 - index) * 8+:8] <= 8'h00;
					end
					else
						case (dpc_addr)
							3'h0: begin
								tops[(7 - index) * 8+:8] <= d_in;
								flags[(7 - index) * 8+:8] <= 8'h00;
							end
							3'h1: bottoms[(7 - index) * 8+:8] <= d_in;
							3'h2: counters[((7 - index) * 11) + 7-:8] <= ((index >= 3'd5) && music_modes[ain_minus_5[1:0]] ? tops[(7 - index) * 8+:8] : d_in);
							3'h3: begin
								counters[((7 - index) * 11) + 10-:3] <= d_in[2:0];
								if (index >= 3'd5)
									music_modes[ain_minus_5[1:0]] <= d_in[4];
							end
							3'h6: rand_val <= 8'h01;
							default:
								;
						endcase
				end
				else
					case (a_in)
						13'h1ff8: bank <= 0;
						13'h1ff9: bank <= 1;
						default:
							;
					endcase
			end
		end
		if (ce) begin
			music_div <= music_div + 1'd1;
			if (music_div == 178) begin
				music_div <= 10'd0;
				music_clock <= music_clock + 1'd1;
				if (music_modes[0])
					flags[16+:8] <= (music_rem[16+:8] > bottoms[16+:8] ? 8'hff : 8'h00);
				if (music_modes[1])
					flags[8+:8] <= (music_rem[8+:8] > bottoms[8+:8] ? 8'hff : 8'h00);
				if (music_modes[2])
					flags[0+:8] <= (music_rem[0+:8] > bottoms[0+:8] ? 8'hff : 8'h00);
			end
		end
		if (reset) begin
			bank <= 0;
			rand_val <= 8'h01;
			bottoms <= {8 {8'd0}};
			tops <= {8 {8'd0}};
			counters <= {8 {11'd0}};
			flags <= {8 {8'd0}};
			music_modes <= 1'sb0;
			music_clock <= 1'sb0;
			music_div <= 1'sb0;
		end
	end
	reg [15:0] mod_num;
	reg [23:0] mod_rem;
	wire [8:0] mod_res [0:2];
	reg [3:0] mod_step;
	reg mod_run;
	wire music_tick = ce && (music_div == 10'd178);
	wire tops_write = (((a_change && a_in[12]) && is_dpc) && ~dpc_rw) && (dpc_addr == 3'h0);
	wire mod_bit = mod_num[~mod_step];
	genvar _gv_v_1;
	generate
		for (_gv_v_1 = 0; _gv_v_1 < 3; _gv_v_1 = _gv_v_1 + 1) begin : music_mod
			localparam v = _gv_v_1;
			wire [8:0] divisor = {1'b0, tops[(7 - (v + 5)) * 8+:8]} + 9'd1;
			wire [8:0] shifted = {mod_rem[(2 - v) * 8+:8], mod_bit};
			assign mod_res[v] = (shifted >= divisor ? shifted - divisor : shifted);
		end
	endgenerate
	always @(posedge clk) begin
		if (music_tick || tops_write) begin
			mod_num <= (music_tick ? music_clock + 1'd1 : music_clock);
			mod_rem <= {3 {8'd0}};
			mod_step <= 4'd0;
			mod_run <= 1'b1;
		end
		else if (mod_run) begin
			mod_rem[16+:8] <= mod_res[0][7:0];
			mod_rem[8+:8] <= mod_res[1][7:0];
			mod_rem[0+:8] <= mod_res[2][7:0];
			mod_step <= mod_step + 1'd1;
			if (&mod_step) begin
				mod_run <= 1'b0;
				music_rem[16+:8] <= mod_res[0][7:0];
				music_rem[8+:8] <= mod_res[1][7:0];
				music_rem[0+:8] <= mod_res[2][7:0];
			end
		end
		if (reset) begin
			mod_run <= 1'b0;
			mod_step <= 4'd0;
			mod_num <= 16'd0;
			mod_rem <= {3 {8'd0}};
			music_rem <= {3 {8'd0}};
		end
	end
endmodule
