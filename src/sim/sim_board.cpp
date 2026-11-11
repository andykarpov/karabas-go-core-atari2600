// sim_board.cpp - verilator harness of a2600_core (Ф2): the board side of the core with the real
// SRAM controller (a2600_sram) on a model of the asynchronous SRAM, the TIA CE (a2600_ce), the load
// stream, the frame buffer and its 1024 x 768 output (a2600_fb).
//
//   sim_board CART [--file] [--frames N] [--ppm PREFIX] [--at X,Y] [--expect-colour HEX] [--joy HEX]
//
// CART goes in as the ROM of the .kg (rom_active / rom_wr, as the firmware does when the core starts),
// or with --file as the FL item (file_active, slot 0). A byte every 12 clocks of clk_sys (the burst of
// the MCU is slower). clk_pix = 2 x clk_sys, phase aligned (one DCM on the board). --frames: output
// frames (vsync of the 1024 x 768 output) to run, default 6. --ppm: every output frame from the 3rd as
// PREFIX_NNNN.ppm (1024 x 768). --at X,Y: the output pixel to check (default 512,174: the status band
// of the gamebub tests); --expect-colour: its palette index (as sim_a2600: {col, lum}) -> exit 1 if not.
// --joy: kg_mcu JOY_L bits (hex), e.g. 40 = A (fire). --mapper N / --region N / --paddles: the OSD
// items Mapper (index of its options), Region (0 Auto, 1 NTSC, 2 PAL, 3 SECAM), Controller = Paddles.
// --mouse DX: one mouse report of X move DX (-128..127) after the load (paddle A from 128).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include "verilated.h"
#include "Va2600_core.h"

static Va2600_core *tb;
static std::vector<uint8_t> sram(4 * 1024 * 1024, 0);
static uint32_t pal[256];

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

// the asynchronous SRAM (2M x 16): reads always (the controller takes MD when it wants), writes of a
// lane while its /WE is low and the controller drives MD
static void sram_eval(void) {
	uint32_t a = (tb->MA & 0x1FFFFF) * 2;
	if (!(tb->MWR_N & 1) && !(tb->MD_OE_N & 0x00FF)) sram[a] = tb->MD_O & 0xFF;
	if (!(tb->MWR_N & 2) && !(tb->MD_OE_N & 0xFF00)) sram[a + 1] = tb->MD_O >> 8;
	tb->MD_I = sram[a] | (sram[a + 1] << 8);
}

static const int OW = 1024, OH = 768;
static std::vector<uint32_t> frame(OW * OH, 0);
static int ox = 0, oy = 0, oframes = 0;
static bool old_de = false, old_vs = false;

static void video_tick(void) {
	bool de = tb->fb_de, vs = tb->fb_vs;
	if (vs && !old_vs) { oframes++; oy = 0; }
	if (de) {
		if (ox < OW && oy < OH) frame[oy * OW + ox] = tb->fb_rgb;
		ox++;
	}
	if (!de && old_de) { ox = 0; oy++; }
	old_de = de;
	old_vs = vs;
}

static void write_ppm(const std::string &prefix, int n) {
	char fn[512];
	snprintf(fn, sizeof fn, "%s_%04d.ppm", prefix.c_str(), n);
	FILE *f = fopen(fn, "wb");
	if (!f) { perror(fn); return; }
	fprintf(f, "P6\n%d %d\n255\n", OW, OH);
	for (int i = 0; i < OW * OH; i++) {
		uint8_t rgb[3] = { (uint8_t)(frame[i] >> 16), (uint8_t)(frame[i] >> 8), (uint8_t)frame[i] };
		fwrite(rgb, 1, 3, f);
	}
	fclose(f);
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	const char *cart = nullptr;
	bool as_file = false;
	int max_frames = 6, at_x = 512, at_y = 174, expect = -1;
	unsigned joy = 0, mapper = 0, region = 0, paddles = 0;
	int mouse_dx = 0;
	std::string ppm;
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		auto next = [&]() { if (i + 1 >= argc) { fprintf(stderr, "%s: value?\n", a.c_str()); exit(2); } return argv[++i]; };
		if (a == "--file") as_file = true;
		else if (a == "--frames") max_frames = atoi(next());
		else if (a == "--ppm") ppm = next();
		else if (a == "--at") { if (sscanf(next(), "%d,%d", &at_x, &at_y) != 2) return 2; }
		else if (a == "--expect-colour") expect = strtol(next(), nullptr, 16);
		else if (a == "--joy") joy = strtol(next(), nullptr, 16);
		else if (a == "--mapper") mapper = atoi(next());
		else if (a == "--region") region = atoi(next());
		else if (a == "--paddles") paddles = 1;
		else if (a == "--mouse") mouse_dx = atoi(next());
		else if (a[0] != '-' && !cart) cart = argv[i];
		else if (a[0] != '+') { fprintf(stderr, "unknown %s\n", a.c_str()); return 2; }
	}
	if (!cart) { fprintf(stderr, "usage: sim_board CART [options]\n"); return 2; }
	FILE *f = fopen(cart, "rb");
	if (!f) { perror(cart); return 2; }
	std::vector<uint8_t> rom;
	fseek(f, 0, SEEK_END);
	rom.resize(ftell(f));
	fseek(f, 0, SEEK_SET);
	if (fread(rom.data(), 1, rom.size(), f) != rom.size()) return 2;
	fclose(f);
	load_palette();
	// the SRAM starts with noise, as a real one (the cartridge RAM must not depend on zeros)
	for (size_t i = 0; i < sram.size(); i++) sram[i] = (i * 2654435761u) >> 24;

	tb = new Va2600_core;
	tb->areset = 1;
	tb->kb_dat0 = tb->kb_dat1 = tb->kb_dat2 = tb->kb_dat3 = tb->kb_dat4 = tb->kb_dat5 = 0x80;
	tb->kb_status = 0;
	tb->joy_l = joy;
	tb->joy_r = 0;
	tb->sw_reset = 0; tb->sw_bw = 0; tb->sw_diff_l = 0; tb->sw_diff_r = 0;
	tb->sw_mapper = mapper; tb->sw_region = region; tb->sw_paddles = paddles;
	tb->ms_x = 0; tb->ms_b = 0; tb->ms_upd = 0;
	tb->rom_active = 0; tb->file_active = 0; tb->rom_wr = 0; tb->file_wr = 0; tb->file_slot = 0;

	uint64_t sys = 0;
	size_t pos = 0;
	int phase = 0;     // 0 reset, 1 active, 2 bytes, 3 done
	int gap = 0;
	const uint64_t limit = (uint64_t)(max_frames + 4) * 1344 * 806;
	uint64_t pix = 0;
	int ppm_frame = -1;
	while (oframes <= max_frames && pix < limit && !Verilated::gotFinish()) {
		// one clk_pix period; clk_sys rises with every other clk_pix rise
		bool sys_edge = (pix & 1) == 0;
		if (sys_edge) {
			// the load stream on clk_sys
			tb->rom_wr = 0; tb->file_wr = 0;
			switch (phase) {
			case 0: if (sys == 64) tb->areset = 0; if (sys == 200) phase = 1; break;
			case 1:
				if (as_file) { tb->file_active = 1; tb->file_slot = 0; tb->file_addr = 0xFFFFFFFF; }
				else { tb->rom_active = 1; tb->rom_addr = 0xFFFFFFFF; }
				phase = 2; gap = 12;
				break;
			case 2:
				if (--gap == 0) {
					gap = 12;
					if (pos < rom.size()) {
						if (as_file) { tb->file_addr = pos; tb->file_data = rom[pos]; tb->file_wr = 1; }
						else { tb->rom_addr = pos; tb->rom_data = rom[pos]; tb->rom_wr = 1; }
						pos++;
					} else {
						tb->rom_active = 0; tb->file_active = 0;
						tb->ms_x = (uint8_t)mouse_dx;
						if (mouse_dx) tb->ms_upd = 1;
						phase = 3;
						printf("loaded %zu bytes at clk_sys %llu\n", rom.size(), (unsigned long long)sys);
					}
				}
				break;
			default: break;
			}
		}
		// clk_pix falls (clk_sys stays), then rises together with clk_sys on a sys_edge; clk_sys falls
		// with the clk_pix rise between
		tb->clk_pix = 0;
		tb->eval();
		sram_eval();
		tb->eval();
		tb->clk_pix = 1;
		tb->clk_sys = sys_edge;
		tb->eval();
		sram_eval();
		tb->eval();
		video_tick();
		if (sys_edge) sys++;
		pix++;
		if (oframes != ppm_frame && oframes >= 3 && oy == OH - 1 && ox == 0) {
			ppm_frame = oframes;
			if (!ppm.empty()) write_ppm(ppm, oframes);
		}
	}
	uint32_t c = frame[at_y * OW + at_x];
	int idx = -1;
	for (int i = 0; i < 256; i += 2) if (pal[i] == c) { idx = i >> 1; break; }
	printf("%s: %zu bytes, mapper %d, pal %d, cart_ok %d, cart_size %u, %d output frames, %llu clk_sys\n", cart, rom.size(),
		tb->mapper, tb->is_pal, tb->cart_ok, tb->cart_size, oframes, (unsigned long long)sys);
	printf("pixel %d,%d: %06x (palette index %02x)\n", at_x, at_y, c, idx);
	int rc = 0;
	if (expect >= 0) {
		if (idx == expect) printf("PASS\n");
		else { printf("FAIL: index %02x, not %02x\n", idx, expect); rc = 1; }
	}
	delete tb;
	return rc;
}
