#!/usr/bin/env python

from typing import List, Union
import math
import numpy as np



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
        print(f"At job {jobidx+1} (index {jobidx}) of {num_jobs_total}: using subject indices {start_idx} to {end_idx}.")
        subjects_this_job = subjects[start_idx:end_idx]
        assert len(subjects_this_job) == subjects_count_current_job, f"Expected {subjects_count_current_job} subjects, got {len(subjects_this_job)} at job with index {jobidx}."
        subjects_string_this_job = subject_separator.join(subjects_this_job.tolist())
        res += f"{jobidx} {subjects_count_current_job} {subjects_string_this_job}\n"
        current_idx = end_idx

    return res


def write_to_textfile(filepath : str, contents : str) -> None:
    f = open(filepath, "w")
    f.write(res)
    f.close()
    print(f"Result written to file '{filepath}'.")



if __name__ == "__main__":
    subjects_file = "subjects.txt"  # input file. we could get these from the command line later.
    num_parallel_jobs_max = 20
    subject_separator : str = ","
    output_file = "jobarray_config.txt"
    res = subjects_txt_to_jobarray_config(subjects_file, num_parallel_jobs_max, subject_separator)
    write_to_textfile(output_file, res)


