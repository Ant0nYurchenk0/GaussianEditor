#!/usr/bin/env bash
# =============================================================================
# GaussianEditor — Download Pretrained Models & Scene Data
# =============================================================================
# Downloads the publicly available 3DGS pretrained models and 360 scene data
# from the original 3D Gaussian Splatting paper (Kerbl et al. 2023).
#
# Scenes downloaded: bicycle, kitchen  (used by the baseline experiments)
#
# Usage:
#   bash runpod/download_data.sh [--data-dir /workspace/gs_data]
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${1:-/workspace/gs_data}"

# Allow override via environment variable
DATA_DIR="${GS_DATA_DIR:-${DATA_DIR}}"

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

echo "==> Downloading to: ${DATA_DIR}"

# ---------------------------------------------------------------------------
# 1. Pretrained 3DGS point clouds (models.zip ~1.4 GB)
#    Contains point clouds for: bicycle, bonsai, counter, garden, kitchen,
#    room, flowers, treehill at various iteration checkpoints.
# ---------------------------------------------------------------------------
if [[ ! -d "${DATA_DIR}/models" ]]; then
    echo "==> [1/2] Downloading pretrained 3DGS models (~1.4 GB)..."
    wget -q --show-progress \
        https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/pretrained/models.zip
    unzip -q models.zip
    rm models.zip
    echo "   Done."
else
    echo "==> [1/2] Pretrained models already present, skipping."
fi

# ---------------------------------------------------------------------------
# 2. 360 scene COLMAP data (360_v2.zip ~5.5 GB)
#    Contains COLMAP reconstructions for the 360 scenes.
# ---------------------------------------------------------------------------
if [[ ! -d "${DATA_DIR}/360_v2" ]]; then
    echo "==> [2/2] Downloading 360 scene COLMAP data (~5.5 GB)..."
    wget -q --show-progress \
        http://storage.googleapis.com/gresearch/refraw360/360_v2.zip
    unzip -q 360_v2.zip
    rm 360_v2.zip
    echo "   Done."
else
    echo "==> [2/2] 360 scene data already present, skipping."
fi

echo ""
echo "Data ready at: ${DATA_DIR}"
echo ""
echo "Key paths for experiments:"
echo "  Bicycle COLMAP : ${DATA_DIR}/360_v2/bicycle"
echo "  Bicycle PLY    : ${DATA_DIR}/models/bicycle/point_cloud/iteration_30000/point_cloud.ply"
echo "  Kitchen COLMAP : ${DATA_DIR}/360_v2/kitchen"
echo "  Kitchen PLY    : ${DATA_DIR}/models/kitchen/point_cloud/iteration_30000/point_cloud.ply"
echo ""
echo "Next step:"
echo "  GS_DATA_DIR=${DATA_DIR} bash runpod/run_experiments.sh"
