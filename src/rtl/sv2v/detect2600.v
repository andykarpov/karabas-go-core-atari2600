module detect2600 (
	clk,
	load_start,
	load_addr,
	load_valid,
	load_end,
	cart_size,
	data,
	force_bs,
	sc,
	mapper_revision,
	cdf_ldx,
	cdf_ldy,
	cdf_fetch_offset_enable,
	cdf_fetch_offset,
	cdfj_entry,
	cdfj_stack,
	arm_audio_size_addr
);
	input clk;
	input load_start;
	input [24:0] load_addr;
	input load_valid;
	input load_end;
	input [31:0] cart_size;
	input [7:0] data;
	output reg [5:0] force_bs;
	output reg sc;
	output reg [2:0] mapper_revision;
	output reg cdf_ldx;
	output reg cdf_ldy;
	output reg cdf_fetch_offset_enable;
	output reg [7:0] cdf_fetch_offset;
	output reg [31:0] cdfj_entry;
	output reg [31:0] cdfj_stack;
	output reg [15:0] arm_audio_size_addr;
	wire reset = load_start;
	wire [24:0] addr = load_addr;
	wire enable = load_valid;
	wire hasMatch3F;
	wire hasMatchBUS;
	reg [31:0] elf_window;
	reg elf_magic;
	reg elf_endian;
	reg elf_type;
	reg elf_machine;
	reg [31:0] revision_window;
	reg [31:0] revision_word_1;
	reg [31:0] revision_word_2;
	reg [2:0] cdf0_count;
	reg [2:0] cdf1_count;
	reg [2:0] cdfj_count;
	reg cdfj_plus;
	reg bus_word_seen;
	reg [1:0] bus_revision;
	reg [31:0] dpc_driver_crc;
	reg audio_size_scan;
	reg [4:0] audio_size_words;
	reg [31:0] fa2_loader_window;
	reg fa2_loader;
	reg fa2_padding_zero;
	wire [31:0] next_revision_window = (load_addr[1:0] == 2'd0 ? {24'b000000000000000000000000, data} : (load_addr[1:0] == 2'd1 ? {16'b0000000000000000, data, revision_window[7:0]} : (load_addr[1:0] == 2'd2 ? {8'b00000000, data, revision_window[15:0]} : {data, revision_window[23:0]})));
	wire [31:0] next_elf_window = {elf_window[23:0], data};
	wire [31:0] next_fa2_loader_window = (load_start ? {24'd0, data} : {fa2_loader_window[23:0], data});
	wire hasMatchELF = ((((cart_size >= 32'd52) && elf_magic) && elf_endian) && elf_type) && elf_machine;
	wire cdf_size = ((((cart_size == 32'd32768) || (cart_size == 32'd65536)) || (cart_size == 32'd131072)) || (cart_size == 32'd262144)) || (cart_size == 32'd524288);
	wire hasMatchDEVC;
	always @(posedge clk) begin
		if (load_start) begin
			fa2_loader_window <= 1'sb0;
			fa2_loader <= 1'b0;
			fa2_padding_zero <= 1'b1;
		end
		if (load_valid) begin
			fa2_loader_window <= next_fa2_loader_window;
			if ((load_addr < 25'd1024) && ((next_fa2_loader_window == 32'ha0c11fe0) || (next_fa2_loader_window == 32'h008002e0)))
				fa2_loader <= 1'b1;
			if (((load_addr >= 25'd29696) && (load_addr < 25'd32768)) && (data != 8'd0))
				fa2_padding_zero <= 1'b0;
		end
	end
	always @(posedge clk) begin
		if (load_start) begin
			elf_window <= 1'sb0;
			elf_magic <= 1'b0;
			elf_endian <= 1'b0;
			elf_type <= 1'b0;
			elf_machine <= 1'b0;
		end
		if (load_valid) begin
			elf_window <= (load_start ? {24'd0, data} : next_elf_window);
			if ((load_addr <= 25'd7) && (next_elf_window == 32'h7f454c46))
				elf_magic <= 1'b1;
			if (load_addr == 25'h0000005)
				elf_endian <= data == 8'h01;
			if (load_addr == 25'h0000010)
				elf_type <= data == 8'h01;
			if (load_addr == 25'h0000012)
				elf_machine <= data == 8'h28;
		end
	end
	function [31:0] nextCRC32_D8;
		input [7:0] Data;
		input [31:0] crc;
		reg [7:0] d;
		reg [31:0] c;
		reg [31:0] newcrc;
		begin
			d = Data;
			c = crc;
			newcrc[0] = ((d[6] ^ d[0]) ^ c[24]) ^ c[30];
			newcrc[1] = ((((((d[7] ^ d[6]) ^ d[1]) ^ d[0]) ^ c[24]) ^ c[25]) ^ c[30]) ^ c[31];
			newcrc[2] = ((((((((d[7] ^ d[6]) ^ d[2]) ^ d[1]) ^ d[0]) ^ c[24]) ^ c[25]) ^ c[26]) ^ c[30]) ^ c[31];
			newcrc[3] = ((((((d[7] ^ d[3]) ^ d[2]) ^ d[1]) ^ c[25]) ^ c[26]) ^ c[27]) ^ c[31];
			newcrc[4] = ((((((((d[6] ^ d[4]) ^ d[3]) ^ d[2]) ^ d[0]) ^ c[24]) ^ c[26]) ^ c[27]) ^ c[28]) ^ c[30];
			newcrc[5] = ((((((((((((d[7] ^ d[6]) ^ d[5]) ^ d[4]) ^ d[3]) ^ d[1]) ^ d[0]) ^ c[24]) ^ c[25]) ^ c[27]) ^ c[28]) ^ c[29]) ^ c[30]) ^ c[31];
			newcrc[6] = ((((((((((d[7] ^ d[6]) ^ d[5]) ^ d[4]) ^ d[2]) ^ d[1]) ^ c[25]) ^ c[26]) ^ c[28]) ^ c[29]) ^ c[30]) ^ c[31];
			newcrc[7] = ((((((((d[7] ^ d[5]) ^ d[3]) ^ d[2]) ^ d[0]) ^ c[24]) ^ c[26]) ^ c[27]) ^ c[29]) ^ c[31];
			newcrc[8] = (((((((d[4] ^ d[3]) ^ d[1]) ^ d[0]) ^ c[0]) ^ c[24]) ^ c[25]) ^ c[27]) ^ c[28];
			newcrc[9] = (((((((d[5] ^ d[4]) ^ d[2]) ^ d[1]) ^ c[1]) ^ c[25]) ^ c[26]) ^ c[28]) ^ c[29];
			newcrc[10] = (((((((d[5] ^ d[3]) ^ d[2]) ^ d[0]) ^ c[2]) ^ c[24]) ^ c[26]) ^ c[27]) ^ c[29];
			newcrc[11] = (((((((d[4] ^ d[3]) ^ d[1]) ^ d[0]) ^ c[3]) ^ c[24]) ^ c[25]) ^ c[27]) ^ c[28];
			newcrc[12] = (((((((((((d[6] ^ d[5]) ^ d[4]) ^ d[2]) ^ d[1]) ^ d[0]) ^ c[4]) ^ c[24]) ^ c[25]) ^ c[26]) ^ c[28]) ^ c[29]) ^ c[30];
			newcrc[13] = (((((((((((d[7] ^ d[6]) ^ d[5]) ^ d[3]) ^ d[2]) ^ d[1]) ^ c[5]) ^ c[25]) ^ c[26]) ^ c[27]) ^ c[29]) ^ c[30]) ^ c[31];
			newcrc[14] = (((((((((d[7] ^ d[6]) ^ d[4]) ^ d[3]) ^ d[2]) ^ c[6]) ^ c[26]) ^ c[27]) ^ c[28]) ^ c[30]) ^ c[31];
			newcrc[15] = (((((((d[7] ^ d[5]) ^ d[4]) ^ d[3]) ^ c[7]) ^ c[27]) ^ c[28]) ^ c[29]) ^ c[31];
			newcrc[16] = (((((d[5] ^ d[4]) ^ d[0]) ^ c[8]) ^ c[24]) ^ c[28]) ^ c[29];
			newcrc[17] = (((((d[6] ^ d[5]) ^ d[1]) ^ c[9]) ^ c[25]) ^ c[29]) ^ c[30];
			newcrc[18] = (((((d[7] ^ d[6]) ^ d[2]) ^ c[10]) ^ c[26]) ^ c[30]) ^ c[31];
			newcrc[19] = (((d[7] ^ d[3]) ^ c[11]) ^ c[27]) ^ c[31];
			newcrc[20] = (d[4] ^ c[12]) ^ c[28];
			newcrc[21] = (d[5] ^ c[13]) ^ c[29];
			newcrc[22] = (d[0] ^ c[14]) ^ c[24];
			newcrc[23] = (((((d[6] ^ d[1]) ^ d[0]) ^ c[15]) ^ c[24]) ^ c[25]) ^ c[30];
			newcrc[24] = (((((d[7] ^ d[2]) ^ d[1]) ^ c[16]) ^ c[25]) ^ c[26]) ^ c[31];
			newcrc[25] = (((d[3] ^ d[2]) ^ c[17]) ^ c[26]) ^ c[27];
			newcrc[26] = (((((((d[6] ^ d[4]) ^ d[3]) ^ d[0]) ^ c[18]) ^ c[24]) ^ c[27]) ^ c[28]) ^ c[30];
			newcrc[27] = (((((((d[7] ^ d[5]) ^ d[4]) ^ d[1]) ^ c[19]) ^ c[25]) ^ c[28]) ^ c[29]) ^ c[31];
			newcrc[28] = (((((d[6] ^ d[5]) ^ d[2]) ^ c[20]) ^ c[26]) ^ c[29]) ^ c[30];
			newcrc[29] = (((((d[7] ^ d[6]) ^ d[3]) ^ c[21]) ^ c[27]) ^ c[30]) ^ c[31];
			newcrc[30] = (((d[7] ^ d[4]) ^ c[22]) ^ c[28]) ^ c[31];
			newcrc[31] = (d[5] ^ c[23]) ^ c[29];
			nextCRC32_D8 = newcrc;
		end
	endfunction
	always @(posedge clk) begin
		if (load_start) begin
			revision_window <= 1'sb0;
			revision_word_1 <= 1'sb0;
			revision_word_2 <= 1'sb0;
			cdf0_count <= 1'sb0;
			cdf1_count <= 1'sb0;
			cdfj_count <= 1'sb0;
			cdfj_plus <= 1'b0;
			bus_word_seen <= 1'b0;
			bus_revision <= 2'd0;
			dpc_driver_crc <= 1'sb0;
			cdf_ldx <= 1'b0;
			cdf_ldy <= 1'b0;
			cdf_fetch_offset_enable <= 1'b0;
			cdf_fetch_offset <= 8'b00000000;
			cdfj_entry <= 32'b00000000000000000000000000000000;
			cdfj_stack <= 32'b00000000000000000000000000000000;
			arm_audio_size_addr <= 16'b0000000000000000;
			audio_size_scan <= 1'b0;
			audio_size_words <= 5'b00000;
		end
		if (load_valid) begin
			revision_window <= next_revision_window;
			if (load_addr < 25'd3072)
				dpc_driver_crc <= nextCRC32_D8(data, (load_start ? 32'b00000000000000000000000000000000 : dpc_driver_crc));
			if ((load_addr[1:0] == 2'b11) && (load_addr < 25'd3072)) begin
				revision_word_2 <= revision_word_1;
				revision_word_1 <= next_revision_window;
				if (next_revision_window == 32'he3c55d3e) begin
					audio_size_scan <= 1'b1;
					audio_size_words <= 5'd20;
				end
				else if (audio_size_scan) begin
					if (next_revision_window[31:16] == 16'h4000) begin
						arm_audio_size_addr <= next_revision_window[15:0];
						audio_size_scan <= 1'b0;
					end
					else if (audio_size_words == 5'd1)
						audio_size_scan <= 1'b0;
					else
						audio_size_words <= audio_size_words - 5'd1;
				end
				if (load_addr < 25'd2048) begin
					if (next_revision_window == 32'h135200a2)
						cdf_ldx <= 1'b1;
					if (next_revision_window == 32'h135200a0)
						cdf_ldy <= 1'b1;
					if ((next_revision_window & 32'hffffff00) == 32'he2422000) begin
						cdf_fetch_offset_enable <= 1'b1;
						cdf_fetch_offset <= next_revision_window[7:0];
					end
					if ((next_revision_window == 32'h00464443) && (cdf0_count < 3))
						cdf0_count <= cdf0_count + 3'd1;
					else if ((next_revision_window == 32'h4a464443) && (cdfj_count < 3))
						cdfj_count <= cdfj_count + 3'd1;
					else if ((((next_revision_window[23:0] == 24'h464443) && (next_revision_window[31:24] != 8'h00)) && (next_revision_window[31:24] != 8'h4a)) && (cdf1_count < 3))
						cdf1_count <= cdf1_count + 3'd1;
					if (((revision_word_2 == 32'h53554c50) && (revision_word_1 == 32'h4a464443)) && (next_revision_window == 32'h00000001))
						cdfj_plus <= 1'b1;
				end
				if (!bus_word_seen && (next_revision_window == 32'h00535542)) begin
					bus_word_seen <= 1'b1;
					case (load_addr - 25'd3)
						25'h00007f4: bus_revision <= 2'd1;
						25'h0000778: bus_revision <= 2'd2;
						25'h0000770: bus_revision <= 2'd3;
						default: bus_revision <= 2'd0;
					endcase
				end
			end
			if (load_addr[1:0] == 2'b11) begin
				if ((load_addr - 25'd3) == 25'h00017f4)
					cdfj_stack <= next_revision_window;
				if ((load_addr - 25'd3) == 25'h00017f8)
					cdfj_entry <= next_revision_window & 32'hfffffffe;
			end
		end
	end
	wire hasMatch0840_0;
	wire hasMatch0840_1;
	wire hasMatch0840_2;
	wire hasMatch0840_3;
	wire hasMatch0840_4;
	wire hasMatch0840 = (((hasMatch0840_0 | hasMatch0840_1) | hasMatch0840_2) | hasMatch0840_3) | hasMatch0840_4;
	wire hasMatch3E_1;
	wire hasMatch3E = hasMatch3E_1 & hasMatch3F;
	wire hasMatchCDF_1;
	wire hasMatchCDF_2;
	wire hasMatchCDF = hasMatchCDF_1 | hasMatchCDF_2;
	wire hasMatchCTY;
	wire hasMatchCV_0;
	wire hasMatchCV_1;
	wire hasMatchCV = hasMatchCV_0 | hasMatchCV_1;
	wire hasMatchDPCP;
	wire hasMatchE0_0;
	wire hasMatchE0_1;
	wire hasMatchE0_2;
	wire hasMatchE0_3;
	wire hasMatchE0_4;
	wire hasMatchE0_5;
	wire hasMatchE0_6;
	wire hasMatchE0_7;
	wire hasMatchE0 = ((((((hasMatchE0_0 | hasMatchE0_1) | hasMatchE0_2) | hasMatchE0_3) | hasMatchE0_4) | hasMatchE0_5) | hasMatchE0_6) | hasMatchE0_7;
	wire hasMatchE7_0;
	wire hasMatchE7_1;
	wire hasMatchE7_2;
	wire hasMatchE7_3;
	wire hasMatchE7_4;
	wire hasMatchE7_5;
	wire hasMatchE7_6;
	wire hasMatchE7 = (((((hasMatchE7_0 | hasMatchE7_1) | hasMatchE7_2) | hasMatchE7_3) | hasMatchE7_4) | hasMatchE7_5) | hasMatchE7_6;
	wire hasMatchEF_0;
	wire hasMatchEF_1;
	wire hasMatchEF_2;
	wire hasMatchEF_3;
	wire hasMatchEF = ((hasMatchEF_0 | hasMatchEF_1) | hasMatchEF_2) | hasMatchEF_3;
	wire hasMatchFC_0;
	wire hasMatchFC_1;
	wire hasMatchFC_2;
	wire hasMatchFC = (hasMatchFC_0 | hasMatchFC_1) | hasMatchFC_2;
	wire hasMatchF8_0;
	wire hasMatchF8_1;
	wire hasMatchF8 = hasMatchF8_0 | hasMatchF8_1;
	wire hasMatchFE_0;
	wire hasMatchFE_1;
	wire hasMatchFE_2;
	wire hasMatchFE_3;
	wire hasMatchFE = ~hasMatchF8 && (((hasMatchFE_0 | hasMatchFE_1) | hasMatchFE_2) | hasMatchFE_3);
	wire hasMatchJANE;
	wire hasMatchSB_1;
	wire hasMatchSB_2;
	wire hasMatchSB = hasMatchSB_1 | hasMatchSB_2;
	wire hasMatchUA_0;
	wire hasMatchUA_1;
	wire hasMatchUA_10;
	wire hasMatchUA_11;
	wire hasMatchUA_2;
	wire hasMatchUA_3;
	wire hasMatchUA_4;
	wire hasMatchUA_5;
	wire hasMatchUA_6;
	wire hasMatchUA_7;
	wire hasMatchUA_8;
	wire hasMatchUA_9;
	wire hasMatchUA = ((((((((((hasMatchUA_0 | hasMatchUA_1) | hasMatchUA_2) | hasMatchUA_3) | hasMatchUA_4) | hasMatchUA_5) | hasMatchUA_6) | hasMatchUA_7) | hasMatchUA_8) | hasMatchUA_9) | hasMatchUA_10) | hasMatchUA_11;
	wire hasMatchWD;
	reg has_sc;
	reg sc4k_sig;
	reg tail_dfbf;
	reg tail_dfbf_sc;
	wire ua_mickey = hasMatchUA_5 & ~((((((((((hasMatchUA_0 | hasMatchUA_1) | hasMatchUA_2) | hasMatchUA_3) | hasMatchUA_4) | hasMatchUA_6) | hasMatchUA_7) | hasMatchUA_8) | hasMatchUA_9) | hasMatchUA_10) | hasMatchUA_11);
	always @(posedge clk)
		if (load_start) begin
			force_bs <= 6'd0;
			sc <= 1'b0;
			mapper_revision <= 3'd0;
		end
		else if (load_end) begin
			sc <= 1'b0;
			mapper_revision <= 3'd0;
			if (hasMatchELF)
				force_bs <= 6'd32;
			else if (((cart_size == 'd24576) || (cart_size == 'd28672)) && !hasMatchDEVC)
				force_bs <= 6'd25;
			else if (cart_size == 'd29696)
				force_bs <= (fa2_loader ? 6'd25 : 6'd21);
			else if (hasMatchCTY && ((cart_size == 'd32768) || (cart_size == 'd61440)))
				force_bs <= 6'd22;
			else if (hasMatchCDF && cdf_size) begin
				force_bs <= 6'd23;
				mapper_revision <= (cdfj_plus ? 3'd3 : (cdfj_count >= 3 ? 3'd2 : (cdf0_count >= 3 ? 3'd0 : 3'd1)));
			end
			else if (hasMatchDPCP && (cart_size == 'd32768)) begin
				force_bs <= 6'd21;
				mapper_revision <= (dpc_driver_crc == 32'ha08cfb13 ? 3'd1 : 3'd0);
			end
			else if ((cart_size == 'd32768) && has_sc) begin
				force_bs <= 6'd6;
				sc <= 1'b1;
			end
			else if (hasMatchFE && (cart_size == 'd8192))
				force_bs <= 6'd3;
			else if (hasMatchE0 && (cart_size == 'd8192))
				force_bs <= 6'd4;
			else if (hasMatch3E && (cart_size > 'd4096))
				force_bs <= 6'd16;
			else if (hasMatch3F && (cart_size > 'd4096))
				force_bs <= 6'd5;
			else if (hasMatchBUS && (cart_size == 'd32768)) begin
				force_bs <= 6'd24;
				mapper_revision <= {1'b0, bus_revision};
			end
			else if (((cart_size == 'd32768) && fa2_padding_zero) && !has_sc)
				force_bs <= 6'd25;
			else if (((cart_size == 'd131072) || (cart_size == 'd262144)) && tail_dfbf) begin
				force_bs <= 6'd28;
				sc <= tail_dfbf_sc;
			end
			else if (hasMatchSB && (cart_size >= 'd131072))
				force_bs <= 6'd17;
			else if (hasMatchEF && (cart_size == 'd65536)) begin
				force_bs <= 6'd19;
				sc <= has_sc;
			end
			else if (hasMatchCV)
				force_bs <= 6'd9;
			else if (hasMatchJANE && (cart_size == 'd16384))
				force_bs <= 6'd20;
			else if (hasMatchE7)
				force_bs <= 6'd12;
			else if (cart_size == 'h2003) begin
				force_bs <= 6'd18;
				mapper_revision <= 3'd1;
			end
			else if ((cart_size == 'h2000) && hasMatchWD)
				force_bs <= 6'd18;
			else if ((cart_size == 'h2000) && hasMatchUA) begin
				force_bs <= 6'd11;
				mapper_revision <= {2'd0, ua_mickey};
			end
			else if ((cart_size == 'h2000) && hasMatch0840)
				force_bs <= 6'd26;
			else if ((cart_size == 'h2000) && hasMatchFC)
				force_bs <= 6'd27;
			else if (cart_size == 'h1800)
				force_bs <= 6'd15;
			else if (cart_size == 'h2100)
				force_bs <= 6'd15;
			else if (cart_size == 'h4200)
				force_bs <= 6'd15;
			else if (cart_size == 'h6300)
				force_bs <= 6'd15;
			else if (cart_size == 'h8400)
				force_bs <= 6'd15;
			else if (cart_size <= 'h800)
				force_bs <= 6'd10;
			else if (cart_size <= 'h1000) begin
				if (has_sc && sc4k_sig) begin
					force_bs <= 6'd0;
					sc <= 1'b1;
				end
				else
					force_bs <= (hasMatchFC ? 6'd27 : 6'd0);
			end
			else if (cart_size <= 'h2000) begin
				force_bs <= 6'd1;
				sc <= has_sc;
			end
			else if ((cart_size >= 'h2800) && (cart_size <= 'h2900))
				force_bs <= 6'd7;
			else if (cart_size <= 'h3000)
				force_bs <= 6'd8;
			else if ((cart_size == 'h4000) && hasMatchFC)
				force_bs <= 6'd27;
			else if (cart_size <= 'h4000) begin
				force_bs <= 6'd2;
				sc <= has_sc;
			end
			else if ((cart_size == 'h8000) && hasMatchFC)
				force_bs <= 6'd27;
			else if (cart_size <= 'h8000) begin
				force_bs <= 6'd6;
				sc <= has_sc;
			end
			else if (cart_size < 'h10000)
				force_bs <= 6'd14;
			else if (cart_size == 'h10000)
				force_bs <= 6'd13;
			else
				force_bs <= 0;
		end
	reg [63:0] match_stream;
	reg [24:0] match_last_addr;
	reg match_have_addr;
	wire match_contiguous = match_have_addr && (addr == (match_last_addr + 25'd1));
	wire [63:0] match_next = (match_contiguous && !reset ? {match_stream[55:0], data} : {56'b00000000000000000000000000000000000000000000000000000000, data});
	always @(posedge clk) begin
		if (reset) begin
			match_stream <= 1'sb0;
			match_last_addr <= 1'sb0;
			match_have_addr <= 1'b0;
		end
		if (enable) begin
			match_stream <= match_next;
			match_last_addr <= addr;
			match_have_addr <= 1'b1;
		end
	end
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h0ce0ff),
		.needmatches(8'd1)
	) match_bytes_EF_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchEF_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade0ff),
		.needmatches(8'd1)
	) match_bytes_EF_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchEF_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h0ce01f),
		.needmatches(8'd1)
	) match_bytes_EF_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchEF_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade01f),
		.needmatches(8'd1)
	) match_bytes_EF_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchEF_3)
	);
	match_bytes #(
		.num_bytes(8'd4),
		.pattern(32'ha9fd8508),
		.needmatches(8'd1)
	) match_bytes_DEVC(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchDEVC)
	);
	match_bytes #(
		.num_bytes(8'd4),
		.pattern(32'h4450432b),
		.needmatches(8'd2)
	) match_bytes_DPCP(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchDPCP)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h425553),
		.needmatches(8'd2)
	) match_bytes_BUS(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchBUS)
	);
	match_bytes #(
		.num_bytes(8'd5),
		.pattern(40'h4c454e494e),
		.needmatches(8'd1)
	) match_bytes_CTY(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchCTY)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h434446),
		.needmatches(8'd3)
	) match_bytes_CDF_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchCDF_1)
	);
	match_bytes #(
		.num_bytes(8'd8),
		.pattern(64'h504c55534344464a),
		.needmatches(8'd1)
	) match_bytes_CDF_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchCDF_2)
	);
	match_bytes #(
		.num_bytes(8'd2),
		.pattern(16'h853f),
		.needmatches(8'd2)
	) match_bytes_3F(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch3F)
	);
	match_bytes #(
		.num_bytes(8'd2),
		.pattern(16'h853e),
		.needmatches(8'd1)
	) match_bytes_3E_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch3E_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'ha5394c),
		.needmatches(8'd1)
	) match_bytes_WD_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchWD)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hbd0008),
		.needmatches(8'd1)
	) match_bytes_SB_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchSB_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'had0008),
		.needmatches(8'd1)
	) match_bytes_SB_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchSB_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade2ff),
		.needmatches(8'd1)
	) match_bytes_E7_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade5ff),
		.needmatches(8'd1)
	) match_bytes_E7_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade51f),
		.needmatches(8'd1)
	) match_bytes_E7_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade71f),
		.needmatches(8'd1)
	) match_bytes_E7_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_3)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h0ce71f),
		.needmatches(8'd1)
	) match_bytes_E7_4(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_4)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8de7ff),
		.needmatches(8'd1)
	) match_bytes_E7_5(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_5)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade71f),
		.needmatches(8'd1)
	) match_bytes_E7_6(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE7_6)
	);
	match_bytes #(
		.num_bytes(8'd4),
		.pattern(32'hadf1ff60),
		.needmatches(8'd1)
	) match_bytes_JANE(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchJANE)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8de01f),
		.needmatches(8'd1)
	) match_bytes_E0_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8de05f),
		.needmatches(8'd1)
	) match_bytes_E0_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8de9ff),
		.needmatches(8'd1)
	) match_bytes_E0_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h0ce01f),
		.needmatches(8'd1)
	) match_bytes_E0_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_3)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade01f),
		.needmatches(8'd1)
	) match_bytes_E0_4(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_4)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hade9ff),
		.needmatches(8'd1)
	) match_bytes_E0_5(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_5)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hadedff),
		.needmatches(8'd1)
	) match_bytes_E0_6(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_6)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hadf3bf),
		.needmatches(8'd1)
	) match_bytes_E0_7(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchE0_7)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8df91f),
		.needmatches(8'd2)
	) match_bytes_F8_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchF8_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8df9ff),
		.needmatches(8'd2)
	) match_bytes_F8_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchF8_1)
	);
	match_bytes #(
		.num_bytes(8'd5),
		.pattern(40'h2000d0c6c5),
		.needmatches(8'd1)
	) match_bytes_FE_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFE_0)
	);
	match_bytes #(
		.num_bytes(8'd5),
		.pattern(40'h20c3f8a582),
		.needmatches(8'd1)
	) match_bytes_FE_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFE_1)
	);
	match_bytes #(
		.num_bytes(8'd5),
		.pattern(40'hd0fb2073fe),
		.needmatches(8'd1)
	) match_bytes_FE_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFE_2)
	);
	match_bytes #(
		.num_bytes(8'd5),
		.pattern(40'h2000f084d6),
		.needmatches(8'd1)
	) match_bytes_FE_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFE_3)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h9dfff3),
		.needmatches(8'd1)
	) match_bytes_CV_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchCV_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h9900f4),
		.needmatches(8'd1)
	) match_bytes_CV_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchCV_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'had0008),
		.needmatches(8'd2)
	) match_bytes_0840_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch0840_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'had4008),
		.needmatches(8'd2)
	) match_bytes_0840_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch0840_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2c0008),
		.needmatches(8'd2)
	) match_bytes_0840_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch0840_2)
	);
	match_bytes #(
		.num_bytes(8'd4),
		.pattern(32'h0c00084c),
		.needmatches(8'd2)
	) match_bytes_0840_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch0840_3)
	);
	match_bytes #(
		.num_bytes(8'd4),
		.pattern(32'h0cff0f4c),
		.needmatches(8'd2)
	) match_bytes_0840_4(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatch0840_4)
	);
	match_bytes #(
		.num_bytes(8'd6),
		.pattern(48'h8df81f4a4a8d),
		.needmatches(8'd1)
	) match_bytes_FC_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFC_0)
	);
	match_bytes #(
		.num_bytes(8'd6),
		.pattern(48'h8df8ff8dfcff),
		.needmatches(8'd1)
	) match_bytes_FC_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFC_1)
	);
	match_bytes #(
		.num_bytes(8'd6),
		.pattern(48'h8cf9ffadfcff),
		.needmatches(8'd1)
	) match_bytes_FC_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchFC_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8d4002),
		.needmatches(8'd1)
	) match_bytes_UA_0(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_0)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'had4002),
		.needmatches(8'd1)
	) match_bytes_UA_1(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_1)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hbd1f02),
		.needmatches(8'd1)
	) match_bytes_UA_2(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_2)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2cc002),
		.needmatches(8'd1)
	) match_bytes_UA_3(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_3)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8dc002),
		.needmatches(8'd1)
	) match_bytes_UA_4(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_4)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hadc002),
		.needmatches(8'd1)
	) match_bytes_UA_5(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_5)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2cc00f),
		.needmatches(8'd1)
	) match_bytes_UA_6(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_6)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2cb00f),
		.needmatches(8'd1)
	) match_bytes_UA_7(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_7)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2cc00f),
		.needmatches(8'd1)
	) match_bytes_UA_8(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_8)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h8dc00f),
		.needmatches(8'd1)
	) match_bytes_UA_9(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_9)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'hadc00f),
		.needmatches(8'd1)
	) match_bytes_UA_10(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_10)
	);
	match_bytes #(
		.num_bytes(8'd3),
		.pattern(24'h2cc0ef),
		.needmatches(8'd1)
	) match_bytes_UA_11(
		.enable(enable),
		.clk(clk),
		.reset(reset),
		.stream(match_next),
		.hasMatch(hasMatchUA_11)
	);
	reg [31:0] sc_crc0;
	reg [31:0] sc_crc1;
	wire [31:0] tail_word = match_next[31:0];
	wire tail_zone = (load_addr + 25'd5) >= cart_size[24:0];
	always @(posedge clk)
		if (load_start) begin
			tail_dfbf <= 1'b0;
			tail_dfbf_sc <= 1'b0;
			sc4k_sig <= 1'b0;
		end
		else if (enable) begin
			if (tail_zone && ((tail_word == "DFDF") || (tail_word == "BFBF")))
				tail_dfbf <= 1'b1;
			if (tail_zone && ((tail_word == "DFSC") || (tail_word == "BFSC"))) begin
				tail_dfbf <= 1'b1;
				tail_dfbf_sc <= 1'b1;
			end
			if ((load_addr == 25'h0000ffb) && (match_next[15:0] == "SC"))
				sc4k_sig <= 1'b1;
		end
	wire [11:0] sc_offset = load_addr[11:0];
	wire sc_enable = load_valid;
	always @(posedge clk) begin
		if (load_start) begin
			sc_crc0 <= 32'b00000000000000000000000000000000;
			sc_crc1 <= 32'b00000000000000000000000000000000;
			has_sc <= 1'b1;
		end
		if (sc_enable) begin
			if (sc_offset < 12'h080)
				sc_crc0 <= nextCRC32_D8(data, (load_start || (sc_offset == 12'h000) ? 32'b00000000000000000000000000000000 : sc_crc0));
			else if (sc_offset < 12'h100)
				sc_crc1 <= nextCRC32_D8(data, (sc_offset == 12'h080 ? 32'b00000000000000000000000000000000 : sc_crc1));
			else if (sc_offset == 12'h100) begin
				if (has_sc)
					has_sc <= sc_crc0 == sc_crc1;
				sc_crc0 <= 32'b00000000000000000000000000000000;
				sc_crc1 <= 32'b00000000000000000000000000000000;
			end
		end
	end
endmodule
