#!/bin/bash

###############################################################################
# Show Current Configuration
#
# Displays which environment configuration is currently active
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Current Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check DevSpaces memory
DEVSPACES_MEM=$(grep -A 5 "name: universal-developer-image" "$SCRIPT_DIR/components/devspaces/workspace-config/checluster.yaml" | grep "memoryLimit:" | awk '{print $2}' | head -1)

# Check Kitchensink memory - more precise extraction
KITCHENSINK_REQUEST=$(grep -A 2 "requests:" "$SCRIPT_DIR/components/kitchensink/k8s/deployment.yaml" | grep "memory:" | awk '{print $2}' | tr -d '"')
KITCHENSINK_LIMIT=$(grep -A 2 "limits:" "$SCRIPT_DIR/components/kitchensink/k8s/deployment.yaml" | grep "memory:" | awk '{print $2}' | tr -d '"')

# Check max workspaces
MAX_WORKSPACES=$(grep "maxNumberOfWorkspacesPerUser:" "$SCRIPT_DIR/components/devspaces/workspace-config/checluster.yaml" | awk '{print $2}')
MAX_RUNNING=$(grep "maxNumberOfRunningWorkspacesPerUser:" "$SCRIPT_DIR/components/devspaces/workspace-config/checluster.yaml" | awk '{print $2}')

# Check PVC size
PVC_SIZE=$(grep "perWorkspacePVCSize:" "$SCRIPT_DIR/components/devspaces/workspace-config/checluster.yaml" | awk '{print $2}')

# Determine configuration
# Allow for slight variations but check key indicators
if [ "$MAX_RUNNING" = "1" ] && [ "$KITCHENSINK_REQUEST" = "256Mi" ]; then
    CONFIG="CRC"
    COLOR=$YELLOW
elif [ "$MAX_RUNNING" = "3" ] && [ "$KITCHENSINK_REQUEST" = "512Mi" ]; then
    CONFIG="PRODUCTION"
    COLOR=$GREEN
else
    CONFIG="CUSTOM/MIXED"
    COLOR=$RED
fi

echo -e "${COLOR}Configuration: ${CONFIG}${NC}"
echo ""

echo "DevSpaces Settings:"
echo "  Tools Memory:        ${DEVSPACES_MEM:-Not explicitly set}"
echo "  Max Workspaces:      $MAX_WORKSPACES"
echo "  Concurrent Running:  $MAX_RUNNING"
echo "  PVC Size:            $PVC_SIZE"

echo ""
echo "Kitchensink Settings:"
echo "  Memory Request:      $KITCHENSINK_REQUEST"
echo "  Memory Limit:        $KITCHENSINK_LIMIT"

echo ""
echo -e "${BLUE}========================================${NC}"

if [ "$CONFIG" = "CRC" ]; then
    echo -e "${YELLOW}Optimized for OpenShift Local (CRC)${NC}"
    echo ""
    echo "To switch to production:"
    echo "  ./restore-production-defaults.sh"
elif [ "$CONFIG" = "PRODUCTION" ]; then
    echo -e "${GREEN}Configured for Production OpenShift${NC}"
    echo ""
    echo "To optimize for CRC:"
    echo "  ./optimize-for-crc.sh"
else
    echo -e "${RED}Mixed/Custom Configuration${NC}"
    echo ""
    echo "To set to CRC:        ./optimize-for-crc.sh"
    echo "To set to Production: ./restore-production-defaults.sh"
fi

echo -e "${BLUE}========================================${NC}"
