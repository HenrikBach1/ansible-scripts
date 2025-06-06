#!/bin/bash
# Test script for robust container implementation
# This script tests both ROS2 and Yocto robust containers

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Robust Container Test Script${NC}"
echo "This script will test the robust container implementation for both ROS2 and Yocto"

# Source the container utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/container-utils.sh"

# Test containers
ROS2_TEST_CONTAINER="test_ros2_robust"
YOCTO_TEST_CONTAINER="test_yocto_robust"
TEST_WORKSPACE="/tmp/test_container_workspace"

# Clean up function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test resources...${NC}"
    
    # Stop and remove test containers
    docker stop $ROS2_TEST_CONTAINER >/dev/null 2>&1 || true
    docker rm $ROS2_TEST_CONTAINER >/dev/null 2>&1 || true
    
    docker stop $YOCTO_TEST_CONTAINER >/dev/null 2>&1 || true
    docker rm $YOCTO_TEST_CONTAINER >/dev/null 2>&1 || true
    
    # Remove test workspace
    rm -rf $TEST_WORKSPACE
    
    echo -e "${GREEN}Test cleanup complete${NC}"
}

# Handle script interruption
trap cleanup EXIT

# Create test workspace
mkdir -p $TEST_WORKSPACE
echo "Test workspace created at $TEST_WORKSPACE"

# Test ROS2 robust container
echo -e "\n${YELLOW}Testing ROS2 Robust Container${NC}"
if create_robust_container "ros2" "$ROS2_TEST_CONTAINER" "$TEST_WORKSPACE" "humble"; then
    echo -e "${GREEN}✓ ROS2 container created successfully${NC}"
    
    # Test detached command
    echo "Testing detached command..."
    if run_detached_command "$ROS2_TEST_CONTAINER" "echo 'ROS2 detached command test' > /workspace/ros2_test.txt"; then
        echo -e "${GREEN}✓ ROS2 detached command executed successfully${NC}"
    else
        echo -e "${RED}✗ ROS2 detached command failed${NC}"
    fi
    
    # Check file exists
    sleep 2
    if [ -f "$TEST_WORKSPACE/ros2_test.txt" ]; then
        echo -e "${GREEN}✓ ROS2 test file created successfully${NC}"
    else
        echo -e "${RED}✗ ROS2 test file not found${NC}"
    fi
    
    # Stop container
    docker stop "$ROS2_TEST_CONTAINER" >/dev/null 2>&1
    docker rm "$ROS2_TEST_CONTAINER" >/dev/null 2>&1
    echo "ROS2 container stopped and removed"
else
    echo -e "${RED}✗ ROS2 container creation failed${NC}"
fi

# Test Yocto robust container
echo -e "\n${YELLOW}Testing Yocto Robust Container${NC}"
if create_robust_container "yocto" "$YOCTO_TEST_CONTAINER" "$TEST_WORKSPACE" "ubuntu-22.04"; then
    echo -e "${GREEN}✓ Yocto container created successfully${NC}"
    
    # Test detached command
    echo "Testing detached command..."
    if run_detached_command "$YOCTO_TEST_CONTAINER" "echo 'Yocto detached command test' > /workdir/yocto_test.txt"; then
        echo -e "${GREEN}✓ Yocto detached command executed successfully${NC}"
    else
        echo -e "${RED}✗ Yocto detached command failed${NC}"
    fi
    
    # Check file exists
    sleep 2
    if [ -f "$TEST_WORKSPACE/yocto_test.txt" ]; then
        echo -e "${GREEN}✓ Yocto test file created successfully${NC}"
    else
        echo -e "${RED}✗ Yocto test file not found${NC}"
    fi
    
    # Stop container
    docker stop "$YOCTO_TEST_CONTAINER" >/dev/null 2>&1
    docker rm "$YOCTO_TEST_CONTAINER" >/dev/null 2>&1
    echo "Yocto container stopped and removed"
else
    echo -e "${RED}✗ Yocto container creation failed${NC}"
fi

echo -e "\n${GREEN}Test script completed${NC}"
echo "You can run the robust container scripts for production use:"
echo "./robust-ros2-container.sh"
echo "./robust-yocto-container.sh"
