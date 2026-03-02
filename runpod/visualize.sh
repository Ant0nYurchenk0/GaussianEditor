#!/usr/bin/env bash
# =============================================================================
# GaussianEditor — Interactive Visualization (Viser WebUI)
# =============================================================================
# Launches the Viser-based WebUI for a trained Gaussian model so you can
# inspect the result interactively from your browser.
#
# On RunPod:
#   1. In the pod settings, expose port 8080 (or whatever VISER_PORT is set to)
#      via RunPod's "Connect" → "HTTP Service" → add port 8080.
#   2. Run this script on the pod.
#   3. Open the URL shown in RunPod's "Connect" panel.
#
# Usage:
#   bash runpod/visualize.sh --exp bicycle_snow_edit
#   bash runpod/visualize.sh --exp kitchen_tracker_delete
#   bash runpod/visualize.sh --ply /path/to/custom.ply --colmap /path/to/colmap
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONDA="${MINIFORGE_PATH:-/root/miniforge3}/bin/conda"
CONDA_ENV="GaussianEditor"
DATA_DIR="${GS_DATA_DIR:-/workspace/gs_data}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/outputs}"
VISER_PORT="${VISER_PORT:-8080}"

# Parse arguments
EXP_NAME=""
CUSTOM_PLY=""
CUSTOM_COLMAP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --exp)      EXP_NAME="$2";    shift 2 ;;
        --ply)      CUSTOM_PLY="$2";  shift 2 ;;
        --colmap)   CUSTOM_COLMAP="$2"; shift 2 ;;
        *)          echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve PLY and COLMAP paths from experiment name or explicit args
# ---------------------------------------------------------------------------
resolve_paths() {
    if [[ -n "${CUSTOM_PLY}" ]]; then
        PLY="${CUSTOM_PLY}"
        COLMAP="${CUSTOM_COLMAP}"
        return
    fi

    case "${EXP_NAME}" in
        bicycle_snow_edit)
            # Find the last saved checkpoint in the experiment output
            PLY="$(find "${OUT_DIR}/${EXP_NAME}" -name "point_cloud.ply" | sort | tail -1)"
            COLMAP="${DATA_DIR}/360_v2/bicycle"
            ;;
        kitchen_tracker_delete)
            PLY="$(find "${OUT_DIR}/${EXP_NAME}" -name "point_cloud.ply" | sort | tail -1)"
            COLMAP="${DATA_DIR}/360_v2/kitchen"
            ;;
        "")
            echo "ERROR: Provide --exp <name> or --ply <path> --colmap <path>"
            exit 1
            ;;
        *)
            # Generic: search outputs directory
            PLY="$(find "${OUT_DIR}/${EXP_NAME}" -name "point_cloud.ply" | sort | tail -1 2>/dev/null || true)"
            COLMAP=""
            if [[ -z "${PLY}" ]]; then
                echo "ERROR: Could not find point_cloud.ply under ${OUT_DIR}/${EXP_NAME}"
                exit 1
            fi
            ;;
    esac
}

resolve_paths

echo ""
echo "=========================================================="
echo " Launching Viser WebUI"
echo "  PLY   : ${PLY}"
echo "  COLMAP: ${COLMAP:-<none>}"
echo "  Port  : ${VISER_PORT}"
echo ""
echo " Open in browser:"
echo "   http://localhost:${VISER_PORT}  (local SSH tunnel)"
echo "   or use the RunPod 'HTTP Service' URL for port ${VISER_PORT}"
echo "=========================================================="
echo ""

ARGS=("--gs_source" "${PLY}" "--port" "${VISER_PORT}")
[[ -n "${COLMAP}" ]] && ARGS+=("--colmap_dir" "${COLMAP}")

cd "${REPO_ROOT}"
"${CONDA}" run --live-stream -n "${CONDA_ENV}" \
    python webui.py "${ARGS[@]}"
