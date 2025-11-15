#!/bin/bash

# Test script to verify skip flags work correctly

echo "Testing skip flags..."
echo

# Test with all skipped except docker
echo "=== Test 1: Only Docker should run ==="
skip_brew=1 \
skip_mas=1 \
skip_xcode_select=1 \
skip_softwareupdate=1 \
skip_disk_maintenance=1 \
skip_system_maintenance=1 \
skip_spotlight=1 \
skip_launchpad=1 \
skip_self_update=1 \
skip_code=1 \
skip_kav=1 \
skip_omz=1 \
skip_apm=1 \
skip_npm=1 \
skip_yarn=1 \
skip_nvm=1 \
skip_pip=1 \
skip_pip3=1 \
skip_pipenv=1 \
skip_rustup=1 \
skip_cargo=1 \
skip_pnpm=1 \
skip_deno=1 \
skip_composer=1 \
skip_asdf=1 \
skip_pyenv=1 \
skip_rbenv=1 \
skip_sdk=1 \
skip_tfenv=1 \
skip_flutter=1 \
skip_conda=1 \
skip_mamba=1 \
skip_helm=1 \
skip_go=1 \
skip_poetry=1 \
skip_pdm=1 \
skip_uv=1 \
skip_gh=1 \
skip_gcloud=1 \
skip_aws=1 \
skip_az=1 \
skip_kubectl=1 \
skip_port=1 \
skip_nix_env=1 \
skip_mise=1 \
skip_antibody=1 \
skip_fisher=1 \
skip_starship=1 \
skip_jenv=1 \
skip_goenv=1 \
skip_nodenv=1 \
skip_rvm=1 \
skip_gem=1 \
skip_pod=1 \
bash -c 'source ./htotheizzo.sh 2>&1' | grep -E "Skipped|Cleaning up Docker|disk maintenance|Software Update|Command Line Tools|htotheizzo itself" | head -60

echo
echo "Expected output: All 'Skipped' messages except Docker cleanup should appear"
