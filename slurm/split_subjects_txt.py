#!/usr/bin/env python
#
#
# This script splits a subjects.txt file into chunks, where the user can supply the count of chunks.
# This is useful if you are running jobs on a cluster that has a limit on the number of jobs a user
# can submit, and always assigns to a single job an entire node (aka worker, aka multi-core machine).
#
# In that scenario, you can assign more than one FreeSurfer subject per job (and node): you should assign
# as many subjects to one node as the node has CPU cores, or more. In the best case, you assign
# `num_total_subjects / max_jobs` per node.
# The only problem is that this number may be higher than the number of cores on the nodes, so that the
# jobs will fight for resources and everything will become very slow. The solution is to use a local
# scheduler on each node. Such a scheduler is GNU parallel: it allows you to assign an arbitrary number
# of subjects/freesurfer jobs to the cores of a single node, but only run as many at a time as the node
# has cores. This strategy is implemented in this script.
#
# It requires FreeSurfer and GNU parallel to be available (or installed by you) on the worker nodes. In
# case of a shared file system, you can of course simply access a single installation from your $HOME on
# all nodes. Often GNU parallel is available via the module system of a cluster.
#
# Written by Tim Schaefer, 2024-06-04
#
# This script was tested with Python 3.8, but care was taken not to depend on very recent Python features.

from typing import List, Union
import math
import numpy as np
import logging
import argparse
import os.path
import sys

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
sh = logging.StreamHandler(sys.stdout)
fmt_interactive = logging.Formatter("%(asctime)s - %(levelname)s: %(message)s", "%H:%M:%S")
sh.setFormatter(fmt_interactive)
logger.addHandler(sh)



def read_subjects_file(subjects_file : str) -> List[str]:
    with open(subjects_file) as file:
        subjects = [l.strip() for l in file.readlines()]
    return subjects


def split_subjects_txt_into_chunks(subjects_file : str, num_parallel_jobs : Union[int, None] = None):
    """
    Split subjects file into chunks.
    @param subjects_file: str, path to text file containing one subject per line (no header line).
    @param num_parallel_jobs: if int, the number of maximal chunks to write. If set to None (the default), the script will assign one file/job per subject.
    @return int, the number of subject files written
    """

    subjects : List[str] = read_subjects_file(subjects_file)

    num_subjects : int = len(subjects)

    if num_parallel_jobs is None:
        num_parallel_jobs = num_subjects

    if num_subjects < num_parallel_jobs:
        num_parallel_jobs = num_subjects
        logger.info(f"Note: Received only {num_subjects} subjects, so will only run {num_parallel_jobs} jobs (even if {num_parallel_jobs} are allowed).")


    num_subjects_per_job : int = math.ceil(num_subjects / num_parallel_jobs)
    num_in_last_job : int = num_subjects_per_job if num_subjects % num_subjects_per_job == 0 else num_subjects % num_subjects_per_job
    num_jobs_required : int = math.ceil(num_subjects / num_subjects_per_job)
    if num_jobs_required < num_parallel_jobs:
        logger.info(f"Will only use {num_jobs_required} out of {num_parallel_jobs} possible jobs.")
        num_parallel_jobs = num_jobs_required
    logger.info(f"Received {num_subjects} subjects and max jobs = {num_parallel_jobs}")
    logger.info(f"Using {num_subjects_per_job} subjects per job, last job will contain {num_in_last_job} subjects.")


    num_subjects_per_job : List[int] = [num_subjects_per_job] * num_parallel_jobs
    if num_in_last_job != num_subjects_per_job:
        num_subjects_per_job[-1] = num_in_last_job
    num_jobs = np.sum(num_subjects_per_job)
    assert num_jobs == num_subjects, f"Mismatch between sum of job count list and total number of subjects in source subjects file."
    logger.info(f'Subjects per job ({len(num_subjects_per_job)} entries, sum={num_jobs}): {num_subjects_per_job} ')

    subjects = np.array(subjects)
    current_idx : int = 0
    for jobidx, subjects_count_current_job in enumerate(num_subjects_per_job):
        start_idx : int = current_idx
        end_idx : int = start_idx + subjects_count_current_job
        logger.info(f"At job {jobidx+1} (index {jobidx}) of {num_parallel_jobs}: using subject indices {start_idx} to {end_idx}.")
        subjects_this_job = subjects[start_idx:end_idx]
        assert len(subjects_this_job) == subjects_count_current_job, f"Expected {subjects_count_current_job} subjects, got {len(subjects_this_job)} at job with index {jobidx}."
        subjects_file_lines : str = "\n".join(subjects_this_job)
        tfile : str = f"subjects_job{jobidx}.txt"
        write_to_textfile(tfile, subjects_file_lines)
        current_idx = end_idx

    logger.info(f"All {len(num_subjects_per_job)} files written.")

    return len(num_subjects_per_job)


def write_to_textfile(filepath : str, contents : str) -> None:
    f = open(filepath, "w")
    f.write(contents)
    f.close()
    logger.info(f"Result written to file '{filepath}'.")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Split subjects.txt file into N chunks.')
    parser.add_argument('num_chunks', type=int, help='The number of chunks, typically the number of jobs you are allowed to run on the cluster.')
    parser.add_argument('--subjects-file', type=str,
                    help='The input subjects file that should be split.', default="subjects.txt")
    args = parser.parse_args()


    subjects_file = args.subjects_file
    num_parallel_jobs = args.num_chunks
    logger.info(f"Splitting file '{subjects_file}' into {num_parallel_jobs} chunks.")
    num_files : int  = split_subjects_txt_into_chunks(subjects_file, num_parallel_jobs)
    if os.path.isfile(f"subjects_job{num_files}.txt"):
        logger.warning(f"WARNING: Wrote {num_files} subjects files (subjects_job0.txt .. subjects_job{num_files -1}.txt), but the file 'subjects_job{num_files}.txt' also exists, maybe from an older run?")
        logger.warning(f"WARNING (cont.): You may want to delete old 'subjects_job*' files before a run to avoid confusion.")



