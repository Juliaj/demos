# Pixi Environment Verification Guide

This guide helps you verify that your Pixi environment is set up properly.

## 1. Check Pixi Installation

```bash
pixi --version
```

Expected: Pixi version number (e.g., `pixi 0.x.x`)

## 2. Check Environment Information

```bash
# List all environments
pixi info

# Show installed packages
pixi list

# Remove pixi environment
pixi clean
```

## 2.5. Clean Up Pixi Environment (for Testing)

To properly test a fresh setup, you may need to clean up the existing pixi environment:

```bash
# Navigate to the demos folder (where pixi.toml is located)
cd ~/ws_pai/src/demos

# Option 1: Clean pixi environment (removes .pixi directory)
pixi clean

# Option 2: Clean build artifacts only (keeps pixi environment)
pixi run clean

# Option 3: Complete cleanup (both pixi environment and build artifacts)
pixi clean && pixi run clean

# Option 4: Nuclear option - remove everything and start fresh
# This removes pixi environment, build artifacts, and lock file
pixi clean
rm -rf build install log
rm -f pixi.lock
```

After cleaning, you can start fresh:

```bash
# Reinstall base environment
pixi install

# Re-run setup steps from DEVELOPMENT.md
pixi run detect-gpu
pixi run install-rtx5090-pytorch  # or install-standard-pytorch
pixi run install-lerobot

```

## 3. Verify Python and Core Packages

```bash
# Enter Pixi shell
pixi shell

# Check Python version
python --version

# Verify Python packages are accessible
python -c "import numpy; print('NumPy:', numpy.__version__)"
python -c "import cv2; print('OpenCV:', cv2.__version__)"
python -c "import huggingface_hub; print('HuggingFace Hub installed')"

# Exit shell
exit
```

Expected: Python 3.12.x and all packages should import without errors.

## 4. Verify PyTorch Installation (after running install task)

```bash
pixi shell
python -c "import torch; print('PyTorch:', torch.__version__); print('CUDA available:', torch.cuda.is_available())"
exit
```

Expected:
- PyTorch version displayed
- `CUDA available: True` (if GPU is properly configured)

## 5. Verify LeRobot Installation (after running install task)

```bash
pixi shell
python -c "import lerobot; print('LeRobot:', lerobot.__version__)"
exit
```

Expected: LeRobot 0.3.3

## 6. Check Build Tools

```bash
pixi shell
cmake --version
colcon version-check
exit
```

Expected: CMake and Colcon version numbers displayed.

## 7. Verify Gazebo Installation

Gazebo is now managed by Pixi (no system-wide installation needed). Verify it's working:

```bash
pixi shell

# Check which gz command is being used (should be from pixi environment)
which gz

# Verify gz CLI is available
gz --version

# Check gz-sim and gz-gui packages are installed
pixi list | grep -E "gz-sim|gz-gui"

# Test gz sim command (should show help without errors)
gz sim --help

exit
```

Expected:
- `which gz` should show a path in `.pixi/envs/.../bin/gz` (not system path)
- `gz --version` should display version information
- `gz-sim` and `gz-gui` packages should appear in `pixi list` output
- `gz sim --help` should display help text

Note: You don't need to uninstall system-wide Gazebo. Pixi's isolated environment ensures the pixi-managed version is used when running `pixi run` or `pixi shell`.

## 8. Verify All Tasks Are Available

```bash
# List all available tasks
pixi task list
```

Expected tasks:
- detect-gpu
- install-rtx5090-pytorch
- install-standard-pytorch
- install-lerobot
- setup-ros
- setup-so-arm100
- setup-colcon
- build
- clean
- so-arm-gz
- lerobot-inference
- test-joints
- zenoh

## Quick Verification Script

Run this comprehensive check:

```bash
pixi run bash -c '
echo "=== Pixi Environment Verification ==="
echo ""
echo "Python: $(python --version)"
echo "CMake: $(cmake --version | head -n1)"
echo "Colcon: $(colcon version-check 2>/dev/null | head -n1 || echo "not found")"
echo ""
echo "Python Packages:"
python -c "import sys; packages=[\"numpy\", \"opencv-python\", \"huggingface_hub\"]; [print(f\"  ✓ {p}\") if __import__(p.replace(\"-\", \"_\").split(\"[\")[0]) else print(f\"  ✗ {p}\") for p in packages]" 2>/dev/null || echo "  Error checking packages"
echo ""
echo "PyTorch (if installed):"
python -c "import torch; print(f\"  ✓ PyTorch {torch.__version__}\"); print(f\"  CUDA: {torch.cuda.is_available()}\")" 2>/dev/null || echo "  Not installed yet"
echo ""
echo "LeRobot (if installed):"
python -c "import lerobot; print(f\"  ✓ LeRobot {lerobot.__version__}\")" 2>/dev/null || echo "  Not installed yet"
'
```

## Expected Output After Full Setup

After completing all installation steps in `docs/DEVELOPMENT.md`, you should see:

- ✓ Python 3.12.x
- ✓ CMake available
- ✓ Colcon available
- ✓ NumPy, OpenCV, HuggingFace Hub installed
- ✓ PyTorch with CUDA available (if GPU setup is complete)
- ✓ LeRobot 0.3.3 installed
- ✓ Gazebo (gz-sim and gz-gui) installed and accessible via `gz` command

## Troubleshooting

### Package Not Found

If a package is missing, re-run the corresponding installation step:

```bash
# For base packages
pixi install

# For PyTorch
pixi run install-rtx5090-pytorch  # or install-standard-pytorch

# For LeRobot
pixi run install-lerobot
```

### CUDA Not Available

If `torch.cuda.is_available()` returns `False`:

1. Check NVIDIA driver: `nvidia-smi`
2. Verify CUDA toolkit installation
3. Ensure PyTorch was installed with CUDA support

### Import Errors

If you get import errors inside `pixi shell`:

1. Exit and re-enter: `exit` then `pixi shell`
2. Verify package installation: `pixi list`
3. Reinstall if needed: `pixi install --force`

### Gazebo Not Found

If `gz` command is not found or points to system installation:

1. Verify packages are installed: `pixi list | grep gz`
2. Reinstall if needed: `pixi install`
3. Check PATH in pixi shell: `echo $PATH` (should include `.pixi/envs/.../bin`)
4. If system `gz` is being used, ensure you're running commands via `pixi run` or inside `pixi shell`
