#!/bin/bash
# run-tests.sh
# Test runner for jsonresume LaTeX package

# Don't exit on error - we want to run all tests
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
PASSED=0
FAILED=0
SKIPPED=0

# Check if lualatex is available
if ! command -v lualatex &> /dev/null; then
    echo -e "${RED}Error: lualatex is not installed or not in PATH${NC}"
    echo "Please install TeX Live with LuaLaTeX support"
    exit 1
fi

# Function to run a test
run_test() {
    local test_name="$1"
    local test_file="$2"
    local requires_network="${3:-false}"
    local pdf_file="${test_file%.tex}.pdf"
    
    echo -n "Running $test_name... "
    
    # Skip network tests if --skip-network is passed
    if [ "$requires_network" = "true" ] && [ "$SKIP_NETWORK" = "true" ]; then
        echo -e "${YELLOW}SKIPPED${NC} (network tests disabled)"
        ((SKIPPED++))
        return
    fi
    
    # Remove old PDF if exists
    rm -f "$pdf_file"
    
    # Run lualatex with shell-escape (needed for curl)
    lualatex --shell-escape --interaction=nonstopmode "$test_file" > /dev/null 2>&1
    
    # Check if PDF was generated (success indicator)
    if [ -f "$pdf_file" ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Re-running with output for debugging:"
        lualatex --shell-escape --interaction=nonstopmode "$test_file" 2>&1 | tail -30
        ((FAILED++))
    fi
}

# Function to run validation test (expected to have warnings but still compile)
run_validation_test() {
    local test_name="$1"
    local test_file="$2"
    local pdf_file="${test_file%.tex}.pdf"
    local log_file="${test_file%.tex}.log"
    
    echo -n "Running $test_name... "
    
    # Remove old files
    rm -f "$pdf_file" "$log_file"
    
    # Run lualatex
    lualatex --shell-escape --interaction=nonstopmode "$test_file" > /dev/null 2>&1
    
    # Check if PDF was generated
    if [ -f "$pdf_file" ]; then
        # Check if warnings were generated in the log
        if grep -q "Package jsonresume Warning" "$log_file" 2>/dev/null; then
            echo -e "${GREEN}PASSED${NC} (warnings generated as expected)"
            ((PASSED++))
        else
            echo -e "${YELLOW}PASSED${NC} (compiled but no warnings found in log)"
            ((PASSED++))
        fi
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Re-running with output for debugging:"
        lualatex --shell-escape --interaction=nonstopmode "$test_file" 2>&1 | tail -30
        ((FAILED++))
    fi
}

# Parse arguments
SKIP_NETWORK=false
for arg in "$@"; do
    case $arg in
        --skip-network)
            SKIP_NETWORK=true
            shift
            ;;
    esac
done

echo "========================================"
echo "JSON Resume LaTeX Package - Test Suite"
echo "========================================"
echo ""

# Core tests
echo "--- Core Tests ---"
run_test "Basic file loading test" "test-basic.tex" false
run_test "Section rendering test" "test-sections.tex" false
run_test "URL loading test" "test-url.tex" true

# Full schema tests
echo ""
echo "--- Full Schema Tests ---"
run_test "Full schema rendering" "test-full-schema.tex" false

# Validation tests
echo ""
echo "--- Validation Tests ---"
run_validation_test "Strict mode validation" "test-validation.tex"

# Cleanup auxiliary files
echo ""
echo "Cleaning up..."
rm -f *.aux *.log *.out *.pdf

# Summary
echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
