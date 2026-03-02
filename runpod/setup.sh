#!/usr/bin/env bash
# =============================================================================
# GaussianEditor — RunPod Environment Setup
# =============================================================================
# Run this ONCE after launching a RunPod GPU pod (CUDA 11.8, Ubuntu 22.04).
# Tested with the RunPod PyTorch 2.1.0 template or a bare CUDA 11.8 image.
#
# Usage:
#   bash runpod/setup.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONDA_ENV="GaussianEditor"
MINIFORGE_PATH="/root/miniforge3"
CONDA="${MINIFORGE_PATH}/bin/conda"
MAMBA="${MINIFORGE_PATH}/bin/mamba"

echo "==> [1/6] Installing system dependencies"
apt-get update -qq
apt-get install -y --no-install-recommends \
    curl wget git git-lfs build-essential \
    libgl1 libglib2.0-0 unzip

echo "==> [2/6] Installing Miniforge (if not present)"
if [[ ! -f "${CONDA}" ]]; then
    curl -fsSL -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
    bash "Miniforge3-$(uname)-$(uname -m).sh" -b -p "${MINIFORGE_PATH}"
    rm -f "Miniforge3-$(uname)-$(uname -m).sh"
    "${CONDA}" init bash
else
    echo "   Miniforge already installed, skipping."
fi

echo "==> [3/6] Creating conda environment '${CONDA_ENV}'"
if "${CONDA}" env list | grep -q "^${CONDA_ENV} "; then
    echo "   Environment already exists, skipping."
else
    # Create env without pip deps (matching Dockerfile pattern)
    cd "${REPO_ROOT}"
    patch -N environment.yaml environment-disable-pip.patch || true
    "${MAMBA}" env create -f environment.yaml
    "${MAMBA}" clean -afy
fi

echo "==> [4/6] Installing pip dependencies (this compiles tiny-cuda-nn — may take 10-20 min)"
export TCNN_CUDA_ARCHITECTURES="${TCNN_CUDA_ARCHITECTURES:-86}"   # 86=A100/A40/A6000, 80=A100 SXM
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.6}"

# Link libcuda stub so tiny-cuda-nn can compile at install time
STUB="${MINIFORGE_PATH}/envs/${CONDA_ENV}/lib/stubs/libcuda.so"
DEST="${MINIFORGE_PATH}/envs/${CONDA_ENV}/lib/libcuda.so"
[[ -L "${DEST}" ]] || ln -s "${STUB}" "${DEST}"

cd "${REPO_ROOT}"
"${CONDA}" run --live-stream -n "${CONDA_ENV}" \
    pip install -r requirements.lock.txt

echo "==> [5/6] Installing forked Viser and building web client"
if [[ ! -d "${REPO_ROOT}/extern/viser" ]]; then
    mkdir -p "${REPO_ROOT}/extern"
    git clone https://github.com/heheyas/viser "${REPO_ROOT}/extern/viser"
fi
"${MAMBA}" run -n "${CONDA_ENV}" --live-stream \
    pip install -e "${REPO_ROOT}/extern/viser"
# Pre-build the Viser web client
"${CONDA}" run --live-stream -n "${CONDA_ENV}" \
    python -c "import viser; viser.ViserServer()" || true

echo "==> [6/6] Verifying installation"
"${CONDA}" run --live-stream -n "${CONDA_ENV}" \
    python -c "import torch; print('torch:', torch.__version__, '| CUDA:', torch.cuda.is_available())"

echo ""
echo "Setup complete. Next step:"
echo "  bash runpod/download_data.sh"
