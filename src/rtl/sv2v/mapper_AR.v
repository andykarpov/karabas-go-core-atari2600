module mapper_AR (
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
	ce,
	ar_read,
	rom_do,
	tape_in,
	fix_sc_cs,
	audio_data,
	rom_size
);
	reg _sv2v_0;
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
	output wire ar_read;
	input [7:0] rom_do;
	input [1:0] tape_in;
	input fix_sc_cs;
	output reg audio_data;
	input [18:0] rom_size;
	localparam CYCLES_PER_HALF_1 = 12'd608;
	localparam CYCLES_PER_HALF_0 = 12'd405;
	localparam PREAMBLE_CYCLES_PER_HALF = 12'd2384;
	localparam COOLDOWN_PERIOD = 16'h0fff;
	reg [2:0] bank;
	reg [5:0] we_cycle;
	wire [7:0] bios_data;
	reg ram_we;
	reg [7:0] we_byte;
	wire rom_en;
	reg [18:0] preload_a;
	reg [7:0] header_a;
	reg [7:0] bank_a;
	reg [3:0] state;
	reg [3:0] state_next;
	reg [11:0] audio_timer;
	reg [3:0] bit_position;
	reg [7:0] page_position;
	wire header_toggle;
	reg [7:0] page_count;
	reg [10:0] state_count;
	reg [16:0] tape_offset;
	reg pre_fetch_byte;
	reg fetch_byte;
	reg playback;
	reg current_bit;
	reg [7:0] audio_buffer;
	reg [15:0] cooldown;
	wire [3:0] bank_lut [0:7];
	reg [1:0] tape_num;
	reg eq_tone;
	reg [7:0] header_array [0:7];
	reg [7:0] block_byte_array [0:23];
	reg [7:0] block_checksum;
	reg [7:0] cs_array [0:23];
	assign bank_lut[0] = 4'hb;
	assign bank_lut[1] = 4'h3;
	assign bank_lut[2] = 4'h8;
	assign bank_lut[3] = 4'h2;
	assign bank_lut[4] = 4'hb;
	assign bank_lut[5] = 4'h7;
	assign bank_lut[6] = 4'h9;
	assign bank_lut[7] = 4'h6;
	wire adata_select = a_in == 13'h1ff9;
	wire is_control_reg = a_in == 13'h1ff8;
	wire [3:0] bit_pos_minus_1 = bit_position - 1'd1;
	wire [1:0] current_bank = (~a_in[11] ? bank_lut[bank][2+:2] : bank_lut[bank][0+:2]);
	wire rom_bank = &current_bank;
	wire adc_load = tape_in[1];
	assign flags_out = {15'd0, (rom_bank || ~ram_rw) || adata_select};
	assign oe = (a_in[12] ? 8'hff : 8'h00);
	assign ram_sel = a_in[12] && ~rom_bank;
	assign ram_a = {5'd0, current_bank, a_in[10:0]};
	assign ram_rw = ~(((((a_in[12] && ram_we) && we_cycle[5]) && ~a_change) && ~is_control_reg) && ~rom_bank);
	assign rom_a = preload_a + tape_offset;
	assign ar_read = ce;
	assign d_out = (~ram_rw ? we_byte : (adata_select ? {7'd0, audio_data} : bios_data));
	spram #(
		.addr_width(11),
		.mem_init_file("ar.mif"),
		.sim_init_file("rtl/k7800/ar.hex")
	) ar_rom(
		.clock(clk),
		.address(a_in[10:0]),
		.data(8'd0),
		.wren(1'b0),
		.cs(1'b1),
		.q(bios_data)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		case (state_next)
			4'd7: preload_a = {6'b100000, header_a};
			4'd2: preload_a = {6'b100000, header_a};
			4'd8: preload_a = {6'b100000, page_position + 8'h10};
			4'd3: preload_a = {6'b100000, page_position + 8'h10};
			4'd9: preload_a = {6'b100000, page_position + 8'h40};
			4'd4: preload_a = {3'd0, page_position, bank_a};
			4'd10: preload_a = {3'd0, page_position, bank_a};
			default: preload_a = 19'd0;
		endcase
		case (tape_num)
			0: tape_offset = 17'h00000;
			1: tape_offset = 17'h02100;
			2: tape_offset = 17'h04200;
			3: tape_offset = 17'h06300;
			default: tape_offset = 17'h00000;
		endcase
	end
	always @(posedge clk) begin
		if (adc_load)
			audio_data <= tape_in[0];
		if (ce) begin
			fetch_byte <= 0;
			if (playback) begin
				audio_timer <= audio_timer + 1'd1;
				if (eq_tone && (audio_timer == PREAMBLE_CYCLES_PER_HALF)) begin
					audio_timer <= 0;
					audio_data <= ~audio_data;
					state_count <= state_count + 1'd1;
					if (&state_count[10:0]) begin
						fetch_byte <= 1;
						eq_tone <= 0;
					end
				end
				else if (~eq_tone && (audio_timer == (current_bit ? CYCLES_PER_HALF_1 : CYCLES_PER_HALF_0))) begin
					audio_timer <= 0;
					bit_position <= bit_pos_minus_1;
					audio_data <= bit_position[0];
					current_bit <= audio_buffer[bit_pos_minus_1[3:1]];
					fetch_byte <= bit_position == 1;
				end
			end
			case (state)
				4'd0: begin
					header_a <= 0;
					pre_fetch_byte <= 1;
					fetch_byte <= 0;
					bit_position <= 0;
					page_position <= 0;
					eq_tone <= 0;
					state_count <= 0;
					bank_a <= 0;
					if (tape_offset >= rom_size)
						tape_num <= 0;
					state_next <= 4'd2;
					state <= 4'd1;
				end
				4'd1:
					if (fetch_byte || pre_fetch_byte)
						state <= state_next;
				4'd2: begin
					header_array[header_a[2:0]] <= (header_a != 4 ? rom_do : 8'd0);
					if (header_a == 3)
						page_count <= rom_do;
					if (header_a < 7) begin
						header_a <= header_a + 1'd1;
						state_next <= 4'd2;
					end
					else begin
						header_a <= 0;
						header_array[4] <= 8'h55 - (((((((header_array[0] + header_array[1]) + header_array[2]) + header_array[3]) + header_array[4]) + header_array[5]) + header_array[6]) + header_array[7]);
						state_next <= 4'd3;
					end
					state <= 4'd1;
				end
				4'd3: begin
					block_byte_array[page_position[4:0]] <= rom_do;
					block_checksum <= 0;
					state_next <= 4'd4;
					state <= 4'd1;
				end
				4'd4: begin
					if (&bank_a) begin
						cs_array[page_position[4:0]] <= (8'h55 - block_byte_array[page_position[4:0]]) - (block_checksum + rom_do);
						page_position <= page_position + 1'd1;
						state_next <= ((page_position == (page_count - 1'd1)) || (page_position == 23) ? 4'd6 : 4'd3);
					end
					else begin
						block_checksum <= block_checksum + rom_do;
						state_next <= 4'd4;
					end
					bank_a <= bank_a + 1'd1;
					state <= 4'd1;
				end
				4'd6: begin
					pre_fetch_byte <= 0;
					playback <= 1;
					audio_buffer <= (&state_count[8:0] ? 8'h54 : 8'h55);
					state_count <= state_count + 1'd1;
					state_next <= (&state_count[8:0] ? 4'd7 : 4'd6);
					state <= 4'd1;
				end
				4'd7: begin
					if (fix_sc_cs)
						audio_buffer <= header_array[header_a[2:0]];
					else
						audio_buffer <= rom_do;
					if (header_a < 7) begin
						header_a <= header_a + 1'd1;
						state_next <= 4'd7;
					end
					else begin
						header_a <= 0;
						page_position <= 0;
						state_next <= 4'd8;
					end
					state <= 4'd1;
				end
				4'd8: begin
					if (fix_sc_cs)
						audio_buffer <= block_byte_array[page_position[4:0]];
					else
						audio_buffer <= rom_do;
					state_next <= 4'd9;
					state <= 4'd1;
				end
				4'd9: begin
					if (fix_sc_cs)
						audio_buffer <= cs_array[page_position[4:0]];
					else
						audio_buffer <= rom_do;
					bank_a <= 0;
					state_next <= 4'd10;
					state <= 4'd1;
				end
				4'd10: begin
					audio_buffer <= rom_do;
					if (&bank_a) begin
						page_position <= page_position + 1'd1;
						state_next <= ((page_position == (page_count - 1'd1)) || (page_position == 23) ? 4'd11 : 4'd8);
					end
					else
						state_next <= 4'd10;
					bank_a <= bank_a + 1'd1;
					state <= 4'd1;
				end
				4'd11: begin
					audio_buffer <= 8'd0;
					state_count <= state_count + 1'd1;
					state <= 4'd1;
					state_next <= (&state_count[8:0] ? 4'd12 : 4'd11);
					if (&state_count[8:0]) begin
						cooldown <= COOLDOWN_PERIOD;
						tape_num <= tape_num + 1'd1;
					end
				end
				4'd12: begin
					playback <= 0;
					pre_fetch_byte <= 0;
					audio_buffer <= 0;
					audio_data <= 0;
				end
			endcase
		end
		if (a_change) begin
			we_cycle <= {we_cycle[4:0], 1'b0};
			if (adata_select && ~playback) begin
				if (|cooldown)
					cooldown <= cooldown - 1'd1;
				else if (~adc_load)
					state <= 4'd0;
			end
			if (a_in == 13'h1ff8) begin
				bank <= we_byte[4:2];
				ram_we <= we_byte[1];
				we_cycle <= 1'sb0;
			end
			if ((a_in[12] && ~|a_in[11:8]) && (~|we_cycle[4:0] || ~ram_we)) begin
				we_cycle <= 5'd1;
				we_byte <= a_in[7:0];
			end
		end
		if (reset) begin
			tape_num <= 0;
			cooldown <= COOLDOWN_PERIOD;
			audio_data <= 0;
			state <= 4'd12;
			state_next <= 4'd12;
			bank <= 0;
			ram_we <= 0;
			we_cycle <= 1'sb0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
