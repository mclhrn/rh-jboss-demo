#!/bin/bash

###############################################################################
# Verification Script
#
# Checks that all placeholders have been replaced and setup is complete
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verifying Demo Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check 1: Source code exists
echo -e "${BLUE}Checking source code...${NC}"
if [ -d "$SCRIPT_DIR/components/kitchensink/src" ]; then
    echo -e "${GREEN}✓ Kitchensink source code present${NC}"
else
    echo -e "${RED}✗ Kitchensink source code missing${NC}"
    echo -e "  Run: ./setup-source-code.sh"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$SCRIPT_DIR/components/kitchensink/pom.xml" ]; then
    echo -e "${GREEN}✓ pom.xml present${NC}"
else
    echo -e "${RED}✗ pom.xml missing${NC}"
    echo -e "  Run: ./setup-source-code.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: No CHANGEME placeholders
echo ""
echo -e "${BLUE}Checking for CHANGEME placeholders...${NC}"
CHANGEME_COUNT=$(grep -r "CHANGEME" --include="*.yaml" "$SCRIPT_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGEME_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✓ No CHANGEME placeholders found${NC}"
else
    echo -e "${RED}✗ Found $CHANGEME_COUNT CHANGEME placeholders${NC}"
    echo -e "  Files with CHANGEME:"
    grep -r "CHANGEME" --include="*.yaml" "$SCRIPT_DIR" | cut -d: -f1 | sort -u | sed 's|^|    |'
    echo ""
    echo -e "  Fix with:"
    echo -e "    find . -type f -name '*.yaml' -exec sed -i '' 's/CHANGEME/your-username/g' {} \\;"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: No YOUR_ORG placeholders
echo ""
echo -e "${BLUE}Checking for YOUR_ORG placeholders...${NC}"
YOUR_ORG_COUNT=$(grep -r "YOUR_ORG" --include="*.yaml" --include="*.md" "$SCRIPT_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$YOUR_ORG_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✓ No YOUR_ORG placeholders found${NC}"
else
    echo -e "${YELLOW}⚠ Found $YOUR_ORG_COUNT YOUR_ORG placeholders${NC}"
    echo -e "  Files with YOUR_ORG:"
    grep -r "YOUR_ORG" --include="*.yaml" --include="*.md" "$SCRIPT_DIR" | cut -d: -f1 | sort -u | sed 's|^|    |'
    echo ""
    echo -e "  Note: Some may be in documentation examples (acceptable)"
    echo -e "  Check: grep -r 'YOUR_ORG' --include='*.yaml' ."
fi

# Check 4: GitHub repo URL is configured
echo ""
echo -e "${BLUE}Checking GitHub repository URL...${NC}"
REPO_URL=$(grep "repoURL:" "$SCRIPT_DIR/argocd/app-of-apps.yaml" | head -1 | awk '{print $2}')
if [ -n "$REPO_URL" ] && [ "$REPO_URL" != "https://github.com/CHANGEME/rh-jboss-demo" ]; then
    GITHUB_USER=$(echo "$REPO_URL" | sed 's|.*github.com/||' | sed 's|/.*||')
    echo -e "${GREEN}✓ GitHub repository configured: $REPO_URL${NC}"
    echo -e "  GitHub user: $GITHUB_USER"
else
    echo -e "${RED}✗ GitHub repository not configured${NC}"
    echo -e "  Update argocd/app-of-apps.yaml with your fork URL"
    ERRORS=$((ERRORS + 1))
fi

# Check 5: Quay.io registry configured
echo ""
echo -e "${BLUE}Checking container registry...${NC}"
IMAGE_NAME=$(grep "default: quay.io" "$SCRIPT_DIR/components/pipelines/kitchensink-pipeline.yaml" | awk '{print $2}')
if [ -n "$IMAGE_NAME" ] && [ "$IMAGE_NAME" != "quay.io/CHANGEME/kitchensink" ]; then
    echo -e "${GREEN}✓ Container registry configured: $IMAGE_NAME${NC}"
else
    echo -e "${YELLOW}⚠ Container registry may need configuration${NC}"
    echo -e "  Current: $IMAGE_NAME"
    echo -e "  Update in: components/pipelines/kitchensink-pipeline.yaml"
    echo -e "           : components/kitchensink/k8s/deployment.yaml"
fi

# Check 6: catalog-info.yaml configured
echo ""
echo -e "${BLUE}Checking catalog-info.yaml...${NC}"
if [ -f "$SCRIPT_DIR/components/kitchensink/catalog-info.yaml" ]; then
    PROJECT_SLUG=$(grep "github.com/project-slug:" "$SCRIPT_DIR/components/kitchensink/catalog-info.yaml" | awk '{print $2}')
    if [ -n "$PROJECT_SLUG" ] && [ "$PROJECT_SLUG" != "YOUR_ORG/rh-jboss-demo" ]; then
        echo -e "${GREEN}✓ catalog-info.yaml configured: $PROJECT_SLUG${NC}"
    else
        echo -e "${RED}✗ catalog-info.yaml has placeholder${NC}"
        echo -e "  Run: ./setup-source-code.sh"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ catalog-info.yaml missing${NC}"
    echo -e "  Run: ./setup-source-code.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Git status
echo ""
echo -e "${BLUE}Checking Git status...${NC}"
if [ -d "$SCRIPT_DIR/.git" ]; then
    if git -C "$SCRIPT_DIR" diff --quiet && git -C "$SCRIPT_DIR" diff --cached --quiet; then
        echo -e "${GREEN}✓ No uncommitted changes${NC}"
    else
        echo -e "${YELLOW}⚠ Uncommitted changes detected${NC}"
        echo -e "  Remember to commit and push before installing:"
        echo -e "    git add -A"
        echo -e "    git commit -m 'Complete setup'"
        echo -e "    git push"
    fi
else
    echo -e "${YELLOW}⚠ Not a git repository${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Setup verification passed!${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Commit changes: git add -A && git commit -m 'Complete setup'"
    echo -e "  2. Push to GitHub: git push"
    echo -e "  3. Install: cd bootstrap && ./install.sh"
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo ""
    echo -e "Please fix the errors above before installing"
fi
echo -e "${BLUE}========================================${NC}"

exit $ERRORS
