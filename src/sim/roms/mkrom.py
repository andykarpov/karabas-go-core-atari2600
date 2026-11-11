#!/usr/bin/env python3
# Our own test cartridges for the Ф1 simulation (no assembler needed: a few opcodes with labels).
#   mkrom.py OUT.a26 [bars|timer|f8|paddle]
# bars : 4K, a standard NTSC frame (3 VSYNC, 37 VBLANK, 192 visible, 30 overscan); the visible
#        lines get COLUBK = frame counter + 2 * line (ADC: the ALU path), the playfield PF1 = $AA
#        in COLUPF $0E (TIA objects), the frame counter lives in RIOT RAM $80.
# timer: 4K, like bars but VBLANK and overscan timed by the RIOT timer (TIM64T / INTIM), as games do.
#        The 6532 counts N - 1 at the cycle after the write, so 0 comes (N - 1) * 64 cycles later:
#        43 -> 2688 cycles (+ WSYNC: VBLANK 36 lines after VSYNC), 35 -> 2176 (29 lines): 261 lines.
# f8   : 8K F8 (hotspots $1FF8 / $1FF9): starts in bank 1, the kernel is in bank 0, each frame goes
#        through both hotspots; the visible lines are all colour $40 if the switching works.
# paddle: 4K, the paddle A (INPT0) as a picture: the dump transistor is on (VBLANK D7) from the
#        overscan to the end of VBLANK, off over the 192 visible lines, which read INPT0 each:
#        black until the capacitor is charged, white ($0E) after. The first white line = the paddle.
import sys

OP = {  # mnemonic, mode -> opcode
	('sei', ''): 0x78, ('cld', ''): 0xD8, ('txa', ''): 0x8A, ('tay', ''): 0xA8, ('dex', ''): 0xCA,
	('txs', ''): 0x9A, ('pha', ''): 0x48, ('clc', ''): 0x18, ('nop', ''): 0xEA,
	('lda', '#'): 0xA9, ('ldx', '#'): 0xA2, ('ldy', '#'): 0xA0, ('adc', '#'): 0x69,
	('sta', 'zp'): 0x85, ('stx', 'zp'): 0x86, ('lda', 'zp'): 0xA5, ('inc', 'zp'): 0xE6,
	('sta', 'abs'): 0x8D, ('lda', 'abs'): 0xAD, ('bit', 'abs'): 0x2C, ('jmp', 'abs'): 0x4C,
	('bit', 'zp'): 0x24, ('bne', 'rel'): 0xD0, ('bpl', 'rel'): 0x10, ('beq', 'rel'): 0xF0,
}
VSYNC, VBLANK, WSYNC, COLUPF, COLUBK, CTRLPF, PF1 = 0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x0E
INTIM, TIM64T = 0x284, 0x296


class Asm:
	def __init__(self, org):
		self.org, self.code, self.labels, self.fix = org, bytearray(), {}, []

	def pc(self):
		return self.org + len(self.code)

	def label(self, name):
		self.labels[name] = self.pc()

	def __call__(self, mn, mode='', arg=None):
		self.code.append(OP[(mn, mode)])
		if mode in ('#', 'zp'):
			self.code.append(arg & 0xFF)
		elif mode == 'abs':
			if isinstance(arg, str):
				self.fix.append(('abs', len(self.code), arg))
				arg = 0
			self.code += bytes((arg & 0xFF, arg >> 8))
		elif mode == 'rel':
			self.fix.append(('rel', len(self.code), arg))
			self.code.append(0)

	def link(self):
		for kind, at, name in self.fix:
			t = self.labels[name]
			if kind == 'abs':
				self.code[at], self.code[at + 1] = t & 0xFF, t >> 8
			else:
				d = t - (self.org + at + 1)
				assert -128 <= d < 128, name
				self.code[at] = d & 0xFF
		return self.code


def wsync_loop(a, n, name):
	a('ldx', '#', n)
	a.label(name)
	a('sta', 'zp', WSYNC)
	a('dex')
	a('bne', 'rel', name)


def timer_wait(a, ticks, name):  # TIM64T = ticks, wait for INTIM = 0, then one WSYNC
	a('lda', '#', ticks)
	a('sta', 'abs', TIM64T)
	a.label(name)
	a('lda', 'abs', INTIM)
	a('bne', 'rel', name)
	a('sta', 'zp', WSYNC)


def kernel(a, timer, base=0):
	a.label('frame')
	a('lda', '#', 2)
	a('sta', 'zp', VBLANK)
	a('sta', 'zp', VSYNC)
	for _ in range(3):
		a('sta', 'zp', WSYNC)
	a('lda', '#', 0)
	a('sta', 'zp', VSYNC)
	if timer:
		timer_wait(a, 43, 'vb')
	else:
		wsync_loop(a, 37, 'vb')
	a('lda', '#', 0)
	a('sta', 'zp', VBLANK)
	a('inc', 'zp', 0x80)
	a('lda', 'zp', 0x80)
	if base:
		a('lda', '#', base)
	a('ldx', '#', 192)
	a.label('kern')
	a('sta', 'zp', WSYNC)
	a('sta', 'zp', COLUBK)
	a('clc')
	a('adc', '#', 0 if base else 2)
	a('dex')
	a('bne', 'rel', 'kern')
	a('lda', '#', 2)
	a('sta', 'zp', VBLANK)
	if timer:
		timer_wait(a, 35, 'os')
	else:
		wsync_loop(a, 30, 'os')


def init(a):
	a.label('start')
	a('sei')
	a('cld')
	a('ldx', '#', 0)
	a('txa')
	a('tay')
	a.label('clear')
	a('dex')
	a('txs')
	a('pha')
	a('bne', 'rel', 'clear')
	a('lda', '#', 0x0E)
	a('sta', 'zp', COLUPF)
	a('lda', '#', 0xAA)
	a('sta', 'zp', PF1)


def bank4k(body, start_vec=True):
	a = Asm(0xF000)
	body(a)
	code = a.link()
	rom = bytearray(b'\xEA' * 4096)
	rom[:len(code)] = code
	s = a.labels.get('start', 0xF000)
	rom[0xFFC:0x1000] = bytes((s & 0xFF, s >> 8, s & 0xFF, s >> 8))
	return rom


def main():
	out, kind = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else 'bars')
	if kind in ('bars', 'timer'):
		def body(a):
			init(a)
			kernel(a, kind == 'timer')
			a('jmp', 'abs', 'frame')
		rom = bank4k(body)
	elif kind == 'f8':
		# F8 starts in bank 1 (image 4K..8K): init, BIT $1FF8 at $F040 -> bank 0 goes on at $F043 with
		# the kernel (colour base $40). Each frame ends in bank 0 at $F200: BIT $1FF9 -> bank 1 at
		# $F203: BIT $1FF8 -> bank 0 at $F206: JMP frame. Bank 1 has no kernel, so a broken switch
		# never draws the $40 lines.
		def b1(a):
			init(a)
			while a.pc() < 0xF040:
				a('nop')
			a('bit', 'abs', 0x1FF8)
			while a.pc() < 0xF203:
				a('nop')
			a('bit', 'abs', 0x1FF8)
		def b0(a):
			while a.pc() < 0xF043:
				a('nop')
			kernel(a, False, base=0x40)
			a('jmp', 'abs', 'sw')
			while a.pc() < 0xF200:
				a('nop')
			a.label('sw')
			a('bit', 'abs', 0x1FF9)
			a('nop'); a('nop'); a('nop')
			a('jmp', 'abs', 'frame')
		rom = bank4k(b0) + bank4k(b1)
	elif kind == 'paddle':
		def body(a):
			init(a)
			a('lda', '#', 0)
			a('sta', 'zp', PF1)
			a.label('frame')
			a('lda', '#', 0x82)          # VBLANK + dump on
			a('sta', 'zp', VBLANK)
			a('sta', 'zp', VSYNC)
			for _ in range(3):
				a('sta', 'zp', WSYNC)
			a('lda', '#', 0)
			a('sta', 'zp', VSYNC)
			wsync_loop(a, 37, 'vb')
			a('lda', '#', 0)             # picture, dump off: the capacitor charges
			a('sta', 'zp', VBLANK)
			a('ldx', '#', 192)
			a.label('kern')
			a('sta', 'zp', WSYNC)
			a('lda', '#', 0)
			a('bit', 'zp', 0x08)         # INPT0 D7 = charged
			a('bpl', 'rel', 'dark')
			a('lda', '#', 0x0E)
			a.label('dark')
			a('sta', 'zp', COLUBK)
			a('dex')
			a('bne', 'rel', 'kern')
			a('lda', '#', 0x82)
			a('sta', 'zp', VBLANK)
			wsync_loop(a, 30, 'os')
			a('jmp', 'abs', 'frame')
		rom = bank4k(body)
	else:
		sys.exit('kind: bars | timer | f8 | paddle')
	open(out, 'wb').write(rom)


main()
