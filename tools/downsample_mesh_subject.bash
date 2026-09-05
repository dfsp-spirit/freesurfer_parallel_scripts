#!/bin/bash
# Downsamples the native-space surfaces (white and pial), per-vertex measures (thickness and sulc), and the cortex label for a subject, both hemispheres.

subject_id="$1"


if [ -z "$subject_id" ]; then
  echo "Usage: $0 <subject_id> [<target_template> <trgicoorder>]"
  echo "  <subject_id>: char, the subject directory name."
  echo "  <target_template>: optional. char, the template subject. Defaults to 'fsaverage6'."
  echo "  <trgicoorder>: optional. int, the triangle ico order for the target_template. Defaults to 6. Must be given for non-standard target_template."
  echo " Hint: the <trgicoorder> is 7 for fsaverage, 6 for fsaverage6, 5 for fsaverage5, and so on."
  echo " Note: The SUBJECTS_DIR environment variable must be set correctly (the subject and template are looked up in it)."
  echo "       This also downsamples the measures 'thickness' and 'sulc', and the cortex label, if those input files exist."
  echo "       A one-line-per-file report is printed at the end."
  exit 1
fi

target_template="fsaverage6"
trgicoorder=6

if [ -n "$2" -a -z "$3" ]; then
  echo "ERROR: If <target_template> is modified, the <trgicoorder> must also be given."
  echo "       Run without any arguments for usage details."
  exit 1
fi

if [ -n "$3" ]; then
  target_template="$2"
  trgicoorder=$3
fi

report_lines=""
count_ok=0
count_skip=0
count_fail=0

append_report() {
  # $1 = status (OK, SKIP, FAIL); $2 = source file; $3 = output file (empty for SKIP)
  local status="$1" src="$2" out="$3"
  case "$status" in
    OK)   count_ok=$((count_ok + 1)) ;;
    SKIP) count_skip=$((count_skip + 1)) ;;
    FAIL) count_fail=$((count_fail + 1)) ;;
  esac
  if [ -n "$out" ]; then
    printf -v report_lines '%s%-8s %-52s (from %s)\n' "$report_lines" "$status" "$out" "$src"
  else
    printf -v report_lines '%s%-8s (input missing: %s)\n' "$report_lines" "$status" "$src"
  fi
}

for hemi in lh rh; do

  ## Downsample the surfaces (native-space geometry at the target resolution).
  for surface in white pial; do
    src_surface="${subject_id}/surf/${hemi}.${surface}"
    out_surface="${subject_id}/surf/${hemi}.${surface}surface${trgicoorder}"
    if [ ! -f "${src_surface}" ]; then
      append_report "SKIP" "${src_surface}" ""
      continue
    fi
    if mri_surf2surf --hemi ${hemi} --srcsubject "${subject_id}" --sval-xyz ${surface} --trgsubject "${target_template}" --trgicoorder ${trgicoorder} --tval-xyz "${subject_id}/mri/brain.mgz" --tval "${out_surface}" > /dev/null 2>&1; then
      append_report "OK" "${src_surface}" "${out_surface}"
    else
      append_report "FAIL" "${src_surface}" "${out_surface}"
    fi
  done

  ## Downsample per-vertex measures.
  for measure in thickness sulc; do
    src_measure="${subject_id}/surf/${hemi}.${measure}"
    out_measure="${subject_id}/surf/${hemi}.${measure}.${target_template}.mgh"
    if [ ! -f "${src_measure}" ]; then
      append_report "SKIP" "${src_measure}" ""
      continue
    fi
    if mris_apply_reg --src "${src_measure}" --streg "${subject_id}/surf/${hemi}.sphere.reg" "${target_template}/surf/${hemi}.sphere.reg" --trg "${out_measure}" > /dev/null 2>&1; then
      append_report "OK" "${src_measure}" "${out_measure}"
    else
      append_report "FAIL" "${src_measure}" "${out_measure}"
    fi
  done

  ## Downsample the medial wall (cortex) label.
  src_label="${subject_id}/label/${hemi}.cortex.label"
  out_label="${subject_id}/label/${hemi}.cortex${trgicoorder}.label"
  if [ ! -f "${src_label}" ]; then
    append_report "SKIP" "${src_label}" ""
  elif mri_label2label --srclabel "${src_label}" --srcsubject "${subject_id}" --trglabel "${out_label}" --trgsubject ico --regmethod surface --hemi ${hemi} --trgicoorder ${trgicoorder} > /dev/null 2>&1; then
    append_report "OK" "${src_label}" "${out_label}"
  else
    append_report "FAIL" "${src_label}" "${out_label}"
  fi

done

## Final report: one line per file.
echo "================================================================================"
echo "Downsampling report for subject '${subject_id}' -> template '${target_template}' (ico ${trgicoorder})"
echo "================================================================================"
printf '%s' "$report_lines"
echo "================================================================================"
echo "Result: ${count_ok} succeeded, ${count_skip} skipped (input missing), ${count_fail} failed."

if [ ${count_fail} -gt 0 ]; then
  exit 1
fi
exit 0
