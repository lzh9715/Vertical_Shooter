#!/usr/bin/env python3
"""Run Godot regressions in a temporary project copy with a bounded runtime."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if engine is None:
        parser.error("Godot 4.7 not found; use --godot /path/to/Godot or GODOT_BIN")

    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="vertical-shooter-tests-") as temporary:
        project = Path(temporary) / "project"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns(
            ".git", ".godot", ".agents", ".vscode", ".DS_Store", "__pycache__"
        ))
        # 测试不读取或覆盖正式游戏的用户设置。
        override = project / "override.cfg"
        with override.open("a", encoding="utf-8") as handle:
            handle.write('\n[application]\nconfig/use_custom_user_dir=true\n'
                         'config/custom_user_dir_name="VerticalShooterRegressionTests"\n')

        suites = [["--script", f"res://tests/{name}_regressions.gd"]
                  for name in ["p1", "p2"]]
        for extra in [["--import"], *suites]:
            command = [engine, "--headless", "--path", str(project),
                       "--log-file", str(Path(temporary) / "godot.log"), *extra]
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=45)
            except subprocess.TimeoutExpired as error:
                print(f"Godot timed out: {error}", file=sys.stderr)
                return 1
            output = result.stdout + result.stderr
            if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
                print(output, end="")
                return 1
            if "--script" in extra:
                print(output, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
