import os
import sys
import zipfile
import urllib.request
import subprocess

PROJECT_ROOT = r"C:\Soobshio_project"
TOOLS_DIR = os.path.join(PROJECT_ROOT, "tools")
STATIC_DIR = os.path.join(PROJECT_ROOT, "static")

os.makedirs(TOOLS_DIR, exist_ok=True)
os.makedirs(STATIC_DIR, exist_ok=True)

PMTILES_ZIP_URL = "https://github.com/protomaps/go-pmtiles/releases/download/v1.20.0/go-pmtiles_1.20.0_windows_x86_64.zip"
ZIP_PATH = os.path.join(TOOLS_DIR, "go-pmtiles.zip")
EXE_PATH = os.path.join(TOOLS_DIR, "pmtiles.exe")
OUTPUT_PMTILES = os.path.join(STATIC_DIR, "nizhnevartovsk.pmtiles")

# Bounding box for Nizhnevartovsk region: min_lon, min_lat, max_lon, max_lat
BBOX = "76.45,60.90,76.65,60.98"

def download_pmtiles():
    if not os.path.exists(EXE_PATH):
        print(f"Downloading go-pmtiles CLI from: {PMTILES_ZIP_URL}")
        try:
            urllib.request.urlretrieve(PMTILES_ZIP_URL, ZIP_PATH)
            print("Download complete. Extracting zip archive...")
            
            with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
                # Find the pmtiles.exe inside zip
                for file_info in zip_ref.infolist():
                    if file_info.filename.endswith("pmtiles.exe"):
                        file_info.filename = "pmtiles.exe" # extract directly as pmtiles.exe
                        zip_ref.extract(file_info, TOOLS_DIR)
                        print(f"Extracted pmtiles.exe successfully to {EXE_PATH}")
                        break
            
            if os.path.exists(ZIP_PATH):
                os.remove(ZIP_PATH)
        except Exception as e:
            print(f"Error downloading/extracting pmtiles: {e}")
            sys.exit(1)
    else:
        print("pmtiles.exe already exists in tools directory.")

def extract_map():
    print(f"Extracting Nizhnevartovsk PMTiles to: {OUTPUT_PMTILES}")
    try:
        # Run pmtiles extract
        cmd = [
            EXE_PATH,
            "extract",
            "https://build.protomaps.com/latest.pmtiles",
            OUTPUT_PMTILES,
            f"--bbox={BBOX}",
            "--force"
        ]
        print(f"Running command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("Extraction complete successfully.")
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Extraction failed: {e}")
        print("Stderr:", e.stderr)
        print("Stdout:", e.stdout)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    download_pmtiles()
    extract_map()
