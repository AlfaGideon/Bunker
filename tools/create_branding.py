"""Compatibility entry point: never regenerate the rejected placeholder logo."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("prepare_selected_branding.py")), run_name="__main__")
