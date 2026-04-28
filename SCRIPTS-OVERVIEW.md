# Scripts Overview

Quick reference for all helper scripts in this repository.

## Setup Scripts

### `./setup-source-code.sh`
**Purpose**: Downloads JBoss kitchensink source code and creates template skeleton

**When to use**: First time setup, or if you need to re-download source

**What it does**:
- Downloads official JBoss EAP 7.4 kitchensink from GitHub
- Copies source to `components/kitchensink/src/`
- Copies and configures `pom.xml`
- Creates Developer Hub template skeleton
- Auto-detects your GitHub username and creates `catalog-info.yaml`

**Example**:
```bash
./setup-source-code.sh
```

---

### `./verify-setup.sh`
**Purpose**: Validates that all setup is complete and correct

**When to use**: Before installation, after making changes

**What it checks**:
- ✓ Source code exists
- ✓ No CHANGEME placeholders
- ✓ GitHub repo configured
- ✓ Container registry configured
- ✓ catalog-info.yaml configured
- ✓ Git status

**Example**:
```bash
./verify-setup.sh
```

**Output**:
- Exit code 0 = Ready to install
- Exit code >0 = Issues found, fix before installing

---

## Environment Configuration Scripts

### `./optimize-for-crc.sh`
**Purpose**: Reduces resource requirements for OpenShift Local (CRC)

**When to use**: Before installing on CRC

**What it changes**:
- DevSpaces: 3Gi → 2Gi memory, max 1 concurrent workspace
- Kitchensink: 512Mi → 256Mi request, 1Gi → 768Mi limit
- Devfile: Reduced memory across all containers
- Storage: 10Gi → 5Gi per workspace
- Disables metrics to save resources

**Example**:
```bash
./optimize-for-crc.sh
git add -A && git commit -m "Optimize for CRC"
git push
```

---

### `./restore-production-defaults.sh`
**Purpose**: Restores production resource settings

**When to use**: After CRC testing, before installing on production cluster

**What it changes**:
- Reverts all CRC optimizations
- Restores full resource requests/limits
- Re-enables metrics
- Restores production storage sizes

**Example**:
```bash
./restore-production-defaults.sh
git add -A && git commit -m "Restore production defaults"
git push
```

---

### `./show-current-config.sh`
**Purpose**: Shows which configuration is currently active

**When to use**: To check which settings are active (CRC vs Production)

**What it shows**:
- Current configuration type (CRC/Production/Custom)
- DevSpaces resource settings
- Kitchensink resource settings
- Instructions for switching

**Example**:
```bash
./show-current-config.sh
```

**Output**:
```
========================================
Current Configuration
========================================

Configuration: CRC

DevSpaces Settings:
  Tools Memory:        2Gi
  Max Workspaces:      3
  Concurrent Running:  1
  PVC Size:            5Gi

Kitchensink Settings:
  Memory Request:      256Mi
  Memory Limit:        768Mi

========================================
Optimized for OpenShift Local (CRC)

To switch to production:
  ./restore-production-defaults.sh
========================================
```

---

## Installation Scripts

### `./bootstrap/install.sh`
**Purpose**: One-click installer for entire demo

**When to use**: After setup is complete and verified

**What it does**:
- Validates prerequisites
- Installs OpenShift GitOps operator
- Deploys app-of-apps
- Monitors installation progress

**Options**:
```bash
./install.sh              # Install everything
./install.sh --status     # Check installation status
./install.sh --urls       # Display access URLs
./install.sh --uninstall  # Remove all components
./install.sh --help       # Show help
```

**Example**:
```bash
cd bootstrap
./install.sh

# In another terminal, monitor:
watch -n 5 './install.sh --status'

# Once complete:
./install.sh --urls
```

---

## Complete Workflows

### First-Time Setup

```bash
# 1. Setup source code
./setup-source-code.sh

# 2. Verify everything is ready
./verify-setup.sh

# 3. Check current config
./show-current-config.sh

# 4. If using CRC, optimize
./optimize-for-crc.sh

# 5. Commit and push
git add -A
git commit -m "Complete setup for CRC"
git push

# 6. Install
cd bootstrap
./install.sh
```

### Switching from CRC to Production

```bash
# 1. Check current config
./show-current-config.sh
# Shows: CRC

# 2. Restore production defaults
./restore-production-defaults.sh

# 3. Verify change
./show-current-config.sh
# Shows: PRODUCTION

# 4. Commit and push
git add -A
git commit -m "Switch to production config"
git push

# 5. Uninstall from CRC (optional)
cd bootstrap
./install.sh --uninstall

# 6. Install on production cluster
# (login to production cluster)
oc login https://api.production-cluster.com:6443
cd bootstrap
./install.sh
```

### Testing Both Environments

```bash
# 1. Create CRC branch
git checkout -b crc
./optimize-for-crc.sh
git add -A && git commit -m "CRC config"
git push -u origin crc

# 2. Switch to main for production
git checkout main
./restore-production-defaults.sh
git add -A && git commit -m "Production config"
git push

# 3. Install on CRC
git checkout crc
# Update argocd/app-of-apps.yaml targetRevision to 'crc'
cd bootstrap && ./install.sh

# 4. Install on Production (different cluster)
git checkout main
# Update argocd/app-of-apps.yaml targetRevision to 'main'
cd bootstrap && ./install.sh
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Download source code | `./setup-source-code.sh` |
| Verify setup | `./verify-setup.sh` |
| Check current config | `./show-current-config.sh` |
| Optimize for CRC | `./optimize-for-crc.sh` |
| Restore production | `./restore-production-defaults.sh` |
| Install demo | `cd bootstrap && ./install.sh` |
| Check install status | `cd bootstrap && ./install.sh --status` |
| Get URLs | `cd bootstrap && ./install.sh --urls` |
| Uninstall | `cd bootstrap && ./install.sh --uninstall` |

---

## Script Execution Order (Recommended)

```
1. ./setup-source-code.sh         ← Downloads source
2. ./verify-setup.sh              ← Checks everything
3. ./show-current-config.sh       ← See current settings
4. ./optimize-for-crc.sh          ← (If using CRC)
   OR
   ./restore-production-defaults.sh  ← (If using production)
5. git add/commit/push            ← Save changes
6. cd bootstrap && ./install.sh   ← Install demo
```

---

## Safe to Run Multiple Times?

| Script | Idempotent? | Notes |
|--------|-------------|-------|
| `setup-source-code.sh` | ✅ Yes | Backs up existing files |
| `verify-setup.sh` | ✅ Yes | Read-only check |
| `optimize-for-crc.sh` | ✅ Yes | Overwrites files |
| `restore-production-defaults.sh` | ✅ Yes | Overwrites files |
| `show-current-config.sh` | ✅ Yes | Read-only display |
| `bootstrap/install.sh` | ⚠️ Mostly | Skips if already installed |

**All scripts are safe to run multiple times.**

---

## Getting Help

Each script has built-in help:

```bash
./setup-source-code.sh --help      # Not implemented yet
./bootstrap/install.sh --help      # Shows all options
```

For questions:
- Check the relevant README in each component directory
- See `GETTING-STARTED.md` for installation guide
- See `CRC-SETUP.md` for CRC-specific help
- See `ENVIRONMENT-CONFIGS.md` for configuration details

---

## Tips

1. **Always run `verify-setup.sh` before installing** - catches common issues
2. **Use `show-current-config.sh` before committing** - know what you're pushing
3. **Run optimization scripts before committing** - don't mix configs
4. **Keep a backup branch** - `git checkout -b backup` before major changes
5. **Check git status after scripts** - scripts don't auto-commit

---

## Troubleshooting

### Script won't execute
```bash
chmod +x ./*.sh
chmod +x bootstrap/*.sh
```

### Wrong configuration active
```bash
./show-current-config.sh
# Then run the appropriate script to fix
```

### Uncommitted changes warning
```bash
git status
git add -A
git commit -m "Description of changes"
git push
```

### Script errors out
Most scripts have detailed error messages. Look for:
- Missing prerequisites (git, oc, etc.)
- File permissions
- Network issues (downloading source)

---

Happy scripting! 🚀
