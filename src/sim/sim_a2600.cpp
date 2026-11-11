// sim_a2600.cpp - verilator harness of atari2600_top (Ф1): the machine on C++ memory models.
//
//   sim_a2600 CART [--frames N] [--div N] [--jitter] [--mapper N] [--pal] [--ppm PREFIX]
//             [--every N] [--expect-lines N] [--expect-frames N] [--expect-colour HEX] [--expect-mapper N] [--sample-line N]
//             [--reset-at FRAME]...
//             [--joy HEX] [--swb HEX] [--trace-vb] [--trace-riot FRAME] [--quiet]
//
// CART: the image (.a26 / .bin), fed through the load stream (detect2600) while the machine is
// held in reset, then kept as the cartridge ROM: rom_do = image[rom_a] at once (the board SRAM
// answers within a few clocks, long before the next 6507 cycle). Cartridge RAM: 256 KB model.
// --div: clk ticks per tia_ce (2x colour clock), default 4 (clk 28.6 MHz); --jitter alternates the
// distance (div-1, div+1), as a fractional CE of a board clock does. --frames: run length in
// frames (VSYNC rising edges), default 10. --ppm: write every N-th frame (--every, default 1) as
// PREFIX_NNNN.ppm, 228 colour clocks x the lines (blank areas dark grey, the NTSC palette of
// k7800). --expect-*: exit 1 unless the frames after the first two have N lines, at least N
// frames came, the background pixel (2 clocks into the visible part) of the middle line (or of
// --sample-line N, counted from VSYNC) of the
// last frame has palette index HEX ({col, lum}), the mapper in use is N.
// --reset-at: a console reset (1000 clocks) when that frame starts; may be repeated.
// --joy: RIOT port A (default FF), --swb: port B (console switches, default FF). --trace-vb:
// print the line / colour clock of every VBLANK change. --trace-riot: the RIOT timer accesses of
// that frame (bus, timer state), only in the DEBUG=1 build of run_sim.sh.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include "verilated.h"
#include "Vatari2600_top.h"
#ifdef SIM_DEBUG
#include "Vatari2600_top___024root.h"   // --trace-riot reads internal signals (DEBUG=1 run_sim.sh)
#endif

static Vatari2600_top *tb;
static std::vector<uint8_t> rom;
static std::vector<uint8_t> cram(256 * 1024, 0);
static uint32_t pal[256];

static const int W = 228, H = 400;
static uint8_t fb[H][W];       // {col, lum} or 0xFF = blank
static int line_x = 0, line_y = 0;
static bool old_hs = false, old_vs = false, old_vb = false, trace_vb = false;
static int frames = 0;
static std::vector<int> lines_per_frame;
static std::string ppm_prefix;
static int ppm_every = 1;
static int last_centre = -1;
static int trace_riot = -1;     // frame to trace the RIOT accesses of
static int sample_line = -1;    // the line of the colour check, -1 = the middle line
static std::vector<int> reset_at; // frames at which a console reset (F12) is pulsed

static void load_palette(void) {
	FILE *f = fopen("rtl/k7800/palettes/NWARM.hex", "r");
	if (!f) { perror("palette"); exit(2); }
	for (int i = 0; i < 256; i++) {
		unsigned v = 0;
		if (fscanf(f, "%x", &v) != 1) break;
		pal[i] = v;
	}
	fclose(f);
}

static void write_ppm(int n, int lines) {
	char fn[512];
	snprintf(fn, sizeof fn, "%s_%04d.ppm", ppm_prefix.c_str(), n);
	FILE *f = fopen(fn, "wb");
	if (!f) { perror(fn); return; }
	if (lines > H) lines = H;
	fprintf(f, "P6\n%d %d\n255\n", W * 2, lines);
	for (int y = 0; y < lines; y++)
		for (int x = 0; x < W * 2; x++) {
			uint8_t p = fb[y][x / 2];
			uint32_t c = p == 0xFF ? 0x202020 : pal[(p & 0x7F) << 1];
			uint8_t rgb[3] = { (uint8_t)(c >> 16), (uint8_t)(c >> 8), (uint8_t)c };
			fwrite(rgb, 1, 3, f);
		}
	fclose(f);
}

// one colour clock of video (video_ce)
static void video_tick(void) {
	bool hs = tb->hsync, vs = tb->vsync;
	if (hs && !old_hs) {           // a new line
		line_y++;
		line_x = 0;
	}
	if (vs && !old_vs) {           // a new frame
		if (frames > 0) {
			lines_per_frame.push_back(line_y);
			int cy = sample_line >= 0 ? sample_line : line_y / 2;
			if (cy < H) {          // the background left of the playfield: 2 clocks into the line
				int x = 0;
				while (x < W && fb[cy][x] == 0xFF) x++;
				last_centre = x + 2 < W ? fb[cy][x + 2] : -1;
			}
			if (!ppm_prefix.empty() && (frames % ppm_every) == 0)
				write_ppm(frames, line_y);
		}
		frames++;
		line_y = 0;
		memset(fb, 0xFF, sizeof fb);
	}
	if (trace_vb && tb->vblank != old_vb)
		printf("frame %d line %d x %d: VBLANK %d\n", frames, line_y, line_x, tb->vblank);
	old_vb = tb->vblank;
	old_hs = hs;
	old_vs = vs;
	if (line_x < W && line_y < H)
		fb[line_y][line_x] = (tb->hblank || tb->vblank) ? 0xFF : ((tb->col << 3) | tb->lum);
	line_x++;
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	const char *cart = nullptr;
	int max_frames = 10, div = 4, mapper = 0, expect_lines = 0, expect_frames = 0, expect_colour = -1, expect_mapper = -1;
	bool jitter = false, quiet = false;
	unsigned joy = 0xFF, swb = 0xFF;
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		auto next = [&]() { if (i + 1 >= argc) { fprintf(stderr, "%s: value?\n", a.c_str()); exit(2); } return argv[++i]; };
		if (a == "--frames") max_frames = atoi(next());
		else if (a == "--div") div = atoi(next());
		else if (a == "--jitter") jitter = true;
		else if (a == "--mapper") mapper = atoi(next());
		else if (a == "--ppm") ppm_prefix = next();
		else if (a == "--every") ppm_every = atoi(next());
		else if (a == "--expect-lines") expect_lines = atoi(next());
		else if (a == "--expect-frames") expect_frames = atoi(next());
		else if (a == "--expect-colour") expect_colour = strtol(next(), nullptr, 16);
		else if (a == "--expect-mapper") expect_mapper = atoi(next());
		else if (a == "--sample-line") sample_line = atoi(next());
		else if (a == "--reset-at") reset_at.push_back(atoi(next()));
		else if (a == "--joy") joy = strtol(next(), nullptr, 16);
		else if (a == "--swb") swb = strtol(next(), nullptr, 16);
		else if (a == "--quiet") quiet = true;
		else if (a == "--trace-vb") trace_vb = true;
		else if (a == "--trace-riot") trace_riot = atoi(next());
		else if (a[0] != '-' && !cart) cart = argv[i];
		else if (a[0] != '+') { fprintf(stderr, "unknown %s\n", a.c_str()); return 2; }
	}
	if (!cart) { fprintf(stderr, "usage: sim_a2600 CART [options]\n"); return 2; }
	FILE *f = fopen(cart, "rb");
	if (!f) { perror(cart); return 2; }
	fseek(f, 0, SEEK_END);
	rom.resize(ftell(f));
	fseek(f, 0, SEEK_SET);
	if (fread(rom.data(), 1, rom.size(), f) != rom.size()) { fclose(f); return 2; }
	fclose(f);
	load_palette();
	memset(fb, 0xFF, sizeof fb);

	tb = new Vatari2600_top;
	tb->reset = 1;
	tb->tia_ce = 0;
	tb->cart_present = 1;
	tb->mapper_force = mapper;
	tb->cart_size = rom.size();
	tb->pa_in = joy;
	tb->pb_in = swb;
	tb->ilatch = 3;
	tb->idump = 0;
	tb->tape_in = 0;
	tb->stabilize = 1;
	tb->decomb = 0;
	tb->use_stereo = 0;
	tb->fix_sc_cs = 0;

	uint64_t tick = 0;
	int ce_cnt = 0, ce_dist = div, jit = 0;
	size_t load_pos = 0;
	int load_phase = 0;            // 0 reset then the start pulse, 1 bytes, 2 end pulse, 3 hold reset, 4 run
	int hold = 0, reset_ticks = 0;
	uint64_t cycles_run = 0;
	const uint64_t limit = (uint64_t)(max_frames + 2) * 262 * 228 * 2 * (div + 1) * 2 + 2000000;

	auto clock = [&](void) {
		// inputs for this cycle
		tb->load_start = 0; tb->load_valid = 0; tb->load_end = 0;
		switch (load_phase) {
		case 0: if (tick >= 16) { tb->load_start = 1; load_phase = 1; } break;   // reset first, as on the board
		case 1:
			if ((tick & 3) == 0) {
				tb->load_addr = load_pos;
				tb->load_data = rom[load_pos];
				tb->load_valid = 1;
				if (++load_pos == rom.size()) load_phase = 2;
			}
			break;
		case 2: tb->load_end = 1; load_phase = 3; break;
		case 3: if (++hold == 64) { tb->reset = 0; load_phase = 4; } break;
		case 4:                    // running: --reset-at pulses the reset for 1000 clocks
			for (size_t k = 0; k < reset_at.size(); k++)
				if (reset_at[k] == frames) { reset_at[k] = -1; tb->reset = 1; reset_ticks = 1000; }
			if (reset_ticks && --reset_ticks == 0) tb->reset = 0;
			break;
		default: break;
		}
		bool ce = false;
		if (load_phase >= 3) {
			if (++ce_cnt >= ce_dist) {
				ce = true;
				ce_cnt = 0;
				if (jitter) { jit ^= 1; ce_dist = div + (jit ? 1 : -1); }
			}
		}
		tb->tia_ce = ce;
		tb->clk = 0;
		tb->eval();
		// memories answer combinationally to the addresses of this cycle
		tb->rom_do = rom.empty() ? 0xFF : rom[tb->rom_a % rom.size()];
		tb->cartram_data = cram[tb->cartram_addr & (cram.size() - 1)];
		tb->eval();
		bool wr = tb->cartram_wr;
		uint32_t wa = tb->cartram_addr & (cram.size() - 1);
		uint8_t wd = tb->cartram_wrdata;
		bool vce = tb->video_ce;
#ifdef SIM_DEBUG
		if (trace_riot == frames && tb->rootp->atari2600_top__DOT__pclk0) {
			auto *r = tb->rootp;
			unsigned ab = r->atari2600_top__DOT__cpu_AB & 0x1FFF;
			if ((ab & 0x1280) == 0x280)
				printf("line %3d x %3d: %04x %s %02x  timer %02x presc %03x incr %d\n", line_y, line_x, ab,
					r->atari2600_top__DOT__cpu_rwn ? "rd" : "wr", r->atari2600_top__DOT__read_DB,
					r->atari2600_top__DOT__riot__DOT__timer, r->atari2600_top__DOT__riot__DOT__prescaler,
					r->atari2600_top__DOT__riot__DOT__incr);
		}
#endif
		tb->clk = 1;
		tb->eval();
		if (wr) cram[wa] = wd;
		if (vce && load_phase == 4) video_tick();
		tick++;
		if (load_phase == 4) cycles_run++;
	};

	while (frames <= max_frames && tick < limit && !Verilated::gotFinish())
		clock();

	if (!quiet) {
		printf("%s: %zu bytes, mapper %d (detected %d), %d frames, %llu clk\n", cart, rom.size(),
			tb->mapper, tb->mapper_detected, frames > 0 ? frames - 1 : 0, (unsigned long long)cycles_run);
		printf("lines per frame:");
		for (int n : lines_per_frame) printf(" %d", n);
		printf("\ncentre of the last frame: %02x\n", last_centre);
	}
	int rc = 0;
	if (expect_frames && (int)lines_per_frame.size() < expect_frames) {
		printf("FAIL: %zu frames < %d\n", lines_per_frame.size(), expect_frames);
		rc = 1;
	}
	if (expect_lines) {
		for (size_t i = 2; i < lines_per_frame.size(); i++)
			if (lines_per_frame[i] != expect_lines) {
				printf("FAIL: frame %zu has %d lines, not %d\n", i, lines_per_frame[i], expect_lines);
				rc = 1;
				break;
			}
		if (lines_per_frame.size() < 3) { printf("FAIL: too few frames for --expect-lines\n"); rc = 1; }
	}
	if (expect_colour >= 0 && last_centre != expect_colour) {
		printf("FAIL: centre %02x, not %02x\n", last_centre, expect_colour);
		rc = 1;
	}
	if (expect_mapper >= 0 && tb->mapper != expect_mapper) {
		printf("FAIL: mapper %d, not %d\n", tb->mapper, expect_mapper);
		rc = 1;
	}
	if (rc == 0 && (expect_lines || expect_frames || expect_colour >= 0 || expect_mapper >= 0)) printf("PASS\n");
	delete tb;
	return rc;
}
