# Slurm Job Array to run FreeSurfer on HPC clusters using local parallelization on the nodes via GNU Parallel

These scripts split a subjects file into several chunks and provide a suitable [Slurm](https://slurm.schedmd.com) job script to run FreeSurfer for many subjects on high performance computing (HPC) systems. The submit script makes use of Slurm job arrays.

You can use the provided job submission script (submit.sh) as a rough template, but you will of course have to adapt it to the setup of cluster and its file systems, rules and resource limits.

The files in this directory can also solve the special case where you want to run local parallelization of several FreeSurfer jobs on the cores of a single worker of a HPC system. This approach can dramatically speed up your computations if the cluster assigns full nodes to a single job.