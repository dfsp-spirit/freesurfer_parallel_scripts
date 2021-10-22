#!/bin/bash
#
# qdec_get_subjects.bash -- List all subject IDs contained in a QDEC longitudinal table.
#
# Notes:
# * This script assumes that in the intput QDEC file, the different time points
#   for a single subject are listed in consecutive rows.
# * The order of subjects is preserved.
#
# Written by TS, 2021-10-13

qdec_file="$1"

if [ -z "$qdec_file" ]; then
  echo "USAGE: $0 <qdec_long_file>"
  echo "  <qdec_long_file> : path to a FreeSurfer QDEC longitudinal table (.dat) file."
  echo "Note: You can get subjects separated by newlines instead of spaces by piping the"
  echo "      ouput of this command to tr, e.g.: $0 qdec.table.dat | tr ' ' '\n'"
  exit 0
fi

if [ ! -z "$2" ]; then
  >&2 echo "WARNING: Command line arguments after 1st one ignored."
fi

if [ ! -f "$qdec_file" ]; then
  echo "ERROR: The file '$qdec_file' does not exist or cannot be read."
  exit 1
fi

qdec_subjects=$(awk '(NR>1)' ${qdec_file} | awk '{print $2}' | uniq)
echo $qdec_subjects

exit 0
