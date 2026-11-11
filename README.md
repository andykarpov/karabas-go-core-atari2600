# Atari 2600 VCS core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Atari 2600 VCS (6507, TIA, RIOT 6532, bank-switched cartridges) for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). Based on the 2600 part of k7800 ([Atari7800_MiSTer](https://github.com/MiSTer-devel/Atari7800_MiSTer) by Jamie Blanks: the TIA from the decapped chip, the 6502, the RIOT, the cartridge mappers), converted to Verilog with sv2v. The A2601 of Retromaster as ported in [A2600Nano](https://github.com/MiSTle-Dev/A2600Nano) is kept in the repository as the fallback.

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `atari2600.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `atari2600.kg` | HDMI | HDMI, analog output (sigma-delta) |
| Karabas Mini G | `atari2600.kg` | HDMI | HDMI, I2S DAC |

The core file is in `src/`. It starts with Legendary Spear, a homebrew game by DChristianson (MIT, `src/roms`) in the cartridge slot. Other games are not included: put your own cartridge images on the SD card in `/atari2600`.

Status: checked on Mini G. The Go and Mini builds have not been run on a board yet.

## Features

- **Machine:** 6507 at 1.19 MHz, TIA, RIOT 6532; NTSC, PAL and SECAM.
- **Cartridges:** `.a26` / `.bin` images up to 512 KB (from the SD card, through the OSD), the mapper is detected from the image: 2K, 4K, F8, F6, F4, FA, FA2 (no save of its flash), FE, E0, E7, 3F, 3E, CV, UA, F0, 32-in-1, P2 (DPC, Pitfall II), AR (Supercharger), SB, WD, EF, 0840, DF, FC, JANE, MC, CTY, SuperChip RAM. Some (FE, CTY, MC, 32-in-1) are not found by the detection: choose them in the Mapper item. AR and JANE have not been tried. The ARM cartridges (DPC+, CDF, ACE, ELF) are not supported: the screen shows "Out of Order".
- **Video:** 160 x 240 of the TIA in a frame buffer, shown as 1024 x 768 at 60 Hz (each pixel 6 x 3, a 960 x 720 picture in the middle). PAL games (50 Hz) are shown with repeated frames.
- **Sound:** the two TIA channels.
- **Controllers:** two joysticks (USB pads, the keyboard as the left joystick); paddles from the mouse and the pads; the second and third buttons of a pad as the Booster Grip.

## Getting started

1. Copy `atari2600.kg` (one file for Go, Mini and Mini G) to the root of the SD card.
2. Put your cartridge images in `/atari2600` on the SD card.
3. Choose Atari 2600 in the core menu. Legendary Spear starts. Open the OSD (**Menu+Esc**) and choose another image in Cartridge (**Menu+C**).

"Menu" is the Windows key of the keyboard.

## OSD menu

| Item | Values | Hotkey |
|---|---|---|
| Cartridge | `.a26` / `.bin` image | Menu+C |
| Reset | resets the machine | F12 |
| TV Type | Color / B&W (the switch of the console) | Menu+T |
| Left Diff, Right Diff | B / A (the difficulty switches) | Menu+L, Menu+R |
| Mapper | Auto / FE / CTY / MC 2K / MC 4K / MC 8K / 32-in-1 / E0 / E7 / 3E / 3F / UA / 0840 / SB / WD / F0 | |
| Region | Auto / NTSC / PAL / SECAM | |
| Controller | Joystick / Paddles (the left port) | Menu+P |

The settings are remembered. A change of Mapper restarts the machine (with the cartridge loaded again). Region Auto takes NTSC or PAL from the number of lines of the game; SECAM has to be chosen.

## Controls

| Console / controller | Keyboard | USB pad |
|---|---|---|
| Left joystick | arrows, fire: Space or Left Ctrl, Fire 2: Left Alt | left pad: A fire, B Fire 2, C Fire 3 |
| Right joystick | | right pad |
| Game Reset | F2 | Start |
| Game Select | F1 | Mode or X |
| Reset of the machine | F12 | |

**Paddles** (Controller = Paddles): paddle A is the mouse (left and right; fire: the left button) and the left / right of the left joystick; paddle B is the left / right of the right pad (fire: the right mouse button or the fire of the right pad).

## Building

Clone with `--recursive` (the `modules` submodule). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The Mini and Go tops (and the timing part of their ucf) are made from the Mini G top by `src/tools/mktops.py`; the converted k7800 sources (`src/rtl/sv2v`) by `src/tools/sv2v.sh`. The Verilator checks: `src/sim/run_checks.sh` (the machine), `src/sim/run_board.sh` (the board side). The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## Licence

The Karabas parts are GPL v3 ([LICENSE](LICENSE)); k7800 is MIT, A2601 / A2600Nano are GPL v3, Legendary Spear is MIT (`src/roms/LICENSE-legendary-spear`). Imported files keep the licence headers of their authors.
