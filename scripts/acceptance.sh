#!/usr/bin/env bash
set -exuo pipefail

HELM_REPO="https://github.com/helm/helm.git"
CHARTMUSEUM_REPO="https://github.com/helm/chartmuseum.git"
#ZOT_REPO="https://github.com/anuvu/zot.git"
DISTRIBUTION_REPO="https://github.com/anuvu/zot.git"
HELM_VERSION="v3.2.3"
CHARTMUSEUM_VERSION="v0.12.0"
#ZOT_VERSION="v1.1.0"
DISTRIBUTION_VERSION="v2.7.1"
PY_REQUIRES="robotframework==3.2.1"

export HELM_OCI_MIRROR_PLUGIN_NO_INSTALL_HOOK=1
export CHARTMUSEUM_PORT="${CHARTMUSEUM_PORT:-8080}"
#export ZOT_PORT="${ZOT_PORT:-5000}"
export DISTRIBUTION_PORT="${DISTRIBUTION_PORT:-5000}"
export CHART_NAME_A="${CHART_NAME_A:-mychart}"
export CHART_NAME_B="${CHART_NAME_B:-otherchart}"

function setup() {
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd "${DIR}/../"
  export PATH="${PWD}/bin:${PWD}/testdata/bin:${PATH}"
  mkdir -p testdata/{bin,clones,storage,xdg}/
  export HELM_EXPERIMENTAL_OCI=1 # Enable Helm OCI support
  export XDG_CACHE_HOME="${PWD}/testdata/xdg/cache"
  export XDG_CONFIG_HOME="${PWD}/testdata/xdg/config"
  export XDG_DATA_HOME="${PWD}/testdata/xdg/data"
}

function teardown() {
  docker logs local-chartmuseum >& .robot/chartmuseum.log
  #docker logs local-zot >& .robot/zot.log
  #docker rm -f local-chartmuseum local-zot
  docker logs local-distribution >& .robot/distribution.log
  docker rm -f local-chartmuseum local-distribution
}

function install_dependencies() {
  install_helm
  install_chartmuseum
  #install_zot
  install_distribution
}

function start_services() {
  start_chartmuseum
  #start_zot
  start_distribution
}

function install_helm() {
  if ! [[ -f testdata/bin/helm ]]; then
    if ! [[ -d testdata/clones/helm/ ]]; then
      git clone --depth 1 "${HELM_REPO}" \
        --single-branch --branch "${HELM_VERSION}" \
        testdata/clones/helm
    fi
    USE_SUDO="false" \
      DESIRED_VERSION="${HELM_VERSION}" \
      HELM_INSTALL_DIR="${PWD}/testdata/bin" \
      testdata/clones/helm/scripts/get-helm-3
  fi
}

function install_chartmuseum() {
  if ! docker images | grep "local-chartmuseum.*${CHARTMUSEUM_VERSION}"; then
    if ! [[ -d testdata/clones/chartmuseum/ ]]; then
      git clone --depth 1 "${CHARTMUSEUM_REPO}" \
        --single-branch --branch "${CHARTMUSEUM_VERSION}" \
        testdata/clones/chartmuseum
    fi
    pushd testdata/clones/chartmuseum/
    make build-linux
    docker build . -t "local-chartmuseum:${CHARTMUSEUM_VERSION}"
    popd
  fi
}

#function install_zot() {
#  if ! docker images | grep "local-zot.*${ZOT_VERSION}"; then
#    if ! [[ -d testdata/clones/zot/ ]]; then
#      git clone --depth 1 "${ZOT_REPO}" \
#        --single-branch --branch "${ZOT_VERSION}" \
#        testdata/clones/zot
#    fi
#    pushd testdata/clones/zot/
#    docker build . -t "local-zot:${ZOT_VERSION}"
#    popd
#  fi
#}

function install_distribution() {
  if ! docker images | grep "local-distribution.*${DISTRIBUTION_VERSION}"; then
    if ! [[ -d testdata/clones/distribution/ ]]; then
      git clone --depth 1 "https://github.com/docker/distribution.git" \
        --single-branch --branch "${DISTRIBUTION_VERSION}" \
        testdata/clones/distribution
    fi
    pushd testdata/clones/distribution/
    docker build . -t "local-distribution:${DISTRIBUTION_VERSION}"
    popd
  fi
}

function start_chartmuseum() {
  populate_chartmuseum
  docker rm -f local-chartmuseum || true
  docker run --name local-chartmuseum -d -p ${CHARTMUSEUM_PORT}:${CHARTMUSEUM_PORT} \
    -v "${PWD}/testdata/storage/chartmuseum":/charts \
    "local-chartmuseum:${CHARTMUSEUM_VERSION}" \
    --debug --port "${CHARTMUSEUM_PORT}" \
    --storage local --storage-local-rootdir /charts &
  while ! nc -zw1 localhost "${CHARTMUSEUM_PORT}"; do
    sleep 1
  done
}

function populate_chartmuseum() {
  rm -rf testdata/storage/chartmuseum/
  mkdir -p testdata/storage/chartmuseum/
  pushd testdata/storage/chartmuseum/
  helm create "${CHART_NAME_A}" && helm package "${CHART_NAME_A}" && rm -rf "${CHART_NAME_A}/"
  helm create "${CHART_NAME_B}" && helm package "${CHART_NAME_B}" && rm -rf "${CHART_NAME_B}/"
  popd
}

#function start_zot() {
#  populate_zot
#  docker rm -f local-zot || true
#  docker run --name local-zot -d -p ${ZOT_PORT}:${ZOT_PORT} \
#    -v "${PWD}/testdata/storage/zot":/var/lib/registry \
#    "local-zot:${ZOT_VERSION}"
#  while ! nc -zw1 localhost "${ZOT_PORT}"; do
#    sleep 1
#  done
#}
#
#function populate_zot() {
#  rm -rf testdata/storage/zot/
#  mkdir -p testdata/storage/zot/
#}

function start_distribution() {
  populate_distribution
  docker rm -f local-distribution || true
  docker run --name local-distribution -d -p ${DISTRIBUTION_PORT}:${DISTRIBUTION_PORT} \
    -v "${PWD}/testdata/storage/distribution":/var/lib/registry \
    "local-distribution:${DISTRIBUTION_VERSION}"
  while ! nc -zw1 localhost "${DISTRIBUTION_PORT}"; do
    sleep 1
  done
}

function populate_distribution() {
  rm -rf testdata/storage/distribution/
  mkdir -p testdata/storage/distribution/
}

function run_acceptance_tests() {
  rm -rf .robot/
  mkdir -p .robot/
  setup_virtualenv
  .venv/bin/robot --outputdir=.robot/ acceptance_tests/
}

function setup_virtualenv() {
  if ! [[ -d .venv/ ]]; then
    virtualenv -p "$(which python3)" .venv/
    .venv/bin/python .venv/bin/pip install "${PY_REQUIRES}"
  fi
}

function main() {
  setup
  install_dependencies
  start_services
  trap teardown EXIT
  run_acceptance_tests
}

main
