# -------------------------------------------------------------
# file: plot.gp
# -------------------------------------------------------------
# -------------------------------------------------------------
# Battelle Memorial Institute
# Pacific Northwest Laboratory
# -------------------------------------------------------------
# -------------------------------------------------------------
# Created July  2, 1999 by William A. Perkins
# Last Change: Fri Sep 17 08:51:17 1999 by William A. Perkins <perk@erebus.pnl.gov>
# -------------------------------------------------------------
# $Id$


set format x "%.0f"
set xlabel "Distince Along Channel, feet"

set format y "%.0f"
set nokey

set pointsize 0.5

set multiplot
set origin 0.0, 0.5
set size 1.0, 0.5
set lmargin 8

set ylabel "Simulated Discharge, cfs"
set yrange [0:2000]

plot 'profile1.out' using (10656 - $4):6 with linespoints

set origin 0.0, 0.0
set size 1.0, 0.5
set lmargin 8

set title ''

set ylabel "Simulated Temperature, C"
set yrange [0:25]

plot 'profile1.out' using (10656 - $4):10 with linespoints

set nomultiplot
