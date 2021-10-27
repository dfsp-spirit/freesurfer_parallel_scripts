#!/bin/bash
# Downsamples the mesh for a subject, both hemispheres.

subject_id="$1"

if [ -z "$subject_id" ]; then
  echo "Usage: $0 <subject_id>"
  exit 1
fi

for hemi in lh rh; do
  mri_surf2surf --hemi $hemi --srcsubject $subject_id --sval-xyz pial --trgsubject fsaverage6 --trgicoorder 6 --tval-xyz "${subject_id}/mri/brain.mgz"  --tval ${subject_id}/surf/"${hemi}.pialsurface6"
done
