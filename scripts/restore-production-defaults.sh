#!/bin/bash

###############################################################################
# Restore Production Defaults
#
# This script restores production resource settings after CRC optimization
###############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}Restoring production defaults...${NC}"
echo ""

# 1. Restore DevSpaces CheCluster
echo "Restoring DevSpaces configuration..."
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
      enable: true
    pluginRegistry:
      openVSXURL: https://open-vsx.org
    devfileRegistry:
      externalDevfileRegistries:
        - url: https://registry.devfile.io
  containerRegistry: {}
  devEnvironments:
    startTimeoutSeconds: 600
    secondsOfRunBeforeIdling: -1
    maxNumberOfWorkspacesPerUser: 5
    maxNumberOfRunningWorkspacesPerUser: 3
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
          memoryLimit: 3Gi
          cpuLimit: 2000m
    storage:
      pvcStrategy: per-workspace
      perWorkspacePVCSize: 10Gi
  networking:
    auth:
      gateway:
        configLabels:
          app: che
          component: che-gateway-config
EOF
echo -e "${GREEN}✓ DevSpaces configuration restored${NC}"

# 2. Restore Kitchensink Deployment
echo "Restoring Kitchensink deployment..."
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
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
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
echo -e "${GREEN}✓ Kitchensink deployment restored${NC}"

# 3. Restore Devfile
echo "Restoring Devfile..."
cat > "$SCRIPT_DIR/components/kitchensink/devfile.yaml" <<'EOF'
schemaVersion: 2.2.0
metadata:
  name: jboss-eap-kitchensink
  displayName: JBoss EAP Kitchensink
  description: JBoss EAP development environment with hot-reload
  tags: ["Java", "JBoss", "EAP", "Maven"]
  projectType: "jboss-eap"
  language: "Java"
  version: 1.0.0

components:
  # Development tools container
  - name: tools
    container:
      image: quay.io/devfile/universal-developer-image:latest
      memoryLimit: 3Gi
      cpuLimit: 2000m
      mountSources: true
      endpoints:
        - name: ide
          targetPort: 3100
          exposure: public
          protocol: https
      env:
        - name: MAVEN_OPTS
          value: "-Xmx1g"
      volumeMounts:
        - name: m2
          path: /home/user/.m2

  # JBoss EAP runtime container
  - name: eap
    container:
      image: registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:latest
      memoryLimit: 2Gi
      cpuLimit: 1000m
      mountSources: true
      sourceMapping: /projects
      endpoints:
        - name: jboss
          targetPort: 8080
          exposure: public
          protocol: http
        - name: debug
          targetPort: 5005
          exposure: internal
      env:
        - name: MAVEN_OPTS
          value: "-Xmx1g"
        - name: JAVA_OPTS_APPEND
          value: "-Djboss.bind.address=0.0.0.0"
      volumeMounts:
        - name: m2
          path: /home/jboss/.m2

  # Persistent Maven cache
  - name: m2
    volume:
      size: 3Gi

commands:
  # Build the application
  - id: build
    exec:
      component: tools
      commandLine: mvn clean package -DskipTests -f ${PROJECT_SOURCE}/components/kitchensink/pom.xml
      workingDir: ${PROJECT_SOURCE}/components/kitchensink
      group:
        kind: build
        isDefault: true

  # Run with hot-reload (recommended for development)
  - id: run-hot-reload
    exec:
      component: tools
      commandLine: |
        cd ${PROJECT_SOURCE}/components/kitchensink && \
        mvn wildfly:run \
          -Dwildfly.hostname=0.0.0.0 \
          -Dwildfly.port=8080 \
          -Dwildfly.dev
      workingDir: ${PROJECT_SOURCE}/components/kitchensink
      group:
        kind: run
        isDefault: true

  # Run in debug mode
  - id: debug
    exec:
      component: tools
      commandLine: |
        cd ${PROJECT_SOURCE}/components/kitchensink && \
        mvn wildfly:run \
          -Dwildfly.hostname=0.0.0.0 \
          -Dwildfly.port=8080 \
          -Dwildfly.dev \
          -Dwildfly.javaOpts="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
      workingDir: ${PROJECT_SOURCE}/components/kitchensink
      group:
        kind: debug

  # Run tests
  - id: test
    exec:
      component: tools
      commandLine: mvn test -f ${PROJECT_SOURCE}/components/kitchensink/pom.xml
      workingDir: ${PROJECT_SOURCE}/components/kitchensink
      group:
        kind: test

starterProjects:
  - name: kitchensink
    description: JBoss EAP Kitchensink starter
    git:
      remotes:
        origin: https://github.com/mclhrn/rh-jboss-demo.git
      checkoutFrom:
        revision: main
    subDir: components/kitchensink
EOF
echo -e "${GREEN}✓ Devfile restored${NC}"

# 4. Restore template skeleton devfile (if exists)
if [ -f "$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton/devfile.yaml" ]; then
    echo "Restoring template skeleton..."

    # Restore the devfile with template variables
    cat > "$SCRIPT_DIR/components/developer-hub/templates/jboss-template/skeleton/devfile.yaml" <<'EOF'
schemaVersion: 2.2.0
metadata:
  name: ${{ values.component_id }}
  displayName: ${{ values.component_id | capitalize }}
  description: ${{ values.description }}
  tags: ["Java", "JBoss", "EAP", "Maven"]
  projectType: "jboss-eap"
  language: "Java"
  version: 1.0.0

components:
  # Development tools container
  - name: tools
    container:
      image: quay.io/devfile/universal-developer-image:latest
      memoryLimit: 3Gi
      cpuLimit: 2000m
      mountSources: true
      endpoints:
        - name: ide
          targetPort: 3100
          exposure: public
          protocol: https
      env:
        - name: MAVEN_OPTS
          value: "-Xmx1g"
      volumeMounts:
        - name: m2
          path: /home/user/.m2

  # JBoss EAP runtime container
  - name: eap
    container:
      {%- if values.eap_version == "7.4" %}
      image: registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:latest
      {%- elif values.eap_version == "8.0" %}
      image: registry.redhat.io/jboss-eap-8/eap8-openjdk17-openshift-rhel8:latest
      {%- endif %}
      memoryLimit: 2Gi
      cpuLimit: 1000m
      mountSources: true
      endpoints:
        - name: jboss
          targetPort: 8080
          exposure: public
          protocol: http
        - name: debug
          targetPort: 5005
          exposure: internal
      env:
        - name: MAVEN_OPTS
          value: "-Xmx1g"
        - name: JAVA_OPTS_APPEND
          value: "-Djboss.bind.address=0.0.0.0"
      volumeMounts:
        - name: m2
          path: /home/jboss/.m2

  # Persistent Maven cache
  - name: m2
    volume:
      size: 3Gi

commands:
  # Build the application
  - id: build
    exec:
      component: tools
      commandLine: mvn clean package -DskipTests
      workingDir: ${PROJECT_SOURCE}
      group:
        kind: build
        isDefault: true

  # Run with hot-reload (recommended for development)
  - id: run-hot-reload
    exec:
      component: tools
      commandLine: |
        mvn wildfly:run \
          -Dwildfly.hostname=0.0.0.0 \
          -Dwildfly.port=8080 \
          -Dwildfly.dev
      workingDir: ${PROJECT_SOURCE}
      group:
        kind: run
        isDefault: true

  # Run in debug mode
  - id: debug
    exec:
      component: tools
      commandLine: |
        mvn wildfly:run \
          -Dwildfly.hostname=0.0.0.0 \
          -Dwildfly.port=8080 \
          -Dwildfly.dev \
          -Dwildfly.javaOpts="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
      workingDir: ${PROJECT_SOURCE}
      group:
        kind: debug

  # Run tests
  - id: test
    exec:
      component: tools
      commandLine: mvn test
      workingDir: ${PROJECT_SOURCE}
      group:
        kind: test

starterProjects:
  - name: ${{ values.component_id }}
    description: ${{ values.description }}
    git:
      remotes:
        origin: https://github.com/${{ values.destination.owner }}/${{ values.destination.repo }}
      checkoutFrom:
        revision: main
EOF
    echo -e "${GREEN}✓ Template skeleton restored${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Production Defaults Restored!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Changes made:"
echo "  • DevSpaces: Restored to 3Gi memory, 5 workspaces max, 3 concurrent"
echo "  • Kitchensink: Restored to 512Mi request, 1Gi limit"
echo "  • Devfile: Restored to 3Gi tools, 2Gi EAP runtime"
echo "  • Storage: Restored to 10Gi per workspace"
echo ""
echo "Next steps:"
echo "  1. Commit changes: git add -A && git commit -m 'Restore production defaults'"
echo "  2. Push to your fork: git push"
echo "  3. Install on production cluster: cd bootstrap && ./install.sh"
echo ""
echo "To switch back to CRC settings, run: ./scripts/optimize-for-crc.sh"
