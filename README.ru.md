# Ядро Atari 2600 VCS для Karabas Go / Mini / Mini G

[English version](README.md)

Atari 2600 VCS (6507, TIA, RIOT 6532, картриджи с переключением банков) для плат семейства Karabas Go (Xilinx Spartan-6 XC6SLX25). Основа — 2600-часть k7800 ([Atari7800_MiSTer](https://github.com/MiSTer-devel/Atari7800_MiSTer) Джейми Бланкса: TIA по вскрытому кристаллу, 6502, RIOT, мапперы картриджей), переведённая в Verilog через sv2v. A2601 Retromaster'а в порте [A2600Nano](https://github.com/MiSTle-Dev/A2600Nano) лежит в репозитории как запасной вариант.

| Плата | Файл ядра | Видео | Звук |
|---|---|---|---|
| Karabas Go | `atari2600.kg` | VGA | I2S ЦАП (PCM5102) |
| Karabas Mini | `atari2600.kg` | HDMI | HDMI, аналоговый выход (сигма-дельта) |
| Karabas Mini G | `atari2600.kg` | HDMI | HDMI, I2S ЦАП |

Файл ядра лежит в `src/`. При старте в слоте картриджа — Legendary Spear, homebrew-игра DChristianson (MIT, `src/roms`). Других игр в ядре нет: свои образы картриджей положите на SD-карту в `/atari2600`.

Состояние: проверено на Mini G. Сборки для Go и Mini на платах ещё не запускались.

## Что умеет

- **Машина:** 6507 на 1,19 МГц, TIA, RIOT 6532; NTSC, PAL и SECAM.
- **Картриджи:** образы `.a26` / `.bin` до 512 КБ (с SD-карты, через OSD), маппер определяется по образу: 2K, 4K, F8, F6, F4, FA, FA2 (без сохранения его флеша), FE, E0, E7, 3F, 3E, CV, UA, F0, 32-in-1, P2 (DPC, Pitfall II), AR (Supercharger), SB, WD, EF, 0840, DF, FC, JANE, MC, CTY, ОЗУ SuperChip. Некоторые (FE, CTY, MC, 32-in-1) автоопределение не узнаёт: их выбирают в пункте Mapper. AR и JANE не проверялись. Картриджи с ARM (DPC+, CDF, ACE, ELF) не поддерживаются: на экране «Out of Order».
- **Видео:** 160 × 240 TIA в кадровом буфере, на выходе 1024 × 768 60 Гц (каждая точка 6 × 3, картинка 960 × 720 посередине). PAL-игры (50 Гц) показываются с повтором кадров.
- **Звук:** два канала TIA.
- **Контроллеры:** два джойстика (USB-геймпады, клавиатура — левый джойстик); пэдлы от мыши и геймпадов; вторая и третья кнопки геймпада — как Booster Grip.

## Как начать

1. Скопируйте `atari2600.kg` (один файл для Go, Mini и Mini G) в корень SD-карты.
2. Положите свои образы картриджей в `/atari2600` на SD-карте.
3. Выберите Atari 2600 в меню ядер. Запустится Legendary Spear. Откройте OSD (**Menu+Esc**) и выберите другой образ в пункте Cartridge (**Menu+C**).

«Menu» — клавиша Windows на клавиатуре.

## Меню OSD

| Пункт | Значения | Горячая клавиша |
|---|---|---|
| Cartridge | образ `.a26` / `.bin` | Menu+C |
| Reset | сброс машины | F12 |
| TV Type | Color / B&W (переключатель приставки) | Menu+T |
| Left Diff, Right Diff | B / A (переключатели сложности) | Menu+L, Menu+R |
| Mapper | Auto / FE / CTY / MC 2K / MC 4K / MC 8K / 32-in-1 / E0 / E7 / 3E / 3F / UA / 0840 / SB / WD / F0 | |
| Region | Auto / NTSC / PAL / SECAM | |
| Controller | Joystick / Paddles (левый порт) | Menu+P |

Настройки запоминаются. Смена Mapper перезапускает машину (картридж загружается заново). Region Auto выбирает NTSC или PAL по числу строк игры; SECAM нужно выбрать самому.

## Управление

| Приставка / контроллер | Клавиатура | USB-геймпад |
|---|---|---|
| Левый джойстик | стрелки, огонь: пробел или левый Ctrl, Fire 2: левый Alt | левый геймпад: A — огонь, B — Fire 2, C — Fire 3 |
| Правый джойстик | | правый геймпад |
| Game Reset | F2 | Start |
| Game Select | F1 | Mode или X |
| Сброс машины | F12 | |

**Пэдлы** (Controller = Paddles): пэдл A — мышь (влево-вправо; огонь — левая кнопка) и влево / вправо левого джойстика; пэдл B — влево / вправо правого геймпада (огонь — правая кнопка мыши или огонь правого геймпада).

## Сборка

Клонируйте с `--recursive` (подмодуль `modules`). ISE 14.7: `cd src && make` для всех плат или `make minig` для одной. Верхи Mini и Go (и временную часть их ucf) делает из верха Mini G `src/tools/mktops.py`; переведённые исходники k7800 (`src/rtl/sv2v`) — `src/tools/sv2v.sh`. Проверки в Verilator: `src/sim/run_checks.sh` (машина), `src/sim/run_board.sh` (сторона платы). План и заметки о решениях — в [docs/PLAN.md](docs/PLAN.md).

## Лицензия

Части Karabas — GPL v3 ([LICENSE](LICENSE)); k7800 — MIT, A2601 / A2600Nano — GPL v3, Legendary Spear — MIT (`src/roms/LICENSE-legendary-spear`). Импортированные файлы сохраняют лицензионные заголовки своих авторов.
