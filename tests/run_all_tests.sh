#!/bin/bash
#
# Bash program to run all the simulations in ../sim

SIM_DIRS="../sim/*/"
for d in $SIM_DIRS; do		# Parenthesis - Run in subshell so cd resets each loop
	(
	[ -L "${d%/}" ] && continue	# Ignore symlinks
	cd $d
	make || exit
	)
done

