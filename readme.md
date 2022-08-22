# Libfabric bug: G2G with NVIDIA GPU


## building and running the reproducer

To build with OpenMPI compiler wrappers and cuda toolkit installed:
```bash
mpicxx -I$CUDAROOT/include -L$CUDAROOT/lib64 -lcuda -lcudart main.cpp
```
The application takes 3 arguments:
* The number of bytes to send
* Where the send buffer resides (host `H` or device `D` memory)
* Where the receive buffer resides (host `H` or device `D` memory)

Sending 10000 bytes between host buffers:
```bash
srun -N2 -n2 ./a.out 10000 H H
Test sending 10000 bytes from host to host
rank 0 -- host / device buffers: 0x90a150 / 0x148422400000
rank 1 -- host / device buffers: 0x907ed0 / 0x1455ca400000
SUCCESS
```

```bash
srun -N2 -n2 ./a.out 10000 H D
Test sending 10000 bytes from host to host
rank 0 -- host / device buffers: 0x90a150 / 0x148422400000
rank 1 -- host / device buffers: 0x907ed0 / 0x1455ca400000
SUCCESS
```

## reproducing the issue

The application fails with runtime errors when the send buffer is on device memory.
The application works when the send buffer is in host memory (including sending from host and receiveing in device memory).

The exact error message depends on the size of the send buffer.

For very small buffers.
Note that the address at which the failure is reported matches the device address of the send buffer.
```
bcumming@nid003052:test > srun -N2 -n2 ./a.out 1 D H
Test sending 1 bytes from device to host
rank 1 -- host / device buffers: 0x907ed0 / 0x14602a400000
rank 0 -- host / device buffers: 0x8f8450 / 0x14fcb0400000
[nid003053:87537] *** Process received signal ***
[nid003053:87537] Signal: Segmentation fault (11)
[nid003053:87537] Signal code: Invalid permissions (2)
[nid003053:87537] Failing at address: 0x14fcb0400000
[nid003053:87537] [ 0] /lib64/libpthread.so.0(+0x168c0)[0x14fce72cb8c0]
[nid003053:87537] [ 1] /lib64/libc.so.6(+0x180d88)[0x14fce7040d88]
[nid003053:87537] [ 2] /opt/cray/libfabric/1.15.0.0/lib64/libfabric.so.1(+0x62ad1)[0x14fce5fa6ad1]
[nid003053:87537] [ 3] /opt/cray/libfabric/1.15.0.0/lib64/libfabric.so.1(+0x67b1b)[0x14fce5fabb1b]
[nid003053:87537] [ 4] /opt/cray/libfabric/1.15.0.0/lib64/libfabric.so.1(+0x67d55)[0x14fce5fabd55]
[nid003053:87537] [ 5] /scratch/e1000/bcumming/manali-cuda-s11/env/linux-sles15-zen3/gcc-11.3.0/openmpi-4.1.4-o4cr3pz3slw3btxn4rxxfdlbwmh7ayiz/lib/libmpi.so.40(+0x1b5591)[0x14fce8032591]
[nid003053:87537] [ 6] /scratch/e1000/bcumming/manali-cuda-s11/env/linux-sles15-zen3/gcc-11.3.0/openmpi-4.1.4-o4cr3pz3slw3btxn4rxxfdlbwmh7ayiz/lib/libmpi.so.40(+0x25457e)[0x14fce80d157e]
[nid003053:87537] [ 7] /scratch/e1000/bcumming/manali-cuda-s11/env/linux-sles15-zen3/gcc-11.3.0/openmpi-4.1.4-o4cr3pz3slw3btxn4rxxfdlbwmh7ayiz/lib/libmpi.so.40(MPI_Send+0x123)[0x14fce7f3dc73]
[nid003053:87537] [ 8] /scratch/e1000/bcumming/manali-cuda-s11/test/./a.out[0x40145f]
[nid003053:87537] [ 9] /lib64/libc.so.6(__libc_start_main+0xef)[0x14fce6ef52bd]
[nid003053:87537] [10] /scratch/e1000/bcumming/manali-cuda-s11/test/./a.out[0x400fda]
[nid003053:87537] *** End of error message ***
srun: error: nid003053: task 0: Segmentation fault (core dumped)
srun: launch/slurm: _step_signal: Terminating StepId=333.0
srun: error: nid003056: task 1: Terminated
srun: Force Terminated StepId=333.0
```

Between 128-256 bytes the message changes:
```
bcumming@nid003052:test > srun -N2 -n2 ./a.out 256 D H
Test sending 256 bytes from device to host
rank 1 -- host / device buffers: 0x8f81a0 / 0x14c56a400000
rank 0 -- host / device buffers: 0x8f8430 / 0x1526c2400000
[nid003053:90693] *** An error occurred in MPI_Send
[nid003053:90693] *** reported by process [22806528,0]
[nid003053:90693] *** on communicator MPI_COMM_WORLD
[nid003053:90693] *** MPI_ERR_OTHER: known error not in list
[nid003053:90693] *** MPI_ERRORS_ARE_FATAL (processes in this communicator will now abort,
[nid003053:90693] ***    and potentially your MPI job)
In: PMI_Abort(16, N/A)
srun: Job step aborted: Waiting up to 32 seconds for job step to finish.
slurmstepd: error: *** STEP 348.0 ON nid003053 CANCELLED AT 2022-08-22T09:51:30 ***
srun: error: nid003056: task 1: Killed
srun: launch/slurm: _step_signal: Terminating StepId=348.0
srun: error: nid003053: task 0: Exited with exit code 16
```
