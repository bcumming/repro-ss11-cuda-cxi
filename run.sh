#! /bin/bash
export LOCAL_RANK=$SLURM_LOCALID
export GLOBAL_RANK=$SLURM_PROCID

export GPUS=(3 2 1 0)

# bind devices to mpi rank
export NUMA_NODE=$LOCAL_RANK
export CUDA_VISIBLE_DEVICES=${GPUS[$NUMA_NODE]}

export FI_PROVIDER=cxi
export OMPI_MCA_btl_ofi_disable_sep=true
export OMPI_MCA_btl_ofi_mode=2

numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE ./a.out 128 H H
echo
numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE ./a.out 128 H D
echo
numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE ./a.out 128 D D
