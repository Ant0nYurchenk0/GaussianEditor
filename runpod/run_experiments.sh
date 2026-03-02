#!/usr/bin/env bash
# =============================================================================
# GaussianEditor — Baseline Experiments
# =============================================================================
# Runs two baseline experiments on publicly available 360 scenes:
#
#   Exp 1 (EDIT)   — bicycle scene: "all covered with snow, winter"
#                    Method: InstructPix2Pix guidance (edit-n2n)
#
#   Exp 2 (DELETE) — kitchen scene: remove the countertop tracker object
#                    Method: ControlNet inpainting (del-ctn)
#
# After each experiment the script renders a turntable video for inspection.
#
# Prerequisites:
#   bash runpod/setup.sh
#   bash runpod/download_data.sh
#
# Usage:
#   GS_DATA_DIR=/workspace/gs_data bash runpod/run_experiments.sh
#   # or, to run a single experiment:
#   EXPERIMENTS=edit  bash runpod/run_experiments.sh
#   EXPERIMENTS=delete bash runpod/run_experiments.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONDA="${MINIFORGE_PATH:-/root/miniforge3}/bin/conda"
CONDA_ENV="GaussianEditor"
DATA_DIR="${GS_DATA_DIR:-/workspace/gs_data}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/outputs}"
GPU="${GPU:-0}"
EXPERIMENTS="${EXPERIMENTS:-all}"   # "all" | "edit" | "delete"

RUN() {
    "${CONDA}" run --live-stream -n "${CONDA_ENV}" "$@"
}

# ---------------------------------------------------------------------------
# Helper: render a short turntable video after training completes.
# The WebUI / launch.py --test mode saves renders to outputs/<exp>/test/
# ---------------------------------------------------------------------------
render_test() {
    local exp_name="$1"
    local config="$2"
    shift 2
    echo "  --> Rendering test views for: ${exp_name}"
    RUN python "${REPO_ROOT}/launch.py" \
        --config "${REPO_ROOT}/configs/${config}" \
        --test \
        --gpu "${GPU}" \
        exp_root_dir="${OUT_DIR}" \
        tag="${exp_name}" \
        "$@" 2>&1 | tee "${OUT_DIR}/${exp_name}_test.log"
}

# ===========================================================================
# Experiment 1: EDIT — Bicycle → snowy bicycle
# ===========================================================================
run_edit_bicycle() {
    local EXP="bicycle_snow_edit"
    local COLMAP="${DATA_DIR}/360_v2/bicycle"
    local PLY="${DATA_DIR}/models/bicycle/point_cloud/iteration_30000/point_cloud.ply"

    echo ""
    echo "=========================================================="
    echo " Experiment 1: EDIT — bicycle → snowy bicycle"
    echo "=========================================================="

    if [[ ! -f "${PLY}" ]]; then
        echo "ERROR: PLY not found at ${PLY}. Run download_data.sh first."
        exit 1
    fi

    RUN python "${REPO_ROOT}/launch.py" \
        --config "${REPO_ROOT}/configs/edit-n2n.yaml" \
        --train \
        --gpu "${GPU}" \
        exp_root_dir="${OUT_DIR}" \
        tag="${EXP}" \
        trainer.max_steps=2000 \
        data.source="${COLMAP}" \
        system.gs_source="${PLY}" \
        system.prompt_processor.prompt="a bicycle parked next to a bench in a park, all covered with snow, winter" \
        system.seg_prompt="bicycle" \
        system.max_densify_percent=0.03 \
        system.anchor_weight_init_g0=0.0 \
        system.anchor_weight_init=0.02 \
        system.anchor_weight_multiplier=1.3 \
        system.loss.lambda_anchor_color=5 \
        system.loss.lambda_anchor_geo=50 \
        system.loss.lambda_anchor_scale=50 \
        system.loss.lambda_anchor_opacity=50 \
        system.densify_from_iter=100 \
        system.densify_until_iter=5000 \
        system.densification_interval=300 \
        system.loggers.wandb.enable=false \
        2>&1 | tee "${OUT_DIR}/${EXP}_train.log"

    echo "  Training done. Output: ${OUT_DIR}/${EXP}/"
}

# ===========================================================================
# Experiment 2: DELETE — kitchen tracker removal
# ===========================================================================
run_delete_kitchen() {
    local EXP="kitchen_tracker_delete"
    local COLMAP="${DATA_DIR}/360_v2/kitchen"
    local PLY="${DATA_DIR}/models/kitchen/point_cloud/iteration_30000/point_cloud.ply"

    echo ""
    echo "=========================================================="
    echo " Experiment 2: DELETE — kitchen tracker removal"
    echo "=========================================================="

    if [[ ! -f "${PLY}" ]]; then
        echo "ERROR: PLY not found at ${PLY}. Run download_data.sh first."
        exit 1
    fi

    RUN python "${REPO_ROOT}/launch.py" \
        --config "${REPO_ROOT}/configs/del-ctn.yaml" \
        --train \
        --gpu "${GPU}" \
        exp_root_dir="${OUT_DIR}" \
        tag="${EXP}" \
        trainer.max_steps=2000 \
        data.source="${COLMAP}" \
        system.gs_source="${PLY}" \
        system.seg_prompt="tractor" \
        system.inpaint_prompt="table, carpet" \
        system.fix_holes=true \
        system.inpaint_scale=1 \
        system.mask_dilate=15 \
        system.max_densify_percent=0.01 \
        system.anchor_weight_init_g0=0.0 \
        system.anchor_weight_init=0.0 \
        system.anchor_weight_multiplier=1.5 \
        system.loss.lambda_anchor_color=5 \
        system.loss.lambda_anchor_geo=50 \
        system.loss.lambda_anchor_scale=50 \
        system.loss.lambda_anchor_opacity=50 \
        system.densify_from_iter=0 \
        system.densify_until_iter=5000 \
        system.densification_interval=50 \
        system.loggers.wandb.enable=false \
        system.cache_overwrite=false \
        2>&1 | tee "${OUT_DIR}/${EXP}_train.log"

    echo "  Training done. Output: ${OUT_DIR}/${EXP}/"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
cd "${REPO_ROOT}"
mkdir -p "${OUT_DIR}"

case "${EXPERIMENTS}" in
    all)
        run_edit_bicycle
        run_delete_kitchen
        ;;
    edit)
        run_edit_bicycle
        ;;
    delete)
        run_delete_kitchen
        ;;
    *)
        echo "Unknown EXPERIMENTS value '${EXPERIMENTS}'. Use: all | edit | delete"
        exit 1
        ;;
esac

echo ""
echo "=========================================================="
echo " All experiments complete."
echo " Results: ${OUT_DIR}/"
echo ""
echo " To visualize interactively, run:"
echo "   bash runpod/visualize.sh --exp bicycle_snow_edit"
echo "   bash runpod/visualize.sh --exp kitchen_tracker_delete"
echo "=========================================================="
