# Scripts Directory

All helper scripts and related documentation for the Red Hat JBoss Modernization Demo.

## Quick Start

All scripts should be run from the **repository root**:

```bash
cd /path/to/rh-jboss-demo

# Setup
./scripts/setup-source-code.sh      # Download kitchensink source
./scripts/verify-setup.sh           # Verify everything is ready

# Configuration
./scripts/show-current-config.sh    # Check current config (CRC vs Production)
./scripts/optimize-for-crc.sh       # Optimize for OpenShift Local
./scripts/restore-production-defaults.sh  # Restore production settings

# Installation
cd bootstrap && ./install.sh        # Install the demo
```

## Directory Structure

```
scripts/
├── README.md                          # This file
├── setup-source-code.sh              # Downloads JBoss kitchensink source
├── verify-setup.sh                   # Validates setup before installation
├── optimize-for-crc.sh               # Reduces resources for CRC
├── restore-production-defaults.sh    # Restores production resources
├── show-current-config.sh            # Shows current configuration
├── CRC-SETUP.md                      # Complete CRC setup guide
├── ENVIRONMENT-CONFIGS.md            # Guide for managing configs
├── SCRIPTS-OVERVIEW.md               # Detailed script documentation
└── SETUP-CHECKLIST.md                # Installation checklist
```

## Setup Scripts

### setup-source-code.sh
**Downloads the official JBoss kitchensink quickstart**

```bash
./scripts/setup-source-code.sh
```

- Downloads JBoss EAP 7.4 kitchensink from GitHub
- Copies source to `components/kitchensink/src/`
- Configures `pom.xml` and `catalog-info.yaml`
- Creates Developer Hub template skeleton
- Auto-detects your GitHub username

### verify-setup.sh
**Validates the setup is complete**

```bash
./scripts/verify-setup.sh
```

Checks:
- ✓ Source code exists
- ✓ No CHANGEME placeholders
- ✓ GitHub repo configured
- ✓ Container registry configured
- ✓ catalog-info.yaml configured

Exit code 0 = ready to install

## Configuration Scripts

### show-current-config.sh
**Shows which configuration is active**

```bash
./scripts/show-current-config.sh
```

Output:
- Configuration type (CRC/Production/Custom)
- DevSpaces resource settings
- Kitchensink resource settings
- Instructions for switching

### optimize-for-crc.sh
**Reduces resources for OpenShift Local**

```bash
./scripts/optimize-for-crc.sh
git add -A && git commit -m "Optimize for CRC"
git push
```

Changes:
- DevSpaces: 3Gi → 2Gi memory
- Kitchensink: 512Mi → 256Mi request
- Max concurrent workspaces: 3 → 1
- Storage: 10Gi → 5Gi per workspace

### restore-production-defaults.sh
**Restores production resource settings**

```bash
./scripts/restore-production-defaults.sh
git add -A && git commit -m "Restore production defaults"
git push
```

Restores all CRC optimizations back to production values.

## Documentation

### CRC-SETUP.md
Complete guide for installing on OpenShift Local (CRC):
- CRC configuration requirements
- Resource optimization details
- Performance expectations
- CRC-specific troubleshooting

### ENVIRONMENT-CONFIGS.md
Guide for managing different environment configurations:
- Resource comparison tables
- Git branch strategy options
- Kustomize overlay approach
- Workflow examples

### SCRIPTS-OVERVIEW.md
Detailed documentation for all scripts:
- Complete usage examples
- Workflow walkthroughs
- Quick reference tables
- Troubleshooting tips

### SETUP-CHECKLIST.md
Printable checklist for installation:
- Pre-installation requirements
- Installation steps
- Post-installation configuration
- Verification tests

## Common Workflows

### First-Time Setup

```bash
# 1. Download source code
./scripts/setup-source-code.sh

# 2. Verify setup
./scripts/verify-setup.sh

# 3. Check current config
./scripts/show-current-config.sh

# 4. (Optional) Optimize for CRC
./scripts/optimize-for-crc.sh

# 5. Commit and push
git add -A && git commit -m "Complete setup" && git push

# 6. Install
cd bootstrap && ./install.sh
```

### Switch from CRC to Production

```bash
# 1. Check current config
./scripts/show-current-config.sh

# 2. Restore production defaults
./scripts/restore-production-defaults.sh

# 3. Verify change
./scripts/show-current-config.sh

# 4. Commit and push
git add -A && git commit -m "Switch to production" && git push

# 5. Install on production cluster
cd bootstrap && ./install.sh
```

### Quick Verification Before Demo

```bash
# Verify everything is configured
./scripts/verify-setup.sh

# Check which config is active
./scripts/show-current-config.sh

# Get installation status
cd bootstrap && ./install.sh --status

# Get access URLs
./install.sh --urls
```

## Important Notes

### Run from Repository Root
All scripts use relative paths from the repo root. Always run:

```bash
cd /path/to/rh-jboss-demo
./scripts/script-name.sh   # ✓ Correct
```

NOT:
```bash
cd /path/to/rh-jboss-demo/scripts
./script-name.sh   # ✗ Will not work correctly
```

### Commit After Configuration Changes
Scripts modify configuration files but don't auto-commit. Remember to commit and push after:
- Running `optimize-for-crc.sh`
- Running `restore-production-defaults.sh`
- Running `setup-source-code.sh`

### All Scripts Are Idempotent
Safe to run multiple times - they will overwrite with the same values.

## Getting Help

Each markdown file has detailed information:

- **New to the demo?** Start with [`../README.md`](../README.md)
- **Installing on CRC?** See [`CRC-SETUP.md`](CRC-SETUP.md)
- **Need step-by-step?** See [`../GETTING-STARTED.md`](../GETTING-STARTED.md)
- **Script details?** See [`SCRIPTS-OVERVIEW.md`](SCRIPTS-OVERVIEW.md)
- **Switching configs?** See [`ENVIRONMENT-CONFIGS.md`](ENVIRONMENT-CONFIGS.md)

## Quick Reference

| Task | Command |
|------|---------|
| Download source | `./scripts/setup-source-code.sh` |
| Verify setup | `./scripts/verify-setup.sh` |
| Check config | `./scripts/show-current-config.sh` |
| Optimize for CRC | `./scripts/optimize-for-crc.sh` |
| Restore production | `./scripts/restore-production-defaults.sh` |
| Install demo | `cd bootstrap && ./install.sh` |
| Check status | `cd bootstrap && ./install.sh --status` |
| Get URLs | `cd bootstrap && ./install.sh --urls` |

## Support

For issues or questions:
- Check the relevant markdown file in this directory
- See component-specific READMEs in `components/*/README.md`
- Review `docs/DEMO-SCRIPT.md` for demo walkthrough
