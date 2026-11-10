// Atari 2600 VCS machine: 6507 (sally), TIA, RIOT (M6532), cartridge mappers (cart2600_kg) and the
// mapper autodetect (detect2600) of k7800 (Atari7800_MiSTer, Jamie Blanks, MIT), wired as the 2600
// path of its rtl/top.sv: no MARIA, no BIOS, no ARM mappers; the TIA is the only phase source.
// Plain Verilog-2001; the parts come through tools/sv2v.sh (rtl/sv2v/).
//
// Clocks: one clock clk; tia_ce = twice the TIA colour clock (7.16 MHz NTSC / 7.09 PAL, k7800 has
// clk_sys / 2), any duty, one clk wide. Holding tia_ce low stops the whole machine (pause).
// The cartridge ROM and RAM are outside (board SRAM): rom_a / cartram_addr are valid while
// rom_read / cartram_rd are high and the data are read back combinationally or within a few clk
// (k7800 reads its SDRAM the same way), long before the next 6507 cycle.

module atari2600_top
(
	input         clk,
	input         tia_ce,
	input         reset,          // machine reset (power on, F12, new cartridge)

	// cartridge load stream (FL), for the mapper autodetect
	input         load_start,     // a pulse before the first byte
	input  [24:0] load_addr,
	input         load_valid,     // a pulse per byte
	input   [7:0] load_data,
	input         load_end,
	input  [31:0] cart_size,      // bytes of the image
	input   [5:0] mapper_force,   // 0 = the detected one, else a BANK* number of detect2600
	output  [5:0] mapper_detected,
	output  [5:0] mapper,         // in use
	input         cart_present,   // 0: empty slot, reads open bus

	// cartridge ROM (image) and cartridge RAM
	output [18:0] rom_a,
	output        rom_read,
	input   [7:0] rom_do,
	output [17:0] cartram_addr,
	output        cartram_wr,
	output        cartram_rd,
	output  [7:0] cartram_wrdata,
	input   [7:0] cartram_data,

	// video (TIA pixel clock domain = clk with video_ce)
	output        video_ce,
	output  [3:0] col,
	output  [2:0] lum,
	output        hsync,
	output        vsync,
	output        hblank,
	output        vblank,
	input         stabilize,      // TIA video_stabilize: 0 = smart (steady VSYNC / VBLANK), 1 = fixed
	input         decomb,
	output        is_pal,
	output        is_f1,

	// audio: the TIA mix (unsigned, k7800 table), stereo: aud0 left, aud1 right
	input         use_stereo,
	output [15:0] audio_l,
	output [15:0] audio_r,

	// controllers
	input   [7:0] pa_in,          // RIOT port A: joysticks (active low), as the port pins
	output  [7:0] pa_out,
	input   [7:0] pb_in,          // RIOT port B: console switches (active low)
	output  [7:0] pb_out,
	input   [3:0] idump,          // TIA I0..I3: paddle comparators
	output  [3:0] i_out,          // TIA dump transistor (paddles.sv)
	output  [3:0] i_read,
	input   [1:0] ilatch,         // TIA I4, I5: fire buttons (active low)
	input   [1:0] tape_in,        // Supercharger tape (ADC)
	input         fix_sc_cs
);

	// ---- phases: the TIA divider -> 6507 phase pair -> everyone ----
	wire pclk0_t, pclk1_t;        // TIA phase 2 / phase 1 starts
	wire pclk1, pclk0;            // the 6507 phase 1 / phase 2 enables
	reg  in_phase2 = 1'b0;
	assign pclk1 = pclk1_t & ~in_phase2;
	assign pclk0 = pclk0_t &  in_phase2;
	always @(posedge clk)
		if (pclk1) in_phase2 <= 1'b1;
		else if (pclk0) in_phase2 <= 1'b0;

	// The TIA divider stops in reset, the 6507 needs phase enables to see its reset: hold the
	// 6507 (and RIOT, cartridge) for a few cycles after the TIA runs, release on a phase 1.
	reg [2:0] hold_cnt = 3'd0;
	reg       reset_hold = 1'b1;
	always @(posedge clk)
		if (reset) begin
			reset_hold <= 1'b1;
			hold_cnt <= 3'd0;
		end else if (reset_hold && pclk1_t) begin
			if (hold_cnt == 3'd4)
				reset_hold <= 1'b0;
			else
				hold_cnt <= hold_cnt + 3'd1;
		end
	wire cpu_reset = reset | reset_hold;

	// ---- the bus ----
	wire [15:0] cpu_AB;
	wire [7:0]  write_DB;
	wire        cpu_rwn, cpu_DB_oe;
	wire [12:0] AB = cpu_AB[12:0];
	wire        RW = cpu_rwn;
	wire        tia_RDY;
	reg         tia_RDY_seen_high = 1'b1;
	wire        RDY = tia_RDY & tia_RDY_seen_high;

	// In 2600 mode SHB and the CPU phase can land on one clk: release must survive a phase 1
	always @(posedge clk)
		if (cpu_reset)
			tia_RDY_seen_high <= 1'b1;
		else if (!tia_RDY)
			tia_RDY_seen_high <= 1'b0;
		else if (pclk1)
			tia_RDY_seen_high <= 1'b1;

	wire cs_cart = AB[12];
	wire cs_tia  = ~AB[12] & ~AB[7];
	wire cs_riot = ~AB[12] &  AB[7];

	wire [7:0] tia_DB_out, tia_DB_oe, riot_DB_out, riot_DB_oe, cart_DB_out, cart_DB_oe;
	reg  [7:0] open_bus = 8'h00;
	reg  [7:0] read_DB;
	wire [7:0] DB = cpu_DB_oe ? write_DB : read_DB;

	always @(posedge clk)
		open_bus <= DB;

	// a chip drives only the lines of its oe mask, the bus keeps its charge on the rest
	always @* begin
		read_DB = open_bus;
		if (RW) begin
			if (cs_tia)  read_DB = (tia_DB_out  & tia_DB_oe)  | (open_bus & ~tia_DB_oe);
			if (cs_riot) read_DB = (riot_DB_out & riot_DB_oe) | (open_bus & ~riot_DB_oe);
			if (cs_cart && cart_present)
				read_DB = (cart_DB_out & cart_DB_oe) | (open_bus & ~cart_DB_oe);
		end
	end

	// ---- 6507 ----
	sally cpu
	(
		.clk_sys   (clk),
		.phi1_en   (pclk1),
		.phi2_en   (pclk0),
		.res_n     (~cpu_reset),
		.rdy       (RDY),
		.irq_n     (1'b1),
		.nmi_n     (1'b1),
		.so_n      (1'b1),
		.data_in   (cpu_rwn ? read_DB : write_DB),
		.data_out  (write_DB),
		.data_oe   (cpu_DB_oe),
		.addr_out  (cpu_AB),
		.rw_n      (cpu_rwn),
		.sync      (),
		.phi1_out  (),
		.phi2_out  (),
		.halt_n    (1'b1),
		.addr_oe   (),
		.rw_oe     (),
		.is_halted (),
		.jammed    (),
		.dbg_a (), .dbg_x (), .dbg_y (), .dbg_s (), .dbg_p (), .dbg_ir (), .dbg_pc ()
	);

	// ---- TIA ----
	wire [3:0] audv0, audv1;
	wire       cart_ce;

	TIA tia
	(
		.clk         (clk),
		.ce          (tia_ce),
		.is_7800     (1'b0),
		.phi0        (),
		.phi1        (),
		.phi0_gen    (pclk0_t),
		.phi1_gen    (pclk1_t),
		.phi2        (pclk0),
		.RW_n        (RW),
		.rdy         (tia_RDY),
		.addr        (AB[5:0]),
		.d_in        (write_DB),
		.d_out       (tia_DB_out),
		.d_out_oe    (tia_DB_oe),
		.i           (idump),
		.i_out       (i_out),
		.i4          (ilatch[0]),
		.i5          (ilatch[1]),
		.aud0        (audv0),
		.aud1        (audv1),
		.col         (col),
		.lum         (lum),
		.BLK_n       (),
		.sync        (),
		.cs0_n       (~cs_tia),
		.cs2_n       (~cs_tia),
		.rst         (reset),
		.video_ce    (video_ce),
		.vblank      (vblank),
		.hblank      (),
		.hgap        (hblank),
		.vsync       (vsync),
		.hsync       (hsync),
		.row         (),
		.column      (),
		.phi1_in     (pclk1),
		.cart_ce     (cart_ce),
		.decomb      (decomb),
		.is_pal      (is_pal),
		.stabilize   (stabilize),
		.is_f1       (is_f1),
		.paddle_read (i_read)
	);

	// ---- RIOT ----
	M6532 riot
	(
		.clk           (clk),
		.ce            (pclk0),
		.res_n         (~cpu_reset),
		.ram_init      (cpu_reset),     // a 2600 starts from zeros
		.ram_init_7800 (1'b0),
		.addr          (AB[6:0]),
		.RW_n          (RW),
		.d_in          (write_DB),
		.d_out         (riot_DB_out),
		.RS_n          (AB[9]),
		.IRQ_n         (),
		.IRQ_n_oe      (),
		.CS1           (AB[7]),
		.CS2_n         (~cs_riot),
		.PA_in         (pa_in),
		.PA_out        (pa_out),
		.PB_in         (pb_in),
		.PB_out        (pb_out),
		.oe            (riot_DB_oe),
		.PA_read       ()
	);

	// ---- cartridge ----
	wire       sc, tape_audio;
	wire [2:0] mapper_revision;

	detect2600 detect
	(
		.clk                     (clk),
		.load_start              (load_start),
		.load_addr               (load_addr),
		.load_valid              (load_valid),
		.load_end                (load_end),
		.cart_size               (cart_size),
		.data                    (load_data),
		.force_bs                (mapper_detected),
		.sc                      (sc),
		.mapper_revision         (mapper_revision),
		.cdf_ldx                 (),
		.cdf_ldy                 (),
		.cdf_fetch_offset_enable (),
		.cdf_fetch_offset        (),
		.cdfj_entry              (),
		.cdfj_stack              (),
		.arm_audio_size_addr     ()
	);

	assign mapper = |mapper_force ? mapper_force : mapper_detected;

	cart2600_kg cart
	(
		.d_out           (cart_DB_out),
		.d_in            (RW ? read_DB : write_DB),
		.a_in            (AB),
		.rw              (RW),
		.clk             (clk),
		.reset           (cpu_reset),
		.ce              (cart_ce),
		.phi1            (pclk1),
		.phi2            (pclk0),
		.oe              (cart_DB_oe),
		.sc              (sc),
		.mapper          (mapper),
		.mapper_revision (mapper_revision),
		.rom_do          (rom_do),
		.rom_size        (cart_size),
		.load_start      (load_start),
		.rom_a           (rom_a),
		.rom_read        (rom_read),
		.cartram_addr    (cartram_addr),
		.cartram_wr      (cartram_wr),
		.cartram_rd      (cartram_rd),
		.cartram_wrdata  (cartram_wrdata),
		.cartram_data    (cartram_data),
		.tape_audio      (tape_audio),
		.tape_in         (tape_in),
		.fix_sc_cs       (fix_sc_cs)
	);

	// ---- audio: the non-linear TIA mix of k7800 (audv0 + audv1, or one channel each) ----
	reg [15:0] lut_mix;
	wire [4:0] aud_index = audv0 + audv1;

	always @* begin
		case (aud_index)
			5'd0:  lut_mix = 16'h0000; 5'd1:  lut_mix = 16'h0842; 5'd2:  lut_mix = 16'h0FFF; 5'd3:  lut_mix = 16'h1745;
			5'd4:  lut_mix = 16'h1E1D; 5'd5:  lut_mix = 16'h2492; 5'd6:  lut_mix = 16'h2AAA; 5'd7:  lut_mix = 16'h306E;
			5'd8:  lut_mix = 16'h35E4; 5'd9:  lut_mix = 16'h3B13; 5'd10: lut_mix = 16'h3FFF; 5'd11: lut_mix = 16'h44AE;
			5'd12: lut_mix = 16'h4924; 5'd13: lut_mix = 16'h4D64; 5'd14: lut_mix = 16'h5173; 5'd15: lut_mix = 16'h5554;
			5'd16: lut_mix = 16'h590A; 5'd17: lut_mix = 16'h5C97; 5'd18: lut_mix = 16'h5FFF; 5'd19: lut_mix = 16'h6343;
			5'd20: lut_mix = 16'h6665; 5'd21: lut_mix = 16'h6968; 5'd22: lut_mix = 16'h6C4D; 5'd23: lut_mix = 16'h6F17;
			5'd24: lut_mix = 16'h71C6; 5'd25: lut_mix = 16'h745C; 5'd26: lut_mix = 16'h76DA; 5'd27: lut_mix = 16'h7942;
			5'd28: lut_mix = 16'h7B95; 5'd29: lut_mix = 16'h7DD3; 5'd30: lut_mix = 16'h7FFF; default: lut_mix = 16'hFFFF;
		endcase
	end

	function [15:0] lut_single;
		input [3:0] v;
		case (v)
			4'd0:  lut_single = 16'h0000; 4'd1:  lut_single = 16'h0C63; 4'd2:  lut_single = 16'h17FF; 4'd3:  lut_single = 16'h22E8;
			4'd4:  lut_single = 16'h2D2C; 4'd5:  lut_single = 16'h36DB; 4'd6:  lut_single = 16'h3FFF; 4'd7:  lut_single = 16'h48A5;
			4'd8:  lut_single = 16'h50D6; 4'd9:  lut_single = 16'h589C; 4'd10: lut_single = 16'h5FFF; 4'd11: lut_single = 16'h6705;
			4'd12: lut_single = 16'h6DB6; 4'd13: lut_single = 16'h7416; 4'd14: lut_single = 16'h7A2D; default: lut_single = 16'h7FFF;
		endcase
	endfunction

	// k7800: tia_r follows audv0, tia_l audv1; the tape (Supercharger loading) is added
	assign audio_r = (use_stereo ? lut_single(audv0) : lut_mix) + {3'd0, tape_audio, 12'd0};
	assign audio_l = (use_stereo ? lut_single(audv1) : lut_mix) + {3'd0, tape_audio, 12'd0};

endmodule
