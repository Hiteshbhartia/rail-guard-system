#!/usr/bin/env bash
# Compile and run the Smart Railway Crossing testbench with Icarus Verilog.
set -e

cd "$(dirname "$0")/.."
mkdir -p sim

echo "[1/3] Compiling ..."
iverilog -g2005 -Wall -o sim/railway_crossing.out \
    rtl/railway_crossing_controller.v \
    tb/tb_railway_crossing_controller.v

echo "[2/3] Running simulation ..."
vvp sim/railway_crossing.out

echo "[3/3] Done. VCD written to sim/railway_crossing.vcd"
echo "View it with:  gtkwave sim/railway_crossing.vcd"
