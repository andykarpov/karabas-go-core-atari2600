// SPDX-License-Identifier: MIT
// Copyright (c) 2019-2026 Jamie Blanks
//
// karabas: cart2600 of k7800 (rtl/k7800/cart2600.sv) without the ARM side. The ARM mappers
// (DPC+, CDF, BUS) are not built here: they and ELF show the "Out of Order" screen (ooo.hex).
// Removed: arm_mapper_* / mapper_dpcplus / mapper_cdf / mapper_bus / cdf_fastjump_table, the
// DDR3, ARM bus, state, table and load ports, the audio RAM grant, bus stuffing. FA2 has no
// flash save yet (nvram reads FF, always ready). The mapper part below "// Other?" and the mux
// above the ARM block are the upstream text unchanged.

module cart2600_kg
(
	// Physical Pins
	output logic [7:0]  d_out, // Data bus
	input    [7:0]  d_in,  // Data bus
	input    [12:0] a_in,  // Address bus
	input           rw,

	// Helpers
	input           clk,        // Master Clock
	input           reset,      // System warm reset
	input           ce,         // Original system clock enable (~3.579mhz) used to divide into crystals
	input           phi1,       // CPU Phase 1 Signal (used for FE to catch data at the right moment)
	input           phi2,
	output logic [7:0] oe,      // Which of d_out's lines the cartridge drives

	// Autodetect info
	input           sc,         // Superchip Enable
	input    [5:0]  mapper,     // Bankswitching type (ie Mapper)
	input    [2:0]  mapper_revision,

	// ROM storage interface
	input    [7:0]  rom_do,     // Incoming ROM data
	input   [31:0]  rom_size,   // Full rom size for address masking
	input           load_start, // a new image: the MC mappers restart their game counter
	output  [18:0]  rom_a,      // Outgoing absolute rom address for image.
	output          rom_read,   // Initiate read

	output   [17:0] cartram_addr,
	output          cartram_wr,
	output          cartram_rd,
	output   [7:0]  cartram_wrdata,
	input    [7:0]  cartram_data,

	// Tape Signals
	output          tape_audio, // Tape audio output
	input    [1:0]  tape_in,    // ADC tape input
	input           fix_sc_cs   // Fix Supercharger Checksums menu option
);
	`define NUM_MAPPERS BANKEND

	// Muxxing signals
	logic [18:0] rom_addr[`NUM_MAPPERS];
	logic [7:0] direct_do[`NUM_MAPPERS];
	logic [15:0] flags_out[`NUM_MAPPERS]; // Flag bit 0 is direct_do in use, bit 1 is output enable used;
	logic [7:0]  out_en[`NUM_MAPPERS];
	logic        ram_rw[`NUM_MAPPERS];
	logic        ram_sel[`NUM_MAPPERS];
	logic [17:0] ram_a[`NUM_MAPPERS];
	logic [12:0] old_ain;
	logic [7:0]  bg_data;
	logic        ar_read;
	logic [7:0]  cr_do;


	logic [18:0] sel_rom_addr;
	logic [7:0] sel_direct_do;
	logic [15:0] sel_flags_out;
	logic [7:0]  sel_out_en;
	logic        sel_ram_rw;
	logic        sel_ram_sel;
	logic [17:0] sel_ram_a;
	logic [18:0] rom_mask;

	assign rom_mask = rom_size[18:0] - 1'd1;
	assign rom_read = mapper == BANKAR ? ar_read : ~address_change;
	// karabas: no ARM, so every ARM mapper is a bad game too
	wire is_bad_game = mapper == BANKELF || mapper == BANKBUS ||
		mapper == BANKDPCP || mapper == BANKCDF;

	// Handle unsupportable ARM mappers :(
	spram #(
		.addr_width(11),
		.mem_init_file("ooo.mif"),
		.sim_init_file("rtl/k7800/ooo.hex") // karabas: path from src/
	) badgame_ram
	(
		.clock      (clk),
		.address    (a_in[10:0]),
		.data       (8'd0),
		.wren       (1'b0),
		.cs         (1'b1),
		.q          (bg_data)
	);

	// Flags:
	// bit 0 - direct_do in use
	// bit 1 - bitwise & direct_do and rom_do
	assign sel_flags_out = flags_out[mapper];
	assign sel_direct_do = direct_do[mapper];
	assign sel_out_en = out_en[mapper];
	assign sel_ram_rw = ram_rw[mapper];
	assign sel_ram_sel = ram_sel[mapper];
	assign sel_ram_a = ram_a[mapper];
	// Mappers whose bank register is wider than the cart it is fitted to: a
	// bank number past the end of the image wraps rather than reading nothing.
	assign rom_a = rom_addr[mapper] & ((mapper == BANKE7 || mapper == BANK3F ||
		mapper == BANKSB || mapper == BANK3E || mapper == BANKFC ||
		mapper == BANKDF) ? rom_mask : {19{1'b1}});
	// oe follows whichever branch actually put a byte on d_out, rather than the
	// selected mapper's mask on its own. Two places differ, and both used to
	// hide behind the open_bus default this mux started from:
	//
	//   - a RAM write port answers nothing. The mapper still claims the lines
	//     for the window, but the inner `if (sel_ram_rw)` has no else, so a
	//     write port read left the fallthrough value standing.
	//   - the bad game screen is not a cartridge at all. It drives whatever it
	//     is asked for, and BANKBUS revision 0 reaches it with a mask that goes
	//     low outside the cartridge window.
	//
	// With both stated, nothing reads d_out where oe is clear, and top.sv holds
	// the charge on those lines instead.
	always_comb begin
		d_out = 8'h00;
		oe = 8'h00;
		if (is_bad_game) begin
			d_out = bg_data;
			oe = 8'hFF;
		end else if (|sel_out_en) begin
			if (sel_flags_out[0]) begin
				d_out = sel_direct_do;
				oe = sel_out_en;
			end else if (sel_flags_out[1]) begin
				d_out = (sel_direct_do & rom_do);
				oe = sel_out_en;
			end else if (sel_ram_sel) begin
				if (sel_ram_rw) begin
					d_out = cr_do;
					oe = sel_out_en;
				end
			end else begin
				d_out = rom_do;
				oe = sel_out_en;
			end
		end
	end

	// Since atari added no clock signal to the cart slot, for most mappers this will be the
	// primary way that they detected when to take action. The address changes typically
	// occur just before or just after phi2 on a real system. On some 7800 systems, A12 is delayed
	// in an atypical way causing this to trigger incorrectly for some games, however this
	// design does not reproduce that issue.
	wire address_change = old_ain != a_in;

	// High from the clock edge that took this access until the next 6507 cycle
	// starts, which is what closes the cartridge RAM write strobe above. phi1
	// re-arms it, not the address: `STA abs,X` without a page crossing presents
	// one address for two cycles - the mandatory dummy read, then the store - so
	// re-arming on the address alone gave the dummy cycle the only write and
	// dropped the store.
	logic access_taken;
	always @(posedge clk) begin
		if (reset || address_change || phi1)
			access_taken <= 1'b0;
		else if (phi2)
			access_taken <= 1'b1;
	end

	always @(posedge clk) begin :reset_2600_cart
		old_ain <= a_in;
	end

	// Bank CTY is compatible with F4 minus the ARM enhanced music
	mapper_CTY mapper_CTY
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKCTY]),
		.flags_out  (flags_out[BANKCTY]),
		.oe         (out_en[BANKCTY]),
		.ram_sel    (ram_sel[BANKCTY]),
		.ram_rw     (ram_rw[BANKCTY]),
		.ram_a      (ram_a[BANKCTY]),
		.rom_a      (rom_addr[BANKCTY]),
		.ce         (ce),
		.rom_do     (rom_do)
	);


	// karabas: the ARM block is cut; its mapper slots and ELF give the bad game screen.
	logic fa2_nvram_request_raw, fa2_nvram_write_raw, fa2_nvram_dirty_raw;
	logic [7:0] fa2_nvram_addr_raw, fa2_nvram_wdata_raw;
	wire [7:0] fa2_nvram_rdata = 8'hFF;
	wire fa2_nvram_ready = 1'b1;

	assign direct_do[BANKELF]     = bg_data;
	assign flags_out[BANKELF]     = 16'd1;
	assign out_en[BANKELF]        = 8'hFF;
	assign ram_sel[BANKELF]       = 0;
	assign ram_rw[BANKELF]        = 1;
	assign ram_a[BANKELF]         = '0;
	assign rom_addr[BANKELF]      = '0;

	assign direct_do[BANKDPCP]    = bg_data;
	assign flags_out[BANKDPCP]    = 16'd1;
	assign out_en[BANKDPCP]       = 8'hFF;
	assign ram_sel[BANKDPCP]      = 0;
	assign ram_rw[BANKDPCP]       = 1;
	assign ram_a[BANKDPCP]        = '0;
	assign rom_addr[BANKDPCP]     = '0;

	assign direct_do[BANKCDF]     = bg_data;
	assign flags_out[BANKCDF]     = 16'd1;
	assign out_en[BANKCDF]        = 8'hFF;
	assign ram_sel[BANKCDF]       = 0;
	assign ram_rw[BANKCDF]        = 1;
	assign ram_a[BANKCDF]         = '0;
	assign rom_addr[BANKCDF]      = '0;

	assign direct_do[BANKBUS]     = bg_data;
	assign flags_out[BANKBUS]     = 16'd1;
	assign out_en[BANKBUS]        = 8'hFF;
	assign ram_sel[BANKBUS]       = 0;
	assign ram_rw[BANKBUS]        = 1;
	assign ram_a[BANKBUS]         = '0;
	assign rom_addr[BANKBUS]      = '0;

	assign cartram_addr = sel_ram_a;
	// One access, one write (upstream): the strobe stands for most of the 6507 cycle.
	assign cartram_wr = sel_ram_sel && ~sel_ram_rw &&
		~phi1 && ~address_change && ~access_taken;
	assign cartram_rd = sel_ram_sel && sel_ram_rw && ~phi1 && ~address_change;
	assign cartram_wrdata = d_in;
	assign cr_do = cartram_data;

	// Other?
	// SV   -- Spectravideo Compumate (seems useless)
	// 0840 -- Econobanking (can't find any games that use it)
	// MC   -- Megacart (doesn't seem like it works on real hardware, also no games)
	// X07  -- X07 Atariage (seems impossible, also cant find any games with it)
	// 4A50 -- 4A50 (never found a game with this)

	mapper_none mapper_none
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK00]),
		.flags_out  (flags_out[BANK00]),
		.oe         (out_en[BANK00]),
		.ram_sel    (ram_sel[BANK00]),
		.ram_rw     (ram_rw[BANK00]),
		.ram_a      (ram_a[BANK00]),
		.rom_a      (rom_addr[BANK00])
	);

	mapper_F8 mapper_F8
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKF8]),
		.flags_out  (flags_out[BANKF8]),
		.oe         (out_en[BANKF8]),
		.ram_sel    (ram_sel[BANKF8]),
		.ram_rw     (ram_rw[BANKF8]),
		.ram_a      (ram_a[BANKF8]),
		.rom_a      (rom_addr[BANKF8])
	);

	mapper_F6 mapper_F6
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKF6]),
		.flags_out  (flags_out[BANKF6]),
		.oe         (out_en[BANKF6]),
		.ram_sel    (ram_sel[BANKF6]),
		.ram_rw     (ram_rw[BANKF6]),
		.ram_a      (ram_a[BANKF6]),
		.rom_a      (rom_addr[BANKF6])
	);

	mapper_FE mapper_FE
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKFE]),
		.flags_out  (flags_out[BANKFE]),
		.oe         (out_en[BANKFE]),
		.ram_sel    (ram_sel[BANKFE]),
		.ram_rw     (ram_rw[BANKFE]),
		.ram_a      (ram_a[BANKFE]),
		.rom_a      (rom_addr[BANKFE]),
		.ce         (phi1)
	);

	mapper_E0 mapper_E0
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKE0]),
		.flags_out  (flags_out[BANKE0]),
		.oe         (out_en[BANKE0]),
		.ram_sel    (ram_sel[BANKE0]),
		.ram_rw     (ram_rw[BANKE0]),
		.ram_a      (ram_a[BANKE0]),
		.rom_a      (rom_addr[BANKE0])
	);

	mapper_3F mapper_3F
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK3F]),
		.flags_out  (flags_out[BANK3F]),
		.oe         (out_en[BANK3F]),
		.ram_sel    (ram_sel[BANK3F]),
		.ram_rw     (ram_rw[BANK3F]),
		.ram_a      (ram_a[BANK3F]),
		.rom_a      (rom_addr[BANK3F])
	);

	mapper_F4 mapper_F4
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKF4]),
		.flags_out  (flags_out[BANKF4]),
		.oe         (out_en[BANKF4]),
		.ram_sel    (ram_sel[BANKF4]),
		.ram_rw     (ram_rw[BANKF4]),
		.ram_a      (ram_a[BANKF4]),
		.rom_a      (rom_addr[BANKF4])
	);

	mapper_P2 mapper_P2
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKP2]),
		.flags_out  (flags_out[BANKP2]),
		.oe         (out_en[BANKP2]),
		.ram_sel    (ram_sel[BANKP2]),
		.ram_rw     (ram_rw[BANKP2]),
		.ram_a      (ram_a[BANKP2]),
		.rom_a      (rom_addr[BANKP2]),
		.ce         (ce)
	);

	mapper_FA mapper_FA
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKFA]),
		.flags_out  (flags_out[BANKFA]),
		.oe         (out_en[BANKFA]),
		.ram_sel    (ram_sel[BANKFA]),
		.ram_rw     (ram_rw[BANKFA]),
		.ram_a      (ram_a[BANKFA]),
		.rom_a      (rom_addr[BANKFA])
	);

	mapper_fa2 mapper_FA2
	(
		.clk           (clk),
		.reset         (reset || mapper != BANKFA2),
		.ce            (ce),
		.phi1          (phi1),
		.a_change      (address_change),
		.a_in          (a_in),
		.d_in          (d_in),
		.rom_data      (rom_do),
		.rom_size      (rom_size),
		.d_out         (direct_do[BANKFA2]),
		.flags_out     (flags_out[BANKFA2]),
		.oe            (out_en[BANKFA2]),
		.rom_a         (rom_addr[BANKFA2]),
		.nvram_request (fa2_nvram_request_raw),
		.nvram_write   (fa2_nvram_write_raw),
		.nvram_addr    (fa2_nvram_addr_raw),
		.nvram_wdata   (fa2_nvram_wdata_raw),
		.nvram_rdata   (fa2_nvram_rdata),
		.nvram_ready   (fa2_nvram_ready),
		.nvram_dirty   (fa2_nvram_dirty_raw)
	);
	assign ram_sel[BANKFA2] = 1'b0;
	assign ram_rw[BANKFA2] = 1'b1;
	assign ram_a[BANKFA2] = 18'd0;

	mapper_CV mapper_CV
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKCV]),
		.flags_out  (flags_out[BANKCV]),
		.oe         (out_en[BANKCV]),
		.ram_sel    (ram_sel[BANKCV]),
		.ram_rw     (ram_rw[BANKCV]),
		.ram_a      (ram_a[BANKCV]),
		.rom_a      (rom_addr[BANKCV])
	);

	mapper_2K mapper_2K
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK2K]),
		.flags_out  (flags_out[BANK2K]),
		.oe         (out_en[BANK2K]),
		.ram_sel    (ram_sel[BANK2K]),
		.ram_rw     (ram_rw[BANK2K]),
		.ram_a      (ram_a[BANK2K]),
		.rom_a      (rom_addr[BANK2K])
	);

	mapper_UA mapper_UA
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKUA]),
		.flags_out  (flags_out[BANKUA]),
		.oe         (out_en[BANKUA]),
		.ram_sel    (ram_sel[BANKUA]),
		.ram_rw     (ram_rw[BANKUA]),
		.ram_a      (ram_a[BANKUA]),
		.rom_a      (rom_addr[BANKUA]),
		// UASW (Mickey) swaps the two bank-select addresses. Carried on the
		// revision like DPC+'s stable_fractional; revision 0 is plain UA.
		.swapped    (mapper_revision[0])
	);

	mapper_E7 mapper_E7
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKE7]),
		.flags_out  (flags_out[BANKE7]),
		.oe         (out_en[BANKE7]),
		.ram_sel    (ram_sel[BANKE7]),
		.ram_rw     (ram_rw[BANKE7]),
		.ram_a      (ram_a[BANKE7]),
		.rom_a      (rom_addr[BANKE7])
	);

	mapper_F0 mapper_F0
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKF0]),
		.flags_out  (flags_out[BANKF0]),
		.oe         (out_en[BANKF0]),
		.ram_sel    (ram_sel[BANKF0]),
		.ram_rw     (ram_rw[BANKF0]),
		.ram_a      (ram_a[BANKF0]),
		.rom_a      (rom_addr[BANKF0])
	);

	mapper_32 mapper_32
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK32]),
		.flags_out  (flags_out[BANK32]),
		.oe         (out_en[BANK32]),
		.ram_sel    (ram_sel[BANK32]),
		.ram_rw     (ram_rw[BANK32]),
		.ram_a      (ram_a[BANK32]),
		.rom_a      (rom_addr[BANK32]),
		.cold_reset (mapper != BANK32)
	);

	mapper_AR mapper_AR
	(
		.clk        (clk),
		.reset      (reset || mapper != BANKAR),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKAR]),
		.flags_out  (flags_out[BANKAR]),
		.oe         (out_en[BANKAR]),
		.ram_sel    (ram_sel[BANKAR]),
		.ram_rw     (ram_rw[BANKAR]),
		.ram_a      (ram_a[BANKAR]),
		.rom_a      (rom_addr[BANKAR]),
		.ce         (ce),
		.ar_read    (ar_read),
		.rom_do     (rom_do),
		.rom_size   (rom_size[18:0]),
		.audio_data (tape_audio),
		.tape_in    (tape_in),
		.fix_sc_cs  (fix_sc_cs)
	);

	mapper_WD mapper_WD
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKWD]),
		.flags_out  (flags_out[BANKWD]),
		.oe         (out_en[BANKWD]),
		.ram_sel    (ram_sel[BANKWD]),
		.ram_rw     (ram_rw[BANKWD]),
		.ram_a      (ram_a[BANKWD]),
		.rom_a      (rom_addr[BANKWD]),
		// An 8195-byte dump carries banks 2 and 3 swapped; detect2600 flags it.
		.swapped    (mapper_revision[0])
	);

	mapper_3E mapper_3E
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK3E]),
		.flags_out  (flags_out[BANK3E]),
		.oe         (out_en[BANK3E]),
		.ram_sel    (ram_sel[BANK3E]),
		.ram_rw     (ram_rw[BANK3E]),
		.ram_a      (ram_a[BANK3E]),
		.rom_a      (rom_addr[BANK3E]),
		.rom_size   (rom_size[18:0])
	);

	mapper_SB mapper_SB
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKSB]),
		.flags_out  (flags_out[BANKSB]),
		.oe         (out_en[BANKSB]),
		.ram_sel    (ram_sel[BANKSB]),
		.ram_rw     (ram_rw[BANKSB]),
		.ram_a      (ram_a[BANKSB]),
		.rom_a      (rom_addr[BANKSB])
	);

	mapper_EF mapper_EF
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKEF]),
		.flags_out  (flags_out[BANKEF]),
		.oe         (out_en[BANKEF]),
		.ram_sel    (ram_sel[BANKEF]),
		.ram_rw     (ram_rw[BANKEF]),
		.ram_a      (ram_a[BANKEF]),
		.rom_a      (rom_addr[BANKEF])
	);

	mapper_0840 mapper_0840
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANK0840]),
		.flags_out  (flags_out[BANK0840]),
		.oe         (out_en[BANK0840]),
		.ram_sel    (ram_sel[BANK0840]),
		.ram_rw     (ram_rw[BANK0840]),
		.ram_a      (ram_a[BANK0840]),
		.rom_a      (rom_addr[BANK0840])
	);

	mapper_FC mapper_FC
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKFC]),
		.flags_out  (flags_out[BANKFC]),
		.oe         (out_en[BANKFC]),
		.ram_sel    (ram_sel[BANKFC]),
		.ram_rw     (ram_rw[BANKFC]),
		.ram_a      (ram_a[BANKFC]),
		.rom_a      (rom_addr[BANKFC]),
		.rom_size   (rom_size)
	);

	mapper_DF mapper_DF
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKDF]),
		.flags_out  (flags_out[BANKDF]),
		.oe         (out_en[BANKDF]),
		.ram_sel    (ram_sel[BANKDF]),
		.ram_rw     (ram_rw[BANKDF]),
		.ram_a      (ram_a[BANKDF]),
		.rom_a      (rom_addr[BANKDF]),
		.big        (rom_size[18])
	);

	mapper_MC #(.SLICE(0)) mapper_MC_MC2K
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKMC2K]),
		.flags_out  (flags_out[BANKMC2K]),
		.oe         (out_en[BANKMC2K]),
		.ram_sel    (ram_sel[BANKMC2K]),
		.ram_rw     (ram_rw[BANKMC2K]),
		.ram_a      (ram_a[BANKMC2K]),
		.rom_a      (rom_addr[BANKMC2K]),
		.load_start (load_start),
		.rom_size   (rom_size)
	);

	mapper_MC #(.SLICE(1)) mapper_MC_MC4K
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKMC4K]),
		.flags_out  (flags_out[BANKMC4K]),
		.oe         (out_en[BANKMC4K]),
		.ram_sel    (ram_sel[BANKMC4K]),
		.ram_rw     (ram_rw[BANKMC4K]),
		.ram_a      (ram_a[BANKMC4K]),
		.rom_a      (rom_addr[BANKMC4K]),
		.load_start (load_start),
		.rom_size   (rom_size)
	);

	mapper_MC #(.SLICE(2)) mapper_MC_MC8K
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKMC8K]),
		.flags_out  (flags_out[BANKMC8K]),
		.oe         (out_en[BANKMC8K]),
		.ram_sel    (ram_sel[BANKMC8K]),
		.ram_rw     (ram_rw[BANKMC8K]),
		.ram_a      (ram_a[BANKMC8K]),
		.rom_a      (rom_addr[BANKMC8K]),
		.load_start (load_start),
		.rom_size   (rom_size)
	);

	mapper_JANE mapper_JANE
	(
		.clk        (clk),
		.reset      (reset),
		.a_change   (address_change),
		.sc         (sc),
		.a_in       (a_in),
		.d_in       (d_in),
		.d_out      (direct_do[BANKJANE]),
		.flags_out  (flags_out[BANKJANE]),
		.oe         (out_en[BANKJANE]),
		.ram_sel    (ram_sel[BANKJANE]),
		.ram_rw     (ram_rw[BANKJANE]),
		.ram_a      (ram_a[BANKJANE]),
		.rom_a      (rom_addr[BANKJANE])
	);

endmodule
