#!/bin/bash

###############################################################################
# Optimize for OpenShift Local (CRC)
#
# This script reduces resource requests/limits for running on CRC
###############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Optimizing demo for OpenShift Local (CRC)...${NC}"
echo ""

# 1. Optimize DevSpaces CheCluster
echo "Optimizing DevSpaces configuration..."
cat > "$SCRIPT_DIR/components/devspaces/workspace-config/checluster.yaml" <<'EOF'
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: openshift-devspaces
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    metrics:
      enable: false
    pluginRegistry:
      openVSXURL: https://open-vsx.org
    devfileRegistry:
      externalDevfileRegistries:
        - url: https://registry.devfile.io
  containerRegistry: {}
  devEnvironments:
    startTimeoutSeconds: 600
    secondsOfRunBeforeIdling: -1
    maxNumberOfWorkspacesPerUser: 3
    maxNumberOfRunningWorkspacesPerUser: 1
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build
    defaultEditor: che-incubator/che-code/latest
    defaultNamespace:
      autoProvision: true
      template: <username>-devspaces
    defaultComponents:
      - name: universal-developer-image
        container:
          image: quay.io/devfile/universal-developer-image:latest
          memoryLimit: 2Gi
          memoryRequest: 1Gi
          cpuLimit: 1000m
          cpuRequest: 500m
    storage:
      pvcStrategy: per-workspace
      perWorkspacePVCSize: 5Gi
  networking:
    auth:
      gateway:
        configLabels:
          app: che
          component: che-gateway-config
EOF
echo -e "${GREEN}✓ DevSpaces optimized${NC}"

# 2. Optimize Kitchensink Deployment
echo "Optimizing Kitchensink deployment..."
cat > "$SCRIPT_DIR/components/kitchensink/k8s/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kitchensink
  namespace: kitchensink-dev
  labels:
    app: kitchensink
    app.kubernetes.io/name: kitchensink
    app.kubernetes.io/component: application
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kitchensink
  template:
    metadata:
      labels:
        app: kitchensink
        version: v1
    spec:
      containers:
        - name: kitchensink
          image: quay.io/mclhrn/kitchensink:latest
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: admin
              containerPort: 9990
              protocol: TCP
          env:
            - name: JAVA_OPTS_APPEND
              value: "-Djboss.bind.address=0.0.0.0 -Djboss.bind.address.management=0.0.0.0"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "768Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health/live
              port: 9990
              scheme: HTTP
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9990
              scheme: HTTP
            initialDelaySeconds: 30
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
EOF
echo -e "${GREEN}✓ Kitchensink deployment optimized${NC}"

# 3. Optimize Devfile
echo "Optimizing Devfile..."
sed -i '' 's/memoryLimit: 3Gi/memoryLimit: 2Gi/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml" 2>/dev/null || \
sed -i 's/memoryLimit: 3Gi/memoryLimit: 2Gi/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml"

sed -i '' 's/cpuLimit: 2000m/cpuLimit: 1000m/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml" 2>/dev/null || \
sed -i 's/cpuLimit: 2000m/cpuLimit: 1000m/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml"

# Find and replace the EAP container memory (appears after tools container)
sed -i '' 's/memoryLimit: 2Gi/memoryLimit: 1536Mi/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml" 2>/dev/null || \
sed -i 's/memoryLimit: 2Gi/memoryLimit: 1536Mi/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml"

sed -i '' 's/cpuLimit: 1000m/cpuLimit: 750m/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml" 2>/dev/null || \
sed -i 's/cpuLimit: 1000m/cpuLimit: 750m/g' "$SCRIPT_DIR/components/kitchensink/devfile.yaml"

echo -e "${GREEN}✓ Devfile optimized${NC}"

# 4. Optimize template skeleton devfile
echo "Optimizing template skeleton..."
if [ -f "$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton/devfile.yaml" ]; then
  sed -i '' 's/memoryLimit: 3Gi/memoryLimit: 2Gi/g' "$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton/devfile.yaml" 2>/dev/null || \
  sed -i 's/memoryLimit: 3Gi/memoryLimit: 2Gi/g' "$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton/devfile.yaml"

  echo -e "${GREEN}✓ Template skeleton optimized${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CRC Optimization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Changes made:"
echo "  • DevSpaces: Reduced memory to 2Gi, limited to 1 concurrent workspace"
echo "  • Kitchensink: Reduced to 256Mi request, 768Mi limit"
echo "  • Devfile: Reduced to 2Gi tools, 1.5Gi EAP runtime"
echo ""
echo "Next steps:"
echo "  1. Ensure CRC is configured with at least 6 CPUs and 16GB RAM"
echo "  2. Run: ./setup-source-code.sh (if not already done)"
echo "  3. Commit changes: git add -A && git commit -m 'Optimize for CRC'"
echo "  4. Push to your fork: git push"
echo "  5. Install: cd bootstrap && ./install.sh"
echo ""
echo "See CRC-SETUP.md for complete CRC installation guide"
