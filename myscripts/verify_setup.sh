#!/bin/bash
# Comprehensive setup verification and execution for RTX 5090 and standard GPU platforms
# Verifies and executes all setup steps: prerequisites, base env, PyTorch, LeRobot, build, and launch readiness
#
# Usage:
#   # Verification only (default - does not execute missing steps):
#   pixi run bash myscripts/verify_setup.sh
#   # Or from pixi shell:
#   ./myscripts/verify_setup.sh
#
#   # Auto-execute missing steps:
#   pixi run bash myscripts/verify_setup.sh --auto
#   # Or from pixi shell:
#   ./myscripts/verify_setup.sh --auto
#
# The --auto flag will automatically run any missing setup steps (PyTorch, LeRobot, build, etc.)
# and then re-verify the setup. Without --auto, the script only reports what needs to be done.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Parse arguments
AUTO_RUN=false
RERUN_COUNT=0
if [ "$1" == "--auto" ] || [ "$1" == "-y" ]; then
    AUTO_RUN=true
fi
# Check for recursion counter (second argument)
if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    RERUN_COUNT=$2
fi

echo "=== Setup Verification and Execution ==="
echo ""

# Detect GPU type
IS_RTX5090=false
GPU_NAME=""
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    if [[ "$GPU_NAME" == *"5090"* ]] || [[ "$GPU_NAME" == *"RTX 5090"* ]]; then
        IS_RTX5090=true
    fi
fi

# Track overall status
ALL_PASSED=true
STEPS_TO_RUN=()

# Function to check and report status
check_status() {
    local name="$1"
    local check_cmd="$2"
    local required="${3:-false}"
    
    echo -n "  $name: "
    if eval "$check_cmd" &> /dev/null; then
        echo "✓"
        return 0
    else
        echo "✗"
        if [ "$required" = "true" ]; then
            ALL_PASSED=false
        fi
        return 1
    fi
}


# Step 0: Prerequisites (system-wide)
echo "Step 0: System Prerequisites"
echo "=============================="

check_status "Pixi installed" "command -v pixi" true
if command -v pixi &> /dev/null; then
    PIXI_VER=$(pixi --version 2>&1)
    echo "    Version: $PIXI_VER"
fi

if command -v nvidia-smi &> /dev/null; then
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    echo "  ✓ NVIDIA driver: $DRIVER_VER"
    echo "  ✓ GPU: $GPU_NAME"
    if [ "$IS_RTX5090" = true ]; then
        echo "    → RTX 5090 detected (will use RTX 5090 PyTorch)"
    else
        echo "    → Standard GPU detected (will use standard PyTorch)"
    fi
else
    echo "  ⚠ NVIDIA GPU not detected (CPU-only mode)"
fi

check_status "libserial-dev" "pkg-config --exists libserial" false
echo ""

# Step 1: Base Environment
echo "Step 1: Base Environment (pixi install)"
echo "========================================"

if [ -z "$CONDA_PREFIX" ]; then
    echo "  ✗ Not in Pixi environment"
    if [ "$AUTO_RUN" = true ]; then
        echo "  → Running: pixi install"
        pixi install
        echo "  → Please run this script again from pixi shell: pixi shell"
        exit 0
    else
        echo "  Run: pixi install"
        echo "  Then: pixi shell or pixi run bash myscripts/verify_setup.sh"
        ALL_PASSED=false
        echo ""
        exit 1
    fi
else
    echo "  ✓ Pixi environment active: $CONDA_PREFIX"
    echo ""
    
    check_status "Python 3.12" "python --version 2>&1 | grep -q 'Python 3.12'" true
    if command -v python &> /dev/null; then
        PYTHON_VER=$(python --version 2>&1)
        echo "    $PYTHON_VER"
    fi
    
    check_status "CMake" "command -v cmake" true
    check_status "Colcon" "command -v colcon" true
    check_status "ROS 2 Kilted" "[ -n \"\$ROS_DISTRO\" ] && [ \"\$ROS_DISTRO\" = \"kilted\" ]" true
    if [ -n "$ROS_DISTRO" ]; then
        echo "    ROS_DISTRO=$ROS_DISTRO"
    fi
    
    check_status "ros2 command" "command -v ros2" true
    echo ""
fi

# Step 2: GPU Detection
echo "Step 2: GPU Detection"
echo "======================"
if [ -f "$PROJECT_ROOT/scripts/detect_gpu_env.sh" ]; then
    echo "  ✓ GPU detection script available"
else
    echo "  ⚠ GPU detection script not found"
fi
echo ""

# Step 3: PyTorch Installation
if [ "$IS_RTX5090" = true ]; then
    echo "Step 3: RTX 5090 PyTorch Installation"
    echo "======================================"
    
    PYTORCH_INSTALLED=false
    PYTORCH_CORRECT=false
    
    if python -c "import torch" 2>/dev/null; then
        PYTORCH_INSTALLED=true
        TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
        CUDA_AVAIL=$(python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
        
        echo "  ✓ PyTorch installed: $TORCH_VER"
        
        # Check for RTX 5090 specific version
        if [[ "$TORCH_VER" == *"2.7.0"* ]] && [[ "$TORCH_VER" == *"cu128"* ]]; then
            echo "    ✓ RTX 5090 version (2.7.0+cu128)"
            PYTORCH_CORRECT=true
        else
            echo "    ⚠ Not RTX 5090 version (expected 2.7.0+cu128)"
            PYTORCH_CORRECT=false
        fi
        
        echo "    CUDA available: $CUDA_AVAIL"
        if [ "$CUDA_AVAIL" != "True" ]; then
            echo "    ⚠ CUDA not available - check driver and toolkit"
        fi
        
        # Optional torchcodec check (warning only, doesn't fail)
        if python -c "import torchcodec" 2>/dev/null; then
            TORCHCODEC_VER=$(python -c "import torchcodec; print(torchcodec.__version__)" 2>/dev/null)
            echo "    ✓ torchcodec installed: $TORCHCODEC_VER"
        else
            echo "    ⚠ torchcodec not installed (optional - may be needed for some LeRobot features)"
        fi
        
        # If PyTorch version is wrong, needs reinstall
        if [ "$PYTORCH_CORRECT" = false ]; then
            echo "  ✗ RTX 5090 PyTorch version incorrect - needs reinstall"
            STEPS_TO_RUN+=("pixi run install-rtx5090-pytorch")
            ALL_PASSED=false
        fi
    else
        echo "  ✗ RTX 5090 PyTorch not installed"
        STEPS_TO_RUN+=("pixi run install-rtx5090-pytorch")
        ALL_PASSED=false
    fi
else
    echo "Step 3: Standard PyTorch Installation"
    echo "======================================"
    
    if python -c "import torch" 2>/dev/null; then
        TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
        CUDA_AVAIL=$(python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
        echo "  ✓ PyTorch installed: $TORCH_VER"
        echo "    CUDA available: $CUDA_AVAIL"
        
        # Optional torchcodec check (warning only, doesn't fail)
        if python -c "import torchcodec" 2>/dev/null; then
            TORCHCODEC_VER=$(python -c "import torchcodec; print(torchcodec.__version__)" 2>/dev/null)
            echo "    ✓ torchcodec installed: $TORCHCODEC_VER"
        else
            echo "    ⚠ torchcodec not installed (optional - may be needed for some LeRobot features)"
        fi
    else
        echo "  ✗ Standard PyTorch not installed"
        STEPS_TO_RUN+=("pixi run install-standard-pytorch")
        ALL_PASSED=false
    fi
fi
echo ""

# Step 4: LeRobot Installation
echo "Step 4: LeRobot Installation"
echo "============================"

if python -c "import lerobot" 2>/dev/null; then
    LEROBOT_VER=$(python -c "import lerobot; print(lerobot.__version__)" 2>/dev/null)
    echo "  ✓ LeRobot installed: $LEROBOT_VER"
    if [ "$LEROBOT_VER" != "0.3.3" ]; then
        echo "    ⚠ Expected version 0.3.3"
    fi
else
    echo "  ✗ LeRobot not installed"
    STEPS_TO_RUN+=("pixi run install-lerobot")
    ALL_PASSED=false
fi
echo ""

# Step 5: Build
echo "Step 5: Workspace Build"
echo "======================="

if [ -d "$PROJECT_ROOT/install" ] && [ -f "$PROJECT_ROOT/install/setup.bash" ]; then
    echo "  ✓ install/ directory exists"
    echo "  ✓ install/setup.bash exists"
    
    if [ -d "$PROJECT_ROOT/install/pai_bringup" ]; then
        echo "  ✓ pai_bringup built"
    else
        echo "  ⚠ pai_bringup not found in install/"
    fi
else
    echo "  ✗ Workspace not built"
    STEPS_TO_RUN+=("pixi run build")
    ALL_PASSED=false
fi
echo ""

# Step 6: Gazebo
echo "Step 6: Gazebo Installation"
echo "==========================="

if command -v gz &> /dev/null; then
    GZ_PATH=$(which gz)
    if [[ "$GZ_PATH" == *".pixi"* ]] || [[ "$GZ_PATH" == "$CONDA_PREFIX"* ]]; then
        echo "  ✓ gz command found (Pixi-managed)"
        if gz --version &> /dev/null; then
            GZ_VER=$(gz --version 2>&1 | head -n1)
            echo "    $GZ_VER"
        fi
        
        if gz sim --help &> /dev/null; then
            echo "  ✓ gz sim command works"
        else
            echo "  ✗ gz sim command failed"
            ALL_PASSED=false
        fi
    else
        echo "  ⚠ gz command found but not from Pixi environment"
        ALL_PASSED=false
    fi
else
    echo "  ✗ gz command not found"
    ALL_PASSED=false
fi
echo ""

# Step 7: Launch Readiness
echo "Step 7: Launch Readiness (so-arm-gz)"
echo "====================================="

if [ -f "$PROJECT_ROOT/pai_bringup/launch/so_arm_gz_bringup.launch.py" ]; then
    echo "  ✓ Launch file exists"
else
    echo "  ✗ Launch file not found"
    ALL_PASSED=false
fi

# Check tasks (pixi task list may not work, so check pixi.toml directly)
if [ -f "$PROJECT_ROOT/pixi.toml" ]; then
    if grep -q "so-arm-gz" "$PROJECT_ROOT/pixi.toml"; then
        echo "  ✓ so-arm-gz task defined in pixi.toml"
    else
        echo "  ⚠ so-arm-gz task not found in pixi.toml"
    fi
    
    if grep -q "start_zenoh" "$PROJECT_ROOT/pixi.toml"; then
        echo "  ✓ start_zenoh task available (recommended middleware)"
    fi
fi
echo ""

# Execute missing steps if any
if [ ${#STEPS_TO_RUN[@]} -gt 0 ]; then
    echo "=== Missing Steps Detected ==="
    echo "=============================="
    echo "The following steps need to be executed:"
    for step in "${STEPS_TO_RUN[@]}"; do
        echo "  - $step"
    done
    echo ""
    
    if [ "$AUTO_RUN" = true ]; then
        echo "Auto-running missing steps..."
        echo ""
        for step in "${STEPS_TO_RUN[@]}"; do
            echo "→ Executing: $step"
            eval "$step" || {
                echo "✗ Failed to execute: $step"
                exit 1
            }
            echo ""
        done
        echo "✓ All steps executed. Re-running verification..."
        echo ""
        
        # Prevent infinite loops - only re-run once
        if [ "$RERUN_COUNT" -ge 1 ]; then
            echo "⚠ Already re-ran verification once. Stopping to prevent infinite loop."
            echo "Please check the output above and run remaining steps manually if needed."
            exit 1
        fi
        
        # Re-run verification with incremented counter
        exec "$0" --auto $((RERUN_COUNT + 1))
    else
        echo "To auto-run these steps, use: $0 --auto"
        echo "Or run them manually:"
        for step in "${STEPS_TO_RUN[@]}"; do
            echo "  $step"
        done
    fi
    echo ""
fi

# Final Summary
echo "=== Summary ==="
echo "=============="
if [ "$ALL_PASSED" = true ] && [ ${#STEPS_TO_RUN[@]} -eq 0 ]; then
    echo "✓ All checks passed! Setup is complete."
    echo ""
    echo "Ready to launch:"
    echo "  Terminal 1: pixi run start_zenoh"
    echo "  Terminal 2: pixi run so-arm-gz"
    exit 0
else
    echo "✗ Some checks failed or steps need to be executed."
    echo ""
    if [ ${#STEPS_TO_RUN[@]} -gt 0 ]; then
        echo "Run missing steps with: $0 --auto"
    fi
    exit 1
fi
