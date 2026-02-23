#!/bin/sh
# verifyVvm.sh - Verify the VVM environment is functional.
# Run this script inside the VVM container.

set -e

echo "Checking vplanet binary..."
vplanet -v

echo ""
echo "Checking Python vplanet package..."
python -c "import vplanet; print('vplanet package:', vplanet.__file__)"

echo ""
echo "Running vplanet test suite..."
cd /workspace/vplanet && make test

echo ""
echo "All checks passed."
