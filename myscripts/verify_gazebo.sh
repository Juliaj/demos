#!/bin/bash
# Verify Gazebo installation in Pixi environment
# Checks that gz command is available and points to pixi-managed installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== Verifying Gazebo Installation ==="
echo ""

# Check if running in pixi shell or via pixi run
if [ -z "$CONDA_PREFIX" ]; then
    echo "⚠ Warning: Not in Pixi environment. Run via 'pixi run' or 'pixi shell'"
    echo ""
    echo "Checking system gz command..."
    if command -v gz &> /dev/null; then
        GZ_PATH=$(which gz)
        echo "Found: $GZ_PATH"
        echo "⚠ This is system-wide Gazebo, not Pixi-managed"
    else
        echo "✗ gz command not found"
    fi
    exit 1
fi

echo "Pixi environment: $CONDA_PREFIX"
echo ""

# Check gz command
if command -v gz &> /dev/null; then
    GZ_PATH=$(which gz)
    echo "✓ gz command found: $GZ_PATH"
    
    # Check if it's in pixi environment
    if [[ "$GZ_PATH" == *".pixi"* ]] || [[ "$GZ_PATH" == "$CONDA_PREFIX"* ]]; then
        echo "✓ gz is from Pixi environment (correct)"
    else
        echo "⚠ Warning: gz is not from Pixi environment"
        echo "  Expected path to contain: .pixi or $CONDA_PREFIX"
    fi
else
    echo "✗ gz command not found"
    exit 1
fi

# Check gz version
echo ""
echo "Gazebo version:"
if gz --version &> /dev/null; then
    gz --version
else
    echo "⚠ Could not get version"
fi

# Check gz sim command
echo ""
echo "Testing 'gz sim' command:"
if gz sim --help &> /dev/null; then
    echo "✓ 'gz sim' command works"
else
    echo "✗ 'gz sim' command failed"
    exit 1
fi

# Check packages via pixi list
echo ""
echo "Checking installed packages:"
if command -v pixi &> /dev/null; then
    if pixi list 2>/dev/null | grep -q "gz-sim"; then
        echo "✓ gz-sim package installed"
    else
        echo "⚠ gz-sim package not found in pixi list"
    fi
    
    if pixi list 2>/dev/null | grep -q "gz-gui"; then
        echo "✓ gz-gui package installed"
    else
        echo "⚠ gz-gui package not found in pixi list"
    fi
else
    echo "⚠ pixi command not available"
fi

echo ""
echo "=== Verification Complete ==="
