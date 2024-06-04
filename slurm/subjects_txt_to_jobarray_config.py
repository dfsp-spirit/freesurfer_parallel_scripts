#!/usr/bin/env python

from typing import List, Union
import math
import numpy as np
import logging

logger = logging.getLogger(__name__)


def read_subjects_file(subjects_file : str) -> List[str]:
    with open(subjects_file) as file:
        subjects = [l.strip() for l in file.readlines()]
    return subjects

def subjects_txt_to_jobarray_config(subjects_file : str, num_parallel_jobs_max : Union[int, None] = None, subject_separator : str = ","):

    subjects : List[str] = read_subjects_file(subjects_file)

    res = "ArrayTaskID NumSubjects Subjects\n"  # header row

    if num_parallel_jobs_max is None:
        num_parallel_jobs_max = len(subjects)

    num_subjects = len(subjects)
    num_full_jobs = math.floor(num_subjects / num_parallel_jobs_max)
    num_in_last_job = num_subjects % num_parallel_jobs_max
    num_jobs_total = num_full_jobs + int(num_in_last_job > 0)

    num_subjects_per_job = [num_parallel_jobs_max] * num_full_jobs
    if num_jobs_total > num_full_jobs:
        num_subjects_per_job.append(num_in_last_job)

    subjects = np.array(subjects)
    current_idx = 0
    for jobidx, subjects_count_current_job in enumerate(num_subjects_per_job):
        start_idx = current_idx
        end_idx = start_idx + subjects_count_current_job
        logger.info(f"At job {jobidx+1} (index {jobidx}) of {num_jobs_total}: using subject indices {start_idx} to {end_idx}.")
        subjects_this_job = subjects[start_idx:end_idx]
        assert len(subjects_this_job) == subjects_count_current_job, f"Expected {subjects_count_current_job} subjects, got {len(subjects_this_job)} at job with index {jobidx}."
        subjects_string_this_job = subject_separator.join(subjects_this_job.tolist())
        res += f"{jobidx} {subjects_count_current_job} {subjects_string_this_job}\n"
        current_idx = end_idx

    return res


def split_subjects_txt_into_chunks(subjects_file : str, num_parallel_jobs : Union[int, None] = None):

    subjects : List[str] = read_subjects_file(subjects_file)

    res = "ArrayTaskID NumSubjects Subjects\n"  # header row

    num_subjects = len(subjects)

    if num_parallel_jobs is None:
        num_parallel_jobs = num_subjects

    if num_subjects < num_parallel_jobs:
        num_parallel_jobs = num_subjects
        logger.info(f"Note: Received only {num_subjects} subjects, so will only run {num_parallel_jobs} jobs (even if {num_parallel_jobs} are allowed).")


    num_subjects_per_job = math.ceil(num_subjects / num_parallel_jobs)
    num_in_last_job = num_subjects_per_job if num_subjects % num_subjects_per_job == 0 else num_subjects % num_subjects_per_job
    num_jobs_required = math.ceil(num_subjects / num_subjects_per_job)
    if num_jobs_required < num_parallel_jobs:
        logger.info(f"Will only use {num_jobs_required} out of {num_parallel_jobs} possible jobs.")
        num_parallel_jobs = num_jobs_required
    logger.info(f"Received {num_subjects} subjects and max jobs = {num_parallel_jobs}")
    logger.info(f"Using {num_subjects_per_job} subjects per job, last job will contain {num_in_last_job} subjects.")


    num_subjects_per_job = [num_subjects_per_job] * num_parallel_jobs
    if num_in_last_job != num_subjects_per_job:
        num_subjects_per_job[-1] = num_in_last_job
    logger.info(f'Subjects per job ({len(num_subjects_per_job)} entries): {num_subjects_per_job} ')

    subjects = np.array(subjects)
    current_idx = 0
    for jobidx, subjects_count_current_job in enumerate(num_subjects_per_job):
        start_idx = current_idx
        end_idx = start_idx + subjects_count_current_job
        logger.info(f"At job {jobidx+1} (index {jobidx}) of {num_parallel_jobs}: using subject indices {start_idx} to {end_idx}.")
        subjects_this_job = subjects[start_idx:end_idx]
        assert len(subjects_this_job) == subjects_count_current_job, f"Expected {subjects_count_current_job} subjects, got {len(subjects_this_job)} at job with index {jobidx}."
        subjects_file_lines = "\n".join(subjects_this_job)
        tfile = f"subjects_job{jobidx}.txt"
        write_to_textfile(tfile, subjects_file_lines)
        current_idx = end_idx

    return res


def write_to_textfile(filepath : str, contents : str) -> None:
    f = open(filepath, "w")
    f.write(contents)
    f.close()
    logger.info(f"Result written to file '{filepath}'.")



if __name__ == "__main__":
    subjects_file = "subjects.txt"  # input file. we could get these from the command line later.
    num_parallel_jobs_max = 20
    split_subjects_txt_into_chunks(subjects_file, num_parallel_jobs_max)


