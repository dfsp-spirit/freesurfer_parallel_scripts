# freesurfer_parallel
Shell scripts to run FreeSurfer's recon-all in parallel on multi-core machines.


## About

FreeSurfer is a state-of-the-art neuroimaging software suite, and its recon-all pipeline supports the fully automated reconstruction of mesh representations of the human cortex from raw MRI scans in DICOM or NIFTI formats. However, running recon-all takes very long (12 - 20 h per subject on current hardware) and typically needs to be run for hundreds of subjects for a neuroimaging study. This repo contains bash shell scripts which allow one to run the time-consuming FreeSurfer pre-processing in parallel on multi-core systems. The parallelization is done on the subject level, meaning that a single subject still takes a long time, but each core of your computer runs one subject.

## Hardware requirements

You will need a multi-core computer (almost all modern machines are multi-core, even laptops) that can run FreeSurfer and about 1.5 - 2 GB of free RAM per CPU core you want to use. An example would be a quad-core computer with 12 GB of RAM (4x2 GB for FreeSurfer, leaving another 4 for the operating system and all other processes). We run this on an AMD Threadripper Linux workstation with 48 cores, 128 GB of RAM and a fast SSD. I typically do not use all of the cores but leave 2 or 3 idle so that I can still use the computer for basic tasks while the pre-processing is running in the background.

## Software requirements

* Any Linux or MacOS operating system that can run FreeSurfer
* A working FreeSurfer 6 or 7 installation (including proper setup for the bash shell)
* GNU parallel, which is used for parallelzation in all of the scripts


### Some notes on MacOS

If using MacOS, you need to make sure that you have a version that can actually run FreeSurfer. Apple has limited more and more what programs can be run under MacOS and the latest versions are not supported by FreeSurfer yet. Some things to keep in mind are:

* Support for 32 bit binaries (x86 compatibility mode on the am64 architecture) was dropped in MacOS Catalina, and some older FreeSurfer tools are 32 bit (e.g., tkmedit). They do not work under MacOS versions >= Cataline. None of the recon-all tools are 32 bit-only though, afaik.
* The system integrity protection (SIP) may need to be turned off in order for some FreeSurfer programs to run properly.
* The default shell on newer MacOS versions is no longer bash. This is fine, but you must make sure that FreeSurfer is configured properly for bash, no matter what your default shell is. Note: You do NOT need to change your default shell to bash to use these scripts.
* Afaik, only the amd64 architecture is supported by FreeSurfer, so ARM hardware ("Apple Silicon" Macs) will not work.
* Recent MacOS versions (starting from Big Sur) do not allow any software to be run for which the developers of the software did not sign up with Apple, accepted various terms and conditions, and signed the software distribution with a certificate they obtained from Apple. This means that various software cannot be run on such systems. The system has lots of holes though, and it seems that while one cannot run arbitrary binaries, one can run arbitrary programs as long as they are scripts (which are run on an interpreter that has been registered). This means that it may still be possible to run parts of the FreeSurfer tools, but we did not try it and we recommend not to use recent MacOS versions for scientific computing.

That being said, we use these scripts under older MacOS versions on amd64 hardware and they work perfectly. We have a dedicated iMac with 24 cores running MacOS High Sierra for this task, on which we do not update the OS.

