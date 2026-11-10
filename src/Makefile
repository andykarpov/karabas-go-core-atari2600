# Atari 2600 VCS core: the ISE 14.7 flow of all boards (as core-archie / core-atarist).
#
#   make minig           a board: <board>-xst (.ngc), <board>-impl (.bin), <board>-core (.kg)
#   make minig-report    LUTs, slices, block RAMs and the timing result of the last build
#   make a2601-xst       the fallback machine alone (A2601 of A2600Nano, a2601.prj, -iobuf NO): fit check
#   make k7800-parts-xst the converted k7800 parts alone (TIA, mos6502; k7800_parts.prj from tools/sv2v.sh)
#   make <name>-report   utilization from the .syr of a2601 / k7800_TIA / k7800_mos6502
#   make clean           the intermediate files (not the .bin / .kg files, they are in git)
#
# Ф0 (docs/PLAN.md) adds the machine top atari2600_top and `make atari2600-xst`, then the board tops.
# Inputs per board: karabas_<board>.prj (the source list, the shared modules as "../modules/rtl/..."),
# karabas_<board>.xst, karabas_<board>.ut, karabas_<board>.ucf. No board has them yet.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh
PART = xc6slx25-ftg256-2
BOARDS = go mini minig

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c
.NOTPARALLEL:

# settings64.sh takes the arguments of the shell that sources it: none here
XIL = source $(ISE_SETTINGS) > /dev/null;

# all boards in one file: a board build puts its bitstream in (make_core --boards)
KG = atari2600.kg
JSON = core.json

# map / par options (cost table 2 by default, the rule of all the cores)
MAP_T_go ?= 2
MAP_T_mini ?= 2
MAP_T_minig ?= 2
MAP = -logic_opt off -ol high -xe n -xt 3 -register_duplication off -r 4 -global_opt off -mt 2 -detail -ir off -pr b -lc auto -power off
PAR = -ol high -xe c -mt 4

# included or read by the sources, not in the prj
INCLUDES = $(wildcard ../modules/rtl/mcu/*.vh)

PARTS = a2601 k7800_TIA k7800_mos6502

.PHONY: all clean $(BOARDS) $(BOARDS:=-xst) $(BOARDS:=-impl) $(BOARDS:=-core) $(BOARDS:=-report) \
	a2601-xst k7800-parts-xst $(PARTS:=-report)

all: $(BOARDS)

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

define board
SRC_$(1) := $$(call prj_src,karabas_$(1).prj)

karabas_$(1).ngc: karabas_$(1).prj karabas_$(1).xst $$(SRC_$(1)) $(INCLUDES)
	mkdir -p xst/projnav.tmp
	$(XIL) xst -intstyle ise -ifn karabas_$(1).xst -ofn karabas_$(1).syr

karabas_$(1).bin: karabas_$(1).ngc karabas_$(1).ucf karabas_$(1).ut
	$(XIL) ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc karabas_$(1).ucf -p $(PART) karabas_$(1).ngc karabas_$(1).ngd
	$(XIL) map -intstyle ise -p $(PART) -w $(MAP) -t $(MAP_T_$(1)) -o karabas_$(1)_map.ncd karabas_$(1).ngd karabas_$(1).pcf
	$(XIL) par -w -intstyle ise $(PAR) karabas_$(1)_map.ncd karabas_$(1).ncd karabas_$(1).pcf
	$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths -xml karabas_$(1).twx karabas_$(1).ncd -o karabas_$(1).twr karabas_$(1).pcf -ucf karabas_$(1).ucf
	$(XIL) bitgen -intstyle ise -f karabas_$(1).ut karabas_$(1).ncd

kg_$(1).stamp: karabas_$(1).bin $(JSON)
	python3 tools/check_osd.py $(JSON)
	python3 make_core.py $(JSON) $(KG) --boards $(1)
	touch $$@

$(1): kg_$(1).stamp
$(1)-xst: karabas_$(1).ngc
$(1)-impl: karabas_$(1).bin
$(1)-core: kg_$(1).stamp
$(1)-report:
	@grep -E "Number of (Slice LUTs|occupied Slices|RAMB16BWERs|RAMB8BWERs):" karabas_$(1)_map.mrp
	@grep -E "constraints? (was|were) met|constraints? not met|Timing Score" karabas_$(1).par | sort -u
endef

$(foreach b,$(BOARDS),$(eval $(call board,$(b))))

# the machines / parts alone: <name>.xst reads <prj>, -iobuf NO
define part
$(1).ngc: $(2) $(1).xst $$(call prj_src,$(2))
	mkdir -p xst/projnav.tmp
	$(XIL) xst -intstyle ise -ifn $(1).xst -ofn $(1).syr

$(1)-report:
	@sed -n '/Device utilization summary/,/Partition Resource Summary/p' $(1).syr | grep -E "Number of (Slice Registers|Slice LUTs|Block RAM/FIFO|DSP48)"
	@grep -E "Minimum period|Xst:737" $(1).syr | sort -u | head
endef

$(eval $(call part,a2601,a2601.prj))
$(eval $(call part,k7800_TIA,k7800_parts.prj))
$(eval $(call part,k7800_mos6502,k7800_parts.prj))

a2601-xst: a2601.ngc
k7800-parts-xst: k7800_TIA.ngc k7800_mos6502.ngc

clean:
	rm -f kg_*.stamp
	rm -rf xst _ngo _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach b,$(BOARDS),$(addprefix karabas_$(b),.ngc .ngd .ngr .syr .lso .bld .pcf .ncd _map.ncd _map.ngm \
		_map.map _map.mrp _map.xrpt .par .pad _pad.csv _pad.txt .twr .twx .unroutes .xpi .ptwx .bgn .bit .drc \
		_bitgen.xwbt _summary.xml _usage.xml _xst.xrpt _ngdbuild.xrpt _par.xrpt _guide.ncd))
	rm -f $(foreach p,$(PARTS),$(addprefix $(p),.ngc .ngr .syr .lso _xst.xrpt))
