# =============================================================================
# Makefile - Icarus Verilog simulation flow  (run from the sim/ directory)
# Owner    : Member 5
#   make mac      MAC unit testbench
#   make pe       Processing Element testbench
#   make array    4x4 array + skew testbench
#   make vectors  regenerate golden-model vectors (Python 3)
#   make top      full system testbench (uses golden vectors)
#   make all      everything above
#   make wave_<x> open GTKWave on the VCD of target x (e.g. make wave_top)
#   make clean
# =============================================================================
IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3
FLAGS    := -g2005 -Wall

RTL := ../rtl/mac_unit.v ../rtl/pe.v ../rtl/input_skew.v ../rtl/systolic_array.v \
       ../rtl/matrix_buffer.v ../rtl/systolic_controller.v ../rtl/systolic_top.v

.PHONY: all mac pe array top vectors clean

all: mac pe array top

mac:
	$(IVERILOG) $(FLAGS) -o tb_mac_unit.vvp ../rtl/mac_unit.v ../tb/tb_mac_unit.v
	$(VVP) -n tb_mac_unit.vvp

pe:
	$(IVERILOG) $(FLAGS) -o tb_pe.vvp ../rtl/mac_unit.v ../rtl/pe.v ../tb/tb_pe.v
	$(VVP) -n tb_pe.vvp

array:
	$(IVERILOG) $(FLAGS) -o tb_systolic_array.vvp ../rtl/mac_unit.v ../rtl/pe.v \
	    ../rtl/input_skew.v ../rtl/systolic_array.v ../tb/tb_systolic_array.v
	$(VVP) -n tb_systolic_array.vvp

vectors:
	$(PYTHON) ../model/golden_model.py

top: vectors
	$(IVERILOG) $(FLAGS) -o tb_systolic_top.vvp $(RTL) ../tb/tb_systolic_top.v
	$(VVP) -n tb_systolic_top.vvp

wave_mac:   ; gtkwave tb_mac_unit.vcd       mac.gtkw   &
wave_pe:    ; gtkwave tb_pe.vcd             pe.gtkw    &
wave_array: ; gtkwave tb_systolic_array.vcd array.gtkw &
wave_top:   ; gtkwave tb_systolic_top.vcd   top.gtkw   &

clean:
	rm -f *.vvp *.vcd
