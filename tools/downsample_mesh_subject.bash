#!/bin/bash
# Downsamples the mesh for a subject, both hemispheres.

subject_id="$1"


if [ -z "$subject_id" ]; then
  echo "Usage: $0 <subject_id> [<target_template> <trgicoorder>]"
  echo "  <subject_id>: char, the subject directory name."
  echo "  <target_template>: optional. char, the template subject. Defaults to 'fsaverage6'."
  echo "  <trgicoorder>: optional. int, the triaangle ico order for the target_template. Defaults to 6. Must be given for non-standard target_template."
  echo " Hint: the <trgicoorder> is 7 for fsaverage, 6 for fsaverage6, 5 for fsaverage5, and so on."
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

for hemi in lh rh; do
  mri_surf2surf --hemi $hemi --srcsubject $subject_id --sval-xyz pial --trgsubject "${target_template}" --trgicoorder $trgicoorder --tval-xyz "${subject_id}/mri/brain.mgz"  --tval ${subject_id}/surf/"${hemi}.pialsurface${trgicoorder}"
done
