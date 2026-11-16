@echo off
REM Runs every Phase-I testbench with Icarus Verilog on Windows.
REM Usage:  cd sim  then  run_all.bat
cd /d %~dp0
set FLAGS=-g2005 -Wall
python ..\model\golden_model.py
iverilog %FLAGS% -o tb_mac_unit.vvp ..\rtl\mac_unit.v ..\tb\tb_mac_unit.v && vvp -n tb_mac_unit.vvp
iverilog %FLAGS% -o tb_pe.vvp ..\rtl\mac_unit.v ..\rtl\pe.v ..\tb\tb_pe.v && vvp -n tb_pe.vvp
iverilog %FLAGS% -o tb_systolic_array.vvp ..\rtl\mac_unit.v ..\rtl\pe.v ..\rtl\input_skew.v ..\rtl\systolic_array.v ..\tb\tb_systolic_array.v && vvp -n tb_systolic_array.vvp
iverilog %FLAGS% -o tb_systolic_top.vvp ..\rtl\mac_unit.v ..\rtl\pe.v ..\rtl\input_skew.v ..\rtl\systolic_array.v ..\rtl\matrix_buffer.v ..\rtl\systolic_controller.v ..\rtl\systolic_top.v ..\tb\tb_systolic_top.v && vvp -n tb_systolic_top.vvp
echo.
echo Done. Open waveforms with e.g.:  gtkwave tb_systolic_top.vcd top.gtkw
