#!/bin/bash
#
# Split a QDEC long table into one table per subject.
#
# Requires the other qdec scripts (qdec_list_subjects.bash and qdec_extract_subject.bash) to be
# in the directory of the current script (no matter where it was called from).
#
# Written by TS, 2021-10-21

full_table_file="$1"

if [ -z "$full_table_file" ]; then
  echo "USAGE: $0 <qdec_table>"
  echo "  <qdec_table>: Path to the full QDEC longitudinal table file that should be split."
  exit 1
fi

if [ ! -f "$full_table_file" ]; then
  echo "ERROR: Input file '${full_table_file}' cannot be read. Exiting."
  exit 1
fi

# Check for required scripts in the directory of the current script (no matter where it was called from).
exec_path_of_this_script=$(dirname $0)
list_subjects_script="${exec_path_of_this_script}/qdec_list_subjects.bash"
if [ ! -x "${list_subjects_script}" ]; then
  echo "ERROR: List subjects script not executable or cannot be read at '${list_subjects_script}'. Exiting."
  exit 1
fi
extract_subject_script="${exec_path_of_this_script}/qdec_extract_subject.bash"
if [ ! -x "${extract_subject_script}" ]; then
  echo "ERROR: Extract subject script not executable or cannot be read at '${extract_subject_script}'. Exiting."
  exit 1
fi

# Okay, start the actual work.
subject_ids=$(${list_subjects_script} ${full_table_file})
num_subjects=$(echo "${subject_ids}" | wc -w | tr -d '[:space:]')

echo "Found ${num_subjects} subjects in longitudinal QDEC table '${full_table_file}'."
if [ $num_subjects -gt 0 ]; then
  qdec_output_dir=$(dirname "$full_table_file")
  for subject in $subject_ids; do
    qdec_filename_subject="qdec_subject_table_${subject}.dat"
    qdec_fullfile_subject="${qdec_output_dir}/${qdec_filename_subject}"
    echo " * Writing subject $subject table to file '$qdec_fullfile_subject'."
    ${extract_subject_script} ${full_table_file} ${subject} > ${qdec_fullfile_subject}
  done
  echo "Subject tables written to directory '${qdec_output_dir}'."
else
  echo "WARNING: No subjects found in file '${full_table_file}', nothing to do. Exiting."
  exit 1
fi

exit 0
