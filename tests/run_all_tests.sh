#!/bin/bash
#
# Bash program to run all the simulations in ../sim
set -e
SIM_DIRS="../sim/*/"
IGNORE_FAILS=""		# Empty to pass nothing to find_failures.py
PRINT_HELP=0

IGN_FAIL_ARG="--ignore-fails"
FAST_FAIL_ARG="--fast-fail"

for i in "$@"; do
  case $i in
    -h|--help)
      PRINT_HELP=1
      shift
      ;;
    "$IGN_FAIL_ARG")
      IGNORE_FAILS=$IGN_FAIL_ARG
      shift # past argument with no value
      ;;
    "$FAST_FAIL_ARG")
      IGNORE_FAILS=$FAST_FAIL_ARG
      shift
      ;;
    -*|--*)
      echo "Unknown option $i. Add -h for help info."
      exit 1
      ;;
    *)
      ;;
  esac
done

if [ $PRINT_HELP -eq 1 ]; then
  echo "This bash script helps run all simulation in the sim dir."
  echo "Each cocotb sim should be in their own directory under sim/"
  echo
  echo "Available args:"
  echo "-h|--help	For this help info."
  echo "$IGN_FAIL_ARG	To not end this script on the first sim failure."
  echo "$FAST_FAIL_ARG	To end the script on the first sim fail."
  echo "		  This is required to return a non-zero exit code."
  exit 0
fi

echo "On failure...	 ${IGNORE_FAILS}"

for d in $SIM_DIRS; do		# Parenthesis - Run in subshell so cd resets each loop
  (
  [ -L "${d%/}" ] && continue	# Ignore symlinks
  cd $d
  make
  python3 ../../tests/find_failures.py results.xml $IGNORE_FAILS
  )
done

