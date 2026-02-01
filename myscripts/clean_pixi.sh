#!/bin/bash
# Clean up Pixi environment and build artifacts
# Usage: ./myscripts/clean_pixi.sh [--all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== Cleaning Pixi Environment ==="
echo ""

if [ "$1" == "--all" ]; then
    echo "Performing complete cleanup (pixi environment + build artifacts + lock file)..."
    echo ""
    
    # Clean pixi environment
    if command -v pixi &> /dev/null; then
        echo "Cleaning Pixi environment..."
        pixi clean || echo "Warning: pixi clean failed or no environment to clean"
    fi
    
    # Remove build artifacts
    echo "Removing build artifacts (build/, install/, log/)..."
    rm -rf build install log
    
    # Remove lock file (optional, forces re-resolution)
    echo "Removing pixi.lock..."
    rm -f pixi.lock
    
    echo ""
    echo "✓ Complete cleanup finished"
    echo "Run 'pixi install' to recreate the environment"
else
    echo "Performing standard cleanup (pixi environment + build artifacts)..."
    echo ""
    
    # Clean pixi environment
    if command -v pixi &> /dev/null; then
        echo "Cleaning Pixi environment..."
        pixi clean || echo "Warning: pixi clean failed or no environment to clean"
    fi
    
    # Remove build artifacts
    echo "Removing build artifacts (build/, install/, log/)..."
    rm -rf build install log
    
    echo ""
    echo "✓ Standard cleanup finished"
    echo "Run 'pixi install' to recreate the environment"
    echo ""
    echo "For complete cleanup (including lock file), use: $0 --all"
fi
