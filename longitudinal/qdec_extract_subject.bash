#!/bin/bash
#
# qdec_extract_subject.bash -- Extract rows for a single specific subject ID contained in a QDEC longitudinal table.
#
#
# Written by TS, 2021-10-20

qdec_file="$1"
subject_id="$2"

if [ -z "$subject_id" ]; then
  echo "USAGE: $0 <qdec_long_file> <subject_id>"
  echo "  <qdec_long_file> : path to a FreeSurfer QDEC longitudinal table (.dat) file."
  echo "  <subject_id>     : the base name of the subject (without any long/_MR suffixes)."
  echo "Note: You can redirect the ouput of this script into a file to create a new table."
  exit 0
fi

if [ ! -z "$3" ]; then
  >&2 echo "WARNING: Command line arguments after 2nd one ignored."
fi

if [ ! -f "$qdec_file" ]; then
  >&2 echo "ERROR: The file '$qdec_file' does not exist or cannot be read."
  exit 0
fi

hdr=$(awk '(NR==1)' ${qdec_file})
if [ -z "$hdr" ]; then
    >&2 echo "ERROR: No header line found in qdec file '$qdec_file'. Empty file?"
    exit 0
fi

res=$(awk '(NR>1)' ${qdec_file} | awk -v subject_id_awk="${subject_id}" '$2 == subject_id_awk')
if [ -z "$res" ]; then
    >&2 echo "ERROR: No entries for subject '$subject_id' found in qdec file '$qdec_file'."
    >&2 echo "ERROR: (cont.): You can use the 'qdec_get_subjects.bash' script to list all subjects in the file."
    exit 0
fi


awk '(NR==1)' ${qdec_file}     # print header line.
awk '(NR>1)' ${qdec_file} | awk -v subject_id_awk="${subject_id}" '$2 == subject_id_awk'   # print lines for subject.


exit 1
