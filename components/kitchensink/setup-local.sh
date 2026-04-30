#!/bin/bash
#
# Local Development Setup Script
# Downloads WildFly and builds the kitchensink application
#

set -e

WILDFLY_VERSION="27.0.1.Final"
WILDFLY_DIR="wildfly-${WILDFLY_VERSION}"
WILDFLY_ARCHIVE="${WILDFLY_DIR}.tar.gz"
WILDFLY_URL="https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/${WILDFLY_ARCHIVE}"

echo "========================================="
echo "Kitchensink Local Development Setup"
echo "========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v java &> /dev/null; then
    echo "❌ Java not found. Please install Java 11 or higher."
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 11 ]; then
    echo "❌ Java 11 or higher required. Found version: $JAVA_VERSION"
    exit 1
fi
echo "✅ Java $JAVA_VERSION found"

if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found. Please install Maven 3.6 or higher."
    exit 1
fi
echo "✅ Maven found: $(mvn -version | head -n 1)"

echo ""

# Download WildFly if not present
if [ -d "$WILDFLY_DIR" ]; then
    echo "✅ WildFly already downloaded at $WILDFLY_DIR"
else
    echo "Downloading WildFly $WILDFLY_VERSION..."
    if command -v wget &> /dev/null; then
        wget -q --show-progress "$WILDFLY_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "$WILDFLY_ARCHIVE" "$WILDFLY_URL"
    else
        echo "❌ Neither wget nor curl found. Please install one of them."
        exit 1
    fi

    echo "Extracting WildFly..."
    tar -xzf "$WILDFLY_ARCHIVE"
    rm "$WILDFLY_ARCHIVE"
    echo "✅ WildFly extracted to $WILDFLY_DIR"
fi

echo ""

# Build the application
echo "Building kitchensink application..."
mvn clean package -DskipTests

if [ $? -eq 0 ]; then
    echo "✅ Application built successfully!"
else
    echo "❌ Build failed. Check Maven output above."
    exit 1
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Start WildFly:"
echo "   ./$WILDFLY_DIR/bin/standalone.sh"
echo ""
echo "2. In another terminal, deploy the app:"
echo "   cp target/kitchensink.war $WILDFLY_DIR/standalone/deployments/ROOT.war"
echo ""
echo "3. Access the application:"
echo "   http://localhost:8080"
echo ""
echo "4. For hot-reload development, run in a separate terminal:"
echo "   while true; do"
echo "     mvn package -DskipTests -q"
echo "     cp target/kitchensink.war $WILDFLY_DIR/standalone/deployments/ROOT.war"
echo "     echo 'Deployed at '\$(date)"
echo "     sleep 5"
echo "   done"
echo ""
echo "5. For debugging, start WildFly with:"
echo "   ./$WILDFLY_DIR/bin/standalone.sh --debug"
echo "   Then attach your debugger to port 8787"
echo ""
