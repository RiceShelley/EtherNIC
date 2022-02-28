#!/bin/bash
#
# Bash program to run all the simulations in ../sim

SIM_DIRS="../sim/*/"
#source venv/bin/activate
for d in $SIM_DIRS; do
	[ -L "${d%/}" ] && continue
#	cd $d
	source venv/bin/activate
	echo "$d"
	make -f $d"Makefile" || exit
done
