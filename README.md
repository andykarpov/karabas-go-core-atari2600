# Atari 2600 VCS core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Atari 2600 VCS (6507, TIA, RIOT 6532, bank-switched cartridges) for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). Based on the 2600 part of k7800 ([Atari7800_MiSTer](https://github.com/MiSTer-devel/Atari7800_MiSTer) by Jamie Blanks); the A2601 of Retromaster as ported in [A2600Nano](https://github.com/MiSTle-Dev/A2600Nano) is the fallback and the donor of the glue.

Status: work in progress (see `docs/PLAN.md`, in Russian). Nothing runs on a board yet.

Games are not included: put your own cartridge images on the SD card in `/atari2600`.

## Licence

k7800 is MIT; A2601 / A2600Nano are GPL v3; the Karabas parts are GPL v3 (`LICENSE`).
