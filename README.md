# freesurfer_parallel
Shell scripts to run FreeSurfer's recon-all in parallel on multi-core machines.


## About

FreeSurfer is a state-of-the-art neuroimaging software suite, and its recon-all pipeline supports the fully automated reconstruction of mesh representations of the human cortex from raw MRI scans in DICOM or NIFTI formats. However, running recon-all takes very long (12 - 20 h per subject on current hardware) and typically needs to be run for hundreds of subjects for a neuroimaging study. This repo contains bash shell scripts which allow one to run the time-consuming FreeSurfer pre-processing in parallel on multi-core systems. The parallelization is done on the subject level, meaning that a single subject still takes a long time, but each core of your computer runs one subject.

## Hardware requirements

You will need a multi-core computer (almost all modern machines are multi-core, even laptops) that can run FreeSurfer and about 1.5 - 2 GB of free RAM per CPU core you want to use. An example would be a quad-core computer with 12 GB of RAM (4x2 GB for FreeSurfer, leaving another 4 for the operating system and all other processes). We run this on an AMD Threadripper Linux workstation with 48 cores, 128 GB of RAM and a fast SSD. I typically do not use all of the cores but leave 2 or 3 idle so that I can still use the computer for basic tasks while the pre-processing is running in the background.

## Software requirements

* any Linux or MacOS operating system that can run FreeSurfer
* a working FreeSurfer 6 or 7 installation (including proper setup for the bash shell)
* GNU parallel, which is used for parallelzation in all of the scripts

