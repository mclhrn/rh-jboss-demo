# Kitchensink JBoss Application

This is the demo JBoss EAP application showcasing modern development workflows, hot-reload capabilities, and containerized deployment.

## Overview

The kitchensink application is a classic JBoss quickstart that demonstrates:

- **Java EE/Jakarta EE**: CDI, JPA, JAX-RS, Bean Validation
- **Member registration**: Simple CRUD operations
- **RESTful API**: JSON endpoints for member management
- **H2 Database**: In-memory database (no external dependencies)
- **Responsive UI**: Mobile-friendly interface

This application serves as the **perfect demo vehicle** because:
- Simple enough to understand quickly
- Complex enough to show real-world patterns
- Well-known in the JBoss community
- Demonstrates modern Java EE development

## What Gets Deployed

### 1. Application Source Code

```
components/kitchensink/src/
├── main/
│   ├── java/
│   │   └── org/jboss/as/quickstarts/kitchensink/
│   │       ├── model/
│   │       │   └── Member.java          # JPA entity
│   │       ├── data/
│   │       │   └── MemberRepository.java # Data access
│   │       ├── rest/
│   │       │   ├── MemberResourceRESTService.java  # REST API
│   │       │   └── JaxRsActivator.java
│   │       ├── service/
│   │       │   └── MemberRegistration.java  # Business logic
│   │       └── util/
│   │           └── Resources.java         # CDI producers
│   ├── resources/
│   │   ├── META-INF/
│   │   │   └── persistence.xml           # JPA configuration
│   │   └── import.sql                    # Sample data
│   └── webapp/
│       ├── WEB-INF/
│       │   ├── beans.xml                 # CDI config
│       │   └── faces-config.xml          # JSF config
│       ├── index.xhtml                   # Main UI
│       ├── style.css
│       └── ...
└── test/
    └── java/
        └── org/jboss/as/quickstarts/kitchensink/
            └── test/
                └── MemberRegistrationTest.java
```

### 2. Build Configuration

**pom.xml**: Maven configuration for:
- JBoss EAP 7.4 dependencies
- WildFly Maven Plugin (for hot-reload)
- JAX-RS, CDI, JPA, Bean Validation
- Arquillian for integration tests

**Key dependencies**:
```xml
<dependencies>
    <dependency>
        <groupId>jakarta.platform</groupId>
        <artifactId>jakarta.jakartaee-api</artifactId>
        <version>8.0.0</version>
        <scope>provided</scope>
    </dependency>
    
    <!-- JBoss/WildFly provides these at runtime -->
</dependencies>
```

### 3. Container Configuration

**Containerfile**:
```dockerfile
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:latest

# Copy WAR to deployments directory
COPY target/kitchensink.war /deployments/

# JBoss EAP will auto-deploy on startup
USER jboss
EXPOSE 8080
```

**Why this base image**:
- Official Red Hat JBoss EAP 7.4 image
- OpenJDK 11
- OpenShift-optimized (runs as non-root)
- Security patches from Red Hat

### 4. Kubernetes Manifests

**k8s/namespace.yaml**: Creates `kitchensink-dev` namespace

**k8s/deployment.yaml**: 
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kitchensink
  namespace: kitchensink-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kitchensink
  template:
    metadata:
      labels:
        app: kitchensink
    spec:
      containers:
        - name: kitchensink
          image: quay.io/CHANGEME/kitchensink:latest
          ports:
            - containerPort: 8080
              protocol: TCP
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
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9990
            initialDelaySeconds: 10
            periodSeconds: 5
```

**k8s/service.yaml**: Exposes the application within the cluster

**k8s/route.yaml**: Creates external URL for accessing the app

### 5. DevSpaces Configuration

**devfile.yaml**: Defines the development environment (see DevSpaces component README)

Key features:
- VS Code browser IDE
- JBoss EAP container with hot-reload
- Maven build tasks
- Debug configuration
- Persistent Maven cache

### 6. VS Code + odo Configuration

**.vscode/settings.json**: VS Code settings for Java development

**.vscode/launch.json**: Debug configurations

**.vscode/tasks.json**: Build and deploy tasks

**Instructions for local development**: See "Local Development with VS Code + odo" section below

## Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Web Browser                               │
│                                                              │
│  ┌────────────────────────────────────────────┐            │
│  │  index.xhtml (JSF)                         │            │
│  │  - Member registration form                │            │
│  │  - Member list display                     │            │
│  │  - Client-side validation                  │            │
│  └────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ HTTP POST/GET
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                JBoss EAP Server                              │
│                                                              │
│  ┌────────────────────────────────────────────┐            │
│  │  REST Layer (JAX-RS)                       │            │
│  │  /rest/members                             │            │
│  │  - GET    → List all members               │            │
│  │  - GET /:id → Get member by ID             │            │
│  │  - POST   → Register new member            │            │
│  └────────────────────────────────────────────┘            │
│                       │                                      │
│                       │ CDI Injection                       │
│                       ▼                                      │
│  ┌────────────────────────────────────────────┐            │
│  │  Service Layer                             │            │
│  │  MemberRegistration                        │            │
│  │  - register(Member)                        │            │
│  │  - Fires CDI events                        │            │
│  │  - Transaction management                  │            │
│  └────────────────────────────────────────────┘            │
│                       │                                      │
│                       │ CDI Injection                       │
│                       ▼                                      │
│  ┌────────────────────────────────────────────┐            │
│  │  Data Layer (Repository)                   │            │
│  │  MemberRepository                          │            │
│  │  - findAll()                               │            │
│  │  - findById(Long)                          │            │
│  │  - findByEmail(String)                     │            │
│  └────────────────────────────────────────────┘            │
│                       │                                      │
│                       │ JPA (Hibernate)                     │
│                       ▼                                      │
│  ┌────────────────────────────────────────────┐            │
│  │  H2 In-Memory Database                     │            │
│  │  MEMBERS table                             │            │
│  │  - id, name, email, phone_number           │            │
│  └────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Key Application Components

### 1. Member Entity (JPA)

```java
@Entity
@Table(name = "Member", uniqueConstraints = @UniqueConstraint(columnNames = "email"))
public class Member implements Serializable {
    
    @Id
    @GeneratedValue
    private Long id;

    @NotNull
    @Size(min = 1, max = 25)
    @Pattern(regexp = "[^0-9]*", message = "Must not contain numbers")
    private String name;

    @NotNull
    @NotEmpty
    @Email
    private String email;

    @NotNull
    @Size(min = 10, max = 12)
    @Digits(fraction = 0, integer = 12)
    @Column(name = "phone_number")
    private String phoneNumber;

    // Getters and setters...
}
```

**Demonstrates**:
- JPA entity mapping
- Bean Validation annotations (`@NotNull`, `@Email`, `@Pattern`)
- Unique constraints
- Custom validation messages

### 2. Member Repository (Data Access)

```java
@ApplicationScoped
public class MemberRepository {

    @Inject
    private EntityManager em;

    public Member findById(Long id) {
        return em.find(Member.class, id);
    }

    public Member findByEmail(String email) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Member> criteria = cb.createQuery(Member.class);
        Root<Member> member = criteria.from(Member.class);
        criteria.select(member).where(cb.equal(member.get("email"), email));
        return em.createQuery(criteria).getSingleResult();
    }

    public List<Member> findAllOrderedByName() {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Member> criteria = cb.createQuery(Member.class);
        Root<Member> member = criteria.from(Member.class);
        criteria.select(member).orderBy(cb.asc(member.get("name")));
        return em.createQuery(criteria).getResultList();
    }
}
```

**Demonstrates**:
- CDI application scoped bean
- EntityManager injection
- JPA Criteria API (type-safe queries)

### 3. Member Registration Service (Business Logic)

```java
@Stateless
public class MemberRegistration {

    @Inject
    private Logger log;

    @Inject
    private EntityManager em;

    @Inject
    private Event<Member> memberEventSrc;

    public void register(Member member) throws Exception {
        log.info("Registering " + member.getName());
        em.persist(member);
        memberEventSrc.fire(member);  // Fire CDI event
    }
}
```

**Demonstrates**:
- Stateless EJB (container-managed transactions)
- CDI dependency injection
- CDI events for loose coupling
- JBoss Logging

### 4. REST API (JAX-RS)

```java
@Path("/members")
@RequestScoped
public class MemberResourceRESTService {

    @Inject
    private MemberRepository repository;

    @Inject
    private MemberRegistration registration;

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Member> listAllMembers() {
        return repository.findAllOrderedByName();
    }

    @GET
    @Path("/{id:[0-9][0-9]*}")
    @Produces(MediaType.APPLICATION_JSON)
    public Member lookupMemberById(@PathParam("id") long id) {
        Member member = repository.findById(id);
        if (member == null) {
            throw new WebApplicationException(Response.Status.NOT_FOUND);
        }
        return member;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response createMember(Member member) {
        try {
            registration.register(member);
            return Response.ok(member).build();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_REQUEST)
                          .entity(e.getMessage()).build();
        }
    }
}
```

**Demonstrates**:
- JAX-RS resource paths
- Content negotiation (JSON)
- Path parameters with regex validation
- Proper HTTP status codes
- Exception handling

## Development Workflows

### Workflow 1: DevSpaces (Browser-Based)

**Target Audience**: No local setup required, consistent environments

**Steps**:
1. Open DevSpaces workspace URL
2. Start hot-reload: `mvn wildfly:run -Dwildfly.dev`
3. Edit `src/main/webapp/index.xhtml`
4. Save file
5. Refresh browser - see changes in 3-5 seconds

**Advantages**:
- Zero local setup
- Consistent environment across team
- Works from any device (even iPad)
- Automatic workspace save/restore

**Demo Impact**: Show 5-minute WebSphere reload vs 5-second DevSpaces reload

### Workflow 2: VS Code + odo (Local IDE)

**Target Audience**: Developers who prefer local IDE

**Setup**:
```bash
# Install odo CLI
curl -L https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/odo/latest/odo-darwin-amd64 -o odo
chmod +x odo
sudo mv odo /usr/local/bin/

# Clone repo
git clone https://github.com/YOUR_USERNAME/rh-jboss-demo
cd rh-jboss-demo/components/kitchensink

# Login to OpenShift
oc login

# Start odo sync
odo dev
```

**What odo does**:
- Creates temporary workspace in OpenShift
- Syncs local files to pod
- Runs JBoss with hot-reload
- Forwards port 8080 to localhost
- Watches for file changes and auto-syncs

**Steps**:
1. `odo dev` (starts sync mode)
2. Edit files in VS Code
3. Save - odo auto-syncs to cluster
4. Refresh http://localhost:8080
5. See changes in seconds

**Advantages**:
- Familiar IDE (VS Code)
- Full IDE features (IntelliSense, debugging)
- Develops against real cluster (not localhost)
- Fast inner-loop (comparable to DevSpaces)

**Demo Impact**: Show that local IDE can have same fast experience

### Workflow 3: CI/CD Pipeline (Production)

**Target Audience**: Production deployment workflow

**Steps**:
1. Make code change
2. Commit and push to Git
3. Tekton pipeline automatically triggers:
   - Clone code
   - Maven build
   - Container build
   - Push to Quay.io
   - Update deployment manifest
4. ArgoCD detects manifest change
5. Deploys new version to cluster

**Timeline**:
- Pipeline execution: 5-8 minutes
- ArgoCD sync: 3-5 minutes
- Total: ~10-13 minutes from push to production

**Demo Impact**: Show full automation - no manual steps

## Demo Script: Inner-Loop Focus

### Setup (Before Demo)

```bash
# Ensure workspace is running
DEVSPACES_URL=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')
echo "Open: https://${DEVSPACES_URL}/#https://github.com/YOUR_USERNAME/rh-jboss-demo"

# Verify app is accessible
KITCHENSINK_URL=$(oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}')
curl -I http://${KITCHENSINK_URL}
```

### Demo Flow (10 minutes)

**1. The Problem (2 minutes)**

*"Your team is migrating from WebSphere to JBoss. Your developers currently experience a 5-minute turnaround time for every code change in their Eclipse + WebSphere environment. Let me show you the modern alternative."*

**2. DevSpaces Hot-Reload Demo (5 minutes)**

1. **Open workspace** (already open before demo)
   - Show VS Code in browser
   - Show file tree with kitchensink source
   
2. **Start JBoss with hot-reload**:
   ```bash
   # In terminal pane
   mvn wildfly:run -Dwildfly.dev
   ```
   - Explain: "This starts JBoss in development mode with file watching enabled"
   - Wait ~30 seconds for server to start
   
3. **Open running app**:
   - Click the endpoint notification
   - Show the kitchensink UI
   - Register a test member
   
4. **Make a visible change**:
   - Open `src/main/webapp/index.xhtml`
   - Change line 32: `<h1>Welcome to JBoss!</h1>` → `<h1>Welcome to Modern JBoss!</h1>`
   - Save file (`Cmd+S`)
   - Show terminal output: "Reloading..."
   
5. **See the change**:
   - Refresh browser tab with app
   - **Point out the time**: "That took 3 seconds"
   - "Your old workflow: 5 minutes. This workflow: 3 seconds. That's a 100x improvement."

**3. Calculate Business Impact (2 minutes)**

*"Let's do the math:"*

```
Old workflow:
  50 code changes/day × 5 minutes = 250 minutes waiting (4+ hours)

New workflow:
  50 code changes/day × 5 seconds = 250 seconds (4 minutes)

Savings per developer: 4 hours/day
Savings per team (10 devs): 40 hours/day
Productivity gain: ~50% more coding time
```

**4. Transition to Outer Loop (1 minute)**

*"Now that we've solved the inner-loop problem, let me show you how this connects to your production pipeline..."*

→ Proceed to CI/CD demo (see demo docs)

## Testing the Application

### Manual Testing

```bash
# Access the UI
KITCHENSINK_URL=$(oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}')
open http://${KITCHENSINK_URL}

# Test REST API
# List all members
curl http://${KITCHENSINK_URL}/rest/members

# Register a new member
curl -X POST http://${KITCHENSINK_URL}/rest/members \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "phoneNumber": "5555551234"
  }'

# Get member by ID
curl http://${KITCHENSINK_URL}/rest/members/1
```

### Running Unit Tests

```bash
# In DevSpaces or locally
cd components/kitchensink
mvn test

# Run with coverage
mvn clean verify
```

### Running Integration Tests

```bash
# Requires Arquillian managed container
mvn clean verify -Parq-managed
```

## Customization

### Changing Database to PostgreSQL

Replace H2 with PostgreSQL for persistence:

**1. Update pom.xml**:
```xml
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <version>42.5.0</version>
</dependency>
```

**2. Update persistence.xml**:
```xml
<jta-data-source>java:jboss/datasources/KitchensinkDS</jta-data-source>
<properties>
    <property name="hibernate.dialect" value="org.hibernate.dialect.PostgreSQLDialect"/>
</properties>
```

**3. Add PostgreSQL to deployment**:
```yaml
# In k8s/postgresql.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
spec:
  template:
    spec:
      containers:
        - name: postgresql
          image: postgres:14
          env:
            - name: POSTGRES_DB
              value: kitchensink
            - name: POSTGRES_USER
              value: jboss
            - name: POSTGRES_PASSWORD
              value: jboss
```

## Troubleshooting

### Application Won't Start

**Symptom**: Deployment pod in CrashLoopBackOff

**Diagnosis**:
```bash
oc logs -n kitchensink-dev deployment/kitchensink
oc describe pod -n kitchensink-dev -l app=kitchensink
```

**Common Causes**:
- Image pull errors (check registry credentials)
- Insufficient resources (check resource limits)
- Database connection failures

### Hot-Reload Not Working

**Symptom**: Changes don't appear after saving files

**Diagnosis**:
- Ensure `mvn wildfly:run -Dwildfly.dev` is running (not `mvn wildfly:run`)
- Check terminal for "Reloading..." messages
- Verify file is actually saved (no asterisk in editor tab)

**Solution**:
- Restart Maven with `-Dwildfly.dev` flag
- For `pom.xml` changes, full restart required

### REST API Returns 404

**Symptom**: `/rest/members` endpoint not found

**Diagnosis**:
```bash
# Check deployment status
oc get deployment kitchensink -n kitchensink-dev

# Check logs
oc logs -n kitchensink-dev deployment/kitchensink
```

**Solution**:
- Ensure WAR is deployed correctly
- Check `JaxRsActivator.java` has `@ApplicationPath("/rest")`
- Verify route is created: `oc get route -n kitchensink-dev`

## Resources

- [JBoss EAP Documentation](https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/)
- [Original Kitchensink Quickstart](https://github.com/jboss-developer/jboss-eap-quickstarts/tree/7.4.x/kitchensink)
- [WildFly Maven Plugin](https://docs.wildfly.org/wildfly-maven-plugin/)
- [Jakarta EE Specifications](https://jakarta.ee/specifications/)
