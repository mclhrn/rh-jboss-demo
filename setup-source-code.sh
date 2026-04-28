#!/bin/bash

###############################################################################
# Setup Script: Kitchensink Source Code and Template Skeleton
#
# This script downloads the official JBoss kitchensink quickstart and sets up:
# 1. The kitchensink application source code
# 2. The Developer Hub template skeleton
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/jboss-quickstarts-$$"

print_header() {
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "Setting Up JBoss Kitchensink Source Code"

# Step 1: Download the official JBoss EAP quickstarts
print_info "Downloading JBoss EAP 7.4 quickstarts from GitHub..."

if ! command -v git &> /dev/null; then
    print_error "git is not installed. Please install git and try again."
    exit 1
fi

git clone --depth 1 --branch 7.4.x https://github.com/jboss-developer/jboss-eap-quickstarts.git "$TEMP_DIR" 2>/dev/null

if [ ! -d "$TEMP_DIR/kitchensink" ]; then
    print_error "Failed to download kitchensink quickstart"
    exit 1
fi

print_success "Downloaded JBoss EAP quickstarts"

# Step 2: Copy kitchensink source code
print_info "Copying kitchensink source code to components/kitchensink/..."

KITCHENSINK_DIR="$SCRIPT_DIR/components/kitchensink"

# Copy source files
if [ -d "$KITCHENSINK_DIR/src" ]; then
    print_info "src/ directory already exists, backing up..."
    mv "$KITCHENSINK_DIR/src" "$KITCHENSINK_DIR/src.backup.$(date +%s)"
fi

cp -r "$TEMP_DIR/kitchensink/src" "$KITCHENSINK_DIR/"
print_success "Copied src/ directory"

# Copy pom.xml
if [ -f "$KITCHENSINK_DIR/pom.xml" ]; then
    print_info "pom.xml already exists, backing up..."
    mv "$KITCHENSINK_DIR/pom.xml" "$KITCHENSINK_DIR/pom.xml.backup.$(date +%s)"
fi

cp "$TEMP_DIR/kitchensink/pom.xml" "$KITCHENSINK_DIR/"
print_success "Copied pom.xml"

# Update the finalName in pom.xml to match our app name
sed -i.bak 's/<finalName>.*<\/finalName>/<finalName>kitchensink<\/finalName>/' "$KITCHENSINK_DIR/pom.xml"
rm -f "$KITCHENSINK_DIR/pom.xml.bak"
print_success "Updated pom.xml finalName"

# Step 3: Set up Developer Hub template skeleton
print_info "Setting up Developer Hub template skeleton..."

SKELETON_DIR="$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton"

# Create directories
mkdir -p "$SKELETON_DIR/k8s"
mkdir -p "$SKELETON_DIR/.vscode"

# Copy source code to skeleton
print_info "Copying source code to skeleton..."
cp -r "$KITCHENSINK_DIR/src" "$SKELETON_DIR/"

# Copy pom.xml and templatize it
cat > "$SKELETON_DIR/pom.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>${{ values.component_id }}</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>war</packaging>

    <name>${{ values.component_id }}</name>
    <description>${{ values.description }}</description>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <failOnMissingWebXml>false</failOnMissingWebXml>
        <version.server.bom>7.4.0.GA</version.server.bom>
        <version.wildfly.maven.plugin>4.0.0.Final</version.wildfly.maven.plugin>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.jboss.bom</groupId>
                <artifactId>jboss-eap-jakartaee8-with-tools</artifactId>
                <version>${version.server.bom}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <!-- Jakarta EE APIs -->
        <dependency>
            <groupId>jakarta.platform</groupId>
            <artifactId>jakarta.jakartaee-api</artifactId>
            <scope>provided</scope>
        </dependency>

        <!-- Bean Validation -->
        <dependency>
            <groupId>org.hibernate.validator</groupId>
            <artifactId>hibernate-validator</artifactId>
            <scope>provided</scope>
        </dependency>

        <!-- JUnit for testing -->
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>

        <!-- Arquillian for integration testing -->
        <dependency>
            <groupId>org.jboss.arquillian.junit</groupId>
            <artifactId>arquillian-junit-container</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <finalName>${{ values.component_id }}</finalName>
        <plugins>
            <plugin>
                <groupId>org.wildfly.plugins</groupId>
                <artifactId>wildfly-maven-plugin</artifactId>
                <version>${version.wildfly.maven.plugin}</version>
            </plugin>
        </plugins>
    </build>
</project>
EOF

print_success "Created templated pom.xml in skeleton"

# Copy other skeleton files (already created)
cp "$KITCHENSINK_DIR/k8s/service.yaml" "$SKELETON_DIR/k8s/" 2>/dev/null || true
cp "$KITCHENSINK_DIR/k8s/route.yaml" "$SKELETON_DIR/k8s/" 2>/dev/null || true
cp "$KITCHENSINK_DIR/.vscode/settings.json" "$SKELETON_DIR/.vscode/" 2>/dev/null || true

print_success "Copied additional skeleton files"

# Step 4: Create catalog-info.yaml for kitchensink
print_info "Creating catalog-info.yaml for kitchensink application..."

cat > "$KITCHENSINK_DIR/catalog-info.yaml" <<'EOF'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: kitchensink
  description: JBoss EAP Kitchensink demo application
  annotations:
    github.com/project-slug: YOUR_ORG/rh-jboss-demo
    argocd/app-name: kitchensink
  tags:
    - java
    - jboss-eap
    - demo
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: demo-system
  providesApis:
    - kitchensink-api
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: kitchensink-api
  description: REST API for member management
spec:
  type: openapi
  lifecycle: production
  owner: platform-team
  system: demo-system
  definition: |
    openapi: 3.0.0
    info:
      title: Kitchensink API
      version: 1.0.0
    paths:
      /rest/members:
        get:
          summary: List all members
          responses:
            '200':
              description: List of members
        post:
          summary: Register a new member
          responses:
            '200':
              description: Member registered
EOF

print_success "Created catalog-info.yaml"

# Step 5: Clean up
print_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
print_success "Cleanup complete"

# Step 6: Summary
print_header "Setup Complete!"

echo ""
echo -e "${GREEN}✓ Kitchensink source code installed in:${NC}"
echo "  $KITCHENSINK_DIR/src/"
echo "  $KITCHENSINK_DIR/pom.xml"

echo ""
echo -e "${GREEN}✓ Developer Hub template skeleton created in:${NC}"
echo "  $SKELETON_DIR/"

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Update CHANGEME placeholders in YAML files:"
echo "     find . -type f -name '*.yaml' -exec sed -i '' 's/CHANGEME/your-username/g' {} \\;"
echo ""
echo "  2. Update catalog-info.yaml with your GitHub org"
echo ""
echo "  3. Test the kitchensink build:"
echo "     cd components/kitchensink"
echo "     mvn clean package"
echo ""
echo "  4. Commit and push to your forked repository"
echo ""

print_success "Ready to install the demo!"
