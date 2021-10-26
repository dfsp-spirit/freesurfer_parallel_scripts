# freesurfer_parallel
Shell scripts to run FreeSurfer's recon-all in parallel on multi-core machines.


## About

FreeSurfer is a state-of-the-art neuroimaging software suite, and its recon-all pipeline supports the fully automated reconstruction of mesh representations of the human cortex from raw MRI scans in DICOM or NIFTI formats. However, running recon-all takes very long (12 - 20 h per subject on current hardware) and typically needs to be run for hundreds of subjects for a neuroimaging study. This repo contains bash shell scripts which allow one to run the time-consuming FreeSurfer pre-processing in parallel on multi-core systems. The parallelization is done on the subject level, meaning that a single subject still takes a long time, but each core of your computer runs one subject.

## Hardware requirements

You will need a multi-core computer (almost all modern machines are multi-core, even laptops) that can run FreeSurfer and about 1.5 - 2 GB of free RAM per CPU core you want to use.

An example would be a quad-core computer with 12 GB of RAM (4x2 GB for FreeSurfer, leaving another 4 for the operating system and all other processes). We run this on an AMD Threadripper Linux workstation with 48 cores, 128 GB of RAM and a fast SSD. I typically do not use all of the cores but leave 2 or 3 idle so that I can still use the computer for basic tasks while the pre-processing is running in the background.

## Software requirements

* Any Linux or MacOS operating system that can run FreeSurfer
* A working FreeSurfer 6 or 7 installation (including proper setup for the bash shell)
* GNU parallel, which is used for parallelzation in all of the scripts

## The scripts


### Running the FreeSurfer cross-sectional pipeline (1 time point per participant)

This involves running the `recon-all` pipeline, which takes 12 - 20h per subject. Typically `qcache` is also run as part of the pipeline, to map the resulting data (like per-vertex cortical thickness in native space) to standard space (fsaverage).

We recommend the following steps:

* First convert the raw DICOM files to NIFTI format using [dcm2nii](https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage).
* Use the script cross-sectional/recon-all-parallel.bash from this repository to run recon-all for all NIFTI files in parallel.
* If you want to add a global brain measure (like total brain volume) as a covariate during modeling during the statistical analysis later, run the script extractTotalBrainMeasures.bash to compute the measures for all subjects.

Note: If you will get data for a second wave later and intend to run a longitudinal analysis then, please read about the longitudinal pipeline now to avoid duplicate work later.


### Running the FreeSurfer longitudinal pipeline (several time points / scans per participant)

This requires first running the cross-sectional `recon-all` pipeline for all time points you have. If a subject is named `subject1` and you have MRI scans from two time points, the NIFTI input files should be called `subject1_MR1.nii` and `subject1_MR2.nii` before you run the cross-sectional pipeline, so that you get two output directories named `subject1_MR1` and `subject1_MR2`.

Then, you can run the longitudinal pipeline using the script [./longitudinal/fs_longitudinal_pipeline.bash](./longitudinal/fs_longitudinal_pipeline.bash) from this repo. The script performs 3 tasks which can be run independently, and we recommend to run one after the other and check whether everything finished successfully before moving on to the next step. The 3 steps are:

* Creating an inter-subject template brain from all scans / time points for each subject. Creates a directory named `subject1`.
* Mapping the data from the time points (directories `subject1_MR1` and `subject1_MR2`) to the template, creating directories `subject1_MR1.long.subject1` and `subject1_MR2.long.subject1`.
* Computing the change between the timepoints for one or several descriptors (cortical thickness, surface area, ...).


