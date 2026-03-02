# GaussianEditor — RunPod Quickstart

Run two baseline experiments (edit + delete) on the publicly available 360 scenes, then inspect results interactively via the Viser WebUI.

---

## Recommended RunPod template

| Setting | Value |
|---------|-------|
| Template | **RunPod PyTorch 2.1** or bare **CUDA 11.8 / Ubuntu 22.04** |
| GPU | A40 / A6000 / A100 (≥ 24 GB VRAM) |
| Volume | `/workspace` — at least **30 GB** for data + outputs |
| Exposed ports | **8080** (Viser WebUI) |

> If your GPU has a different compute capability, set `TCNN_CUDA_ARCHITECTURES` before running `setup.sh`.
> Common values: `86` = A40/A6000/RTX 3090, `80` = A100, `89` = RTX 4090.

---

## Step-by-step

```bash
# 1. Clone the repo (if not already on the pod)
git clone <repo-url> /workspace/GaussianEditor
cd /workspace/GaussianEditor

# 2. One-time environment setup (~20 min, mostly compiling tiny-cuda-nn)
TCNN_CUDA_ARCHITECTURES=86 bash runpod/setup.sh

# 3. Download pretrained 3DGS models + 360 COLMAP data (~7 GB total)
GS_DATA_DIR=/workspace/gs_data bash runpod/download_data.sh

# 4. Run both baseline experiments (≈5-10 min each)
GS_DATA_DIR=/workspace/gs_data bash runpod/run_experiments.sh

# 5. Inspect results in the browser
GS_DATA_DIR=/workspace/gs_data bash runpod/visualize.sh --exp bicycle_snow_edit
# or:
GS_DATA_DIR=/workspace/gs_data bash runpod/visualize.sh --exp kitchen_tracker_delete
```

---

## Experiments

### Exp 1 — Edit: Bicycle → Snowy Bicycle
- **Config**: `configs/edit-n2n.yaml`
- **Guidance**: InstructPix2Pix (Stable Diffusion v1.5)
- **Prompt**: "a bicycle parked next to a bench in a park, all covered with snow, winter"
- **Steps**: 2 000  (~5 min on A40)
- **Output**: `outputs/bicycle_snow_edit/`

### Exp 2 — Delete: Kitchen Tracker Removal
- **Config**: `configs/del-ctn.yaml`
- **Guidance**: ControlNet inpainting
- **Target**: `tractor` (the tracking device visible in the kitchen scene)
- **Steps**: 2 000  (~5 min on A40)
- **Output**: `outputs/kitchen_tracker_delete/`

---

## Running a single experiment

```bash
# Edit only
EXPERIMENTS=edit  GS_DATA_DIR=/workspace/gs_data bash runpod/run_experiments.sh

# Delete only
EXPERIMENTS=delete GS_DATA_DIR=/workspace/gs_data bash runpod/run_experiments.sh
```

## Visualizing any PLY directly

```bash
bash runpod/visualize.sh \
  --ply /workspace/gs_data/models/bicycle/point_cloud/iteration_30000/point_cloud.ply \
  --colmap /workspace/gs_data/360_v2/bicycle
```

---

## Enabling Weights & Biases logging

Add `system.loggers.wandb.enable=true system.loggers.wandb.name="my_run"` to the
`launch.py` call inside `run_experiments.sh`, or set `WANDB_API_KEY` in the environment
and the existing flag will forward your credentials automatically.

---

## File layout

```
runpod/
├── setup.sh            # One-time conda env + pip install
├── download_data.sh    # Fetch pretrained models + COLMAP data
├── run_experiments.sh  # Run Exp 1 (edit) and Exp 2 (delete)
├── visualize.sh        # Launch Viser WebUI for a trained model
└── README.md           # This file
```
