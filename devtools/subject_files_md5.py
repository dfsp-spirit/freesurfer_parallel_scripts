#!/usr/bin/which python
#
# This script computes the md5sum of all relevant files in a FreeSurfer subject directory.
# It also allows to copy the files to a specified directory.
#
# This script is used for preparing a FreeSurfer subject for upload to our web server, so
# that users of the fsbrain R package can download the subject and use it in R after they
# accept the FreeSurfer license agreement.
#
# Written by Tim Schaefer, 2024. License: MIT. Tested with Python 3.10.

import os
from typing import List
import logging
import sys

logger = logging.getLogger(__name__)

def md5sum(filename : str) -> str:
    import hashlib
    md5 = hashlib.md5()
    with open(filename, 'rb') as f:
        for chunk in iter(lambda: f.read(128 * md5.block_size), b''):
            md5.update(chunk)
    return md5.hexdigest()


def add_file_entry(path : str, files_list : List[List[str]], new_entry : List[str]) -> None:
    if not os.path.exists(os.path.join(path, *new_entry)):
        logger.warning("File not found, skipping: " + os.path.join(path, *new_entry))
        return
    if new_entry not in files_list:
        files_list.append(new_entry)
    else:
        logger.warning("File already in list, skipping: " + os.path.join(path, *new_entry))


def get_relevant_subject_files(path : str) -> List[List[str]]:
    subject_files = []

    # ---------- Handle all stuff under mri/ ----------

    subdir = "mri"
    for file in ["brainmask.mgz", "orig.mgz", "T1.mgz", "aseg.mgz", "brain.mgz"]:
        file_entry = [subdir, file]
        add_file_entry(path, subject_files, file_entry)


    # Now handle all the paired files, which exist for both hemispheres

    for hemi in ["lh", "rh"]:

        # ---------- Handle all stuff under surf/ ----------
        subdir = "surf"

        # Surfaces
        for surf in ["inflated", "pial", "sphere", "white"]:
            file_entry = [subdir, hemi + "." + surf]
            add_file_entry(path, subject_files, file_entry)

        # Curvatures (native space)
        for curv in ["thickness", "area", "curv", "sulc", "volume"]:
            file_entry = [subdir, hemi + "." + curv]
            add_file_entry(path, subject_files, file_entry)

        # Surface registration files
        for curv in ["sphere.reg"]:
            file_entry = [subdir, hemi + "." + curv]
            add_file_entry(path, subject_files, file_entry)

        # Curvatures mapped to standard space
        smoothings = ["10"]
        for smoothing in smoothings:
            for curv in ["thickness", "area", "sulc"]:
                mapped_file = hemi + "." + curv + ".fwhm" + smoothing + ".fsaverage.mgh"
                file_entry = [subdir, mapped_file]
                add_file_entry(path, subject_files, file_entry)


        # ---------- Handle all stuff under label/ ----------
        subdir = "label"

        # Labels
        for label in ["cortex.label"]:
            mapped_file = hemi + "." + label
            file_entry = [subdir, mapped_file]
            add_file_entry(path, subject_files, file_entry)

        # Atlases
        for label in ["aparc.annot", "aparc.a2009s.annot"]:
            mapped_file = hemi + "." + label
            file_entry = [subdir, mapped_file]
            add_file_entry(path, subject_files, file_entry)

    return subject_files


def subject_files_md5():
    import argparse
    parser = argparse.ArgumentParser(description='Compute md5sum of all relevant subject files')
    parser.add_argument('subject_dir', type=str, help='Path to the subject directory (<SUBJECTS_DIR>/<your_subject>).')
    parser.add_argument('--print', type=str, help='What to print, one of "md5", "fullpath", "innerpath", "Rpath", "full_with_md5", or "all". Defaults to "full_with_md5".', default="full_with_md5")
    parser.add_argument('--copy', type=str, help='Optional, a directory where to copy the files for which md5sums were computed. Must exist and be writable. Omit if you do not want to copy.')
    args = parser.parse_args()

    subject_dir = args.subject_dir
    toprint = args.print
    subject_files = get_relevant_subject_files(subject_dir)
    copydir = args.copy


    if not os.path.exists(subject_dir):
        logger.error("Subject directory not found: " + subject_dir)
        sys.exit(1)

    if not toprint in ["md5", "fullpath", "innerpath", "Rpath", "full_with_md5", "all"]:
        logger.error("Invalid print option: " + toprint)
        sys.exit(1)

    for file in subject_files:
        file_path = os.path.join(subject_dir, *file)

        if copydir:
            if not os.path.exists(copydir):
                logger.error("Copy directory specified with argument --copy not found, it must exist: '" + copydir + "'")
                sys.exit(1)
            else:
                import shutil
                copy_path = os.path.join(copydir, *file)
                os.makedirs(os.path.dirname(copy_path), exist_ok=True)
                shutil.copy(file_path, copy_path)

        inner_path = os.path.join(*file)
        custom_path_for_R = "c(base_path_subject, " + ",".join(f"'{f}'" for f in file) + "),"
        #print(md5sum(file_path) + "  " + file_path + "  " + inner_path + "  " + custom_path_for_R)
        if toprint == "md5" or toprint == "all":
            print(md5sum(file_path))
        if toprint == "fullpath" or toprint == "all":
            print(file_path)
        if toprint == "innerpath" or toprint == "all":
            print(inner_path)
        if toprint == "Rpath" or toprint == "all":
            print(custom_path_for_R)
        if toprint == "full_with_md5" or toprint == "all":
            print(md5sum(file_path) + "  " + file_path)


if __name__ == "__main__":
    subject_files_md5()