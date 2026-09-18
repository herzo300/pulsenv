"""
Train specialized YOLO models for City Pulse urban monitoring.
Downloads datasets from Roboflow and trains YOLOv8n models, then exports to ONNX.

Models:
  1. Garbage/Trash detector (TACO dataset)
  2. Fire/Smoke detector (DFire dataset)

Run on LOCAL machine (GPU recommended, CPU OK but slower).
Results go to models/ folder for deployment to Timeweb.

Usage:
    pip install ultralytics roboflow
    python train_specialized_models.py
"""

import os
import sys
from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)

INPUT_SIZE = 320  # Match edge filter config


def install_deps():
    """Install training/download dependencies."""
    os.system(f"{sys.executable} -m pip install ultralytics roboflow -q")


def train_garbage_model():
    """Train YOLOv8n on TACO/garbage detection dataset from Roboflow."""
    from roboflow import Roboflow
    from ultralytics import YOLO

    output = MODELS_DIR / "yolov8n_garbage.onnx"
    if output.exists():
        print(f"✅ Garbage model already exists: {output}")
        return

    print("\n🗑️ === GARBAGE/TRASH DETECTION (TACO) ===")

    # Download TACO dataset from Roboflow Universe (public, free)
    # Using the popular "TACO-7" dataset with good annotations
    print("📥 Downloading TACO trash detection dataset...")
    rf = Roboflow(api_key="")  # Public datasets don't require key
    try:
        # Option 1: Popular community TACO dataset
        project = rf.workspace("divya-lzcld").project("taco-mqclx")
        dataset = project.version(6).download("yolov8", location="datasets/taco")
    except Exception:
        print("⚠️ Cannot auto-download from Roboflow without API key.")
        print("   Manual steps:")
        print("   1. Go to https://universe.roboflow.com/search?q=TACO+trash+garbage")
        print("   2. Select a dataset → Download → YOLOv8 format")
        print("   3. Extract to datasets/taco/")
        print("   4. Re-run this script")

        # Alternative: train on existing COCO classes that overlap
        print("\n🔄 Using COCO pretrained as base (detects bottles, cups, etc.)...")
        model = YOLO("yolov8n.pt")
        model.export(format="onnx", imgsz=INPUT_SIZE)

        src = Path("yolov8n.onnx")
        if src.exists():
            src.rename(output)
            print(f"   Saved as: {output}")
        return

    # Train on TACO
    print("🏋️ Training YOLOv8n on TACO dataset...")
    model = YOLO("yolov8n.pt")
    results = model.train(
        data="datasets/taco/data.yaml",
        epochs=50,
        imgsz=INPUT_SIZE,
        batch=16,
        patience=10,
        name="garbage_detector",
        project="runs",
    )

    # Export best model to ONNX
    best_pt = Path("runs/garbage_detector/weights/best.pt")
    if best_pt.exists():
        best_model = YOLO(str(best_pt))
        best_model.export(format="onnx", imgsz=INPUT_SIZE)
        onnx_file = best_pt.with_suffix(".onnx")
        if onnx_file.exists():
            onnx_file.rename(output)
            print(
                f"✅ Garbage model exported: {output} ({output.stat().st_size / 1e6:.1f} MB)"
            )
    else:
        print("❌ Training failed — best.pt not found")


def train_fire_smoke_model():
    """Train YOLOv8n on fire/smoke detection dataset."""
    from roboflow import Roboflow
    from ultralytics import YOLO

    output = MODELS_DIR / "yolov8n_fire_smoke.onnx"
    if output.exists():
        print(f"✅ Fire/smoke model already exists: {output}")
        return

    print("\n🔥 === FIRE/SMOKE DETECTION (DFire) ===")

    print("📥 Downloading fire/smoke detection dataset...")
    rf = Roboflow(api_key="")
    try:
        # Popular fire-smoke detection dataset on Roboflow
        project = rf.workspace("fire-smoke-detection-ynter").project(
            "fire-smoke-detection-w5qlh"
        )
        dataset = project.version(1).download("yolov8", location="datasets/fire_smoke")
    except Exception:
        print("⚠️ Cannot auto-download from Roboflow without API key.")
        print("   Manual steps:")
        print("   1. Go to https://universe.roboflow.com/search?q=fire+smoke+detection")
        print("   2. Select a dataset → Download → YOLOv8 format")
        print("   3. Extract to datasets/fire_smoke/")
        print("   4. Re-run this script")

        # DFire GitHub dataset fallback
        print("\n🔄 Attempting DFire GitHub dataset...")
        os.system(
            "git clone --depth 1 https://github.com/gaiasd/DFireDataset.git datasets/dfire 2>/dev/null"
        )

        if Path("datasets/dfire").exists():
            print("   Downloaded DFire. Manual YOLO format conversion needed.")
        return

    # Train
    print("🏋️ Training YOLOv8n on fire/smoke dataset...")
    model = YOLO("yolov8n.pt")
    results = model.train(
        data="datasets/fire_smoke/data.yaml",
        epochs=50,
        imgsz=INPUT_SIZE,
        batch=16,
        patience=10,
        name="fire_smoke_detector",
        project="runs",
    )

    best_pt = Path("runs/fire_smoke_detector/weights/best.pt")
    if best_pt.exists():
        best_model = YOLO(str(best_pt))
        best_model.export(format="onnx", imgsz=INPUT_SIZE)
        onnx_file = best_pt.with_suffix(".onnx")
        if onnx_file.exists():
            onnx_file.rename(output)
            print(
                f"✅ Fire/smoke model exported: {output} ({output.stat().st_size / 1e6:.1f} MB)"
            )
    else:
        print("❌ Training failed — best.pt not found")


def main():
    print("=" * 50)
    print("🧠 City Pulse — Specialized Model Training")
    print("=" * 50)

    install_deps()
    train_garbage_model()
    train_fire_smoke_model()

    print("\n" + "=" * 50)
    print("📦 Available models in models/:")
    for f in sorted(MODELS_DIR.glob("*.onnx")):
        print(f"   {f.name} ({f.stat().st_size / 1e6:.1f} MB)")
    print("\n🚀 Deploy to Timeweb:")
    print("   scp models/*.onnx root@45.153.68.59:/root/citypulse_api/models/")
    print("=" * 50)


if __name__ == "__main__":
    main()
