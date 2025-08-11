#!/usr/bin/env bash
set -o nounset
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT


cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}


if [ -d "src" ]; then
  rm -rf src
fi
rm pom.xml || true



success(){
    local msg=$1
    local GREEN='\033[0;32m'
    local NC='\033[0m'
    printf "${GREEN}${msg}${NC}\n"
}

check_docker_running() {
  # Method 1: Use docker command to ping the daemon
  if docker info &>/dev/null; then
    echo "Docker is running."
    return 0
  else
    echo "Docker is not running or not accessible."
    return 1
  fi
}

check_jq_which() {
  # Method 2: Use 'which' to find jq in PATH
  if which jq &>/dev/null; then
    echo "jq is installed at: $(which jq)"
    return $(which jq)
  else
    echo "jq is not found in PATH."
    return 1
  fi
}



# make sure the configuration has the up to date version from package.json
# Check for local jq installation
if which jq &>/dev/null; then
  success "Local jq installation found at $(which jq)"
  JQ_PATH="$(which jq)"
else
  warn "Local jq installation not found"

  # Check if Docker is running
  if check_docker_running; then
    success "Docker is running, will use jq Docker image"

    # Try to pull the jq image
    if docker pull ghcr.io/jqlang/jq:latest &>/dev/null; then
      success "Successfully pulled jq Docker image"
      JQ_PATH="docker run -i ghcr.io/jqlang/jq:latest"
    else
      die "Failed to pull jq Docker image"
    fi
  else
    warn "Neither local jq nor Docker is available"
    die "Please install jq or make sure Docker is running"
  fi
fi

# Export JQ_PATH for use in the current shell
export JQ_PATH
VERSION=$($JQ_PATH  -r '.version' package.json)
$JQ_PATH  --arg version "$VERSION" '.artifactVersion = $version' ci/generator/config.json > tmp.json \
&& mv tmp.json ci/generator/config.json
# Set the package name from the config file
if [ ! -f ci/generator/config.json ]; then
  die "ci/generator/config.json not found, please run this script from the project root directory"
fi
PACKAGE_NAME=$($JQ_PATH  -r '.modelPackage' ci/generator/config.json)



docker run --rm \
  --user $(id -u):$(id -g) \
  -v ${PWD}:/local openapitools/openapi-generator-cli generate \
  -i /local/specs/openapi.json \
  -g java \
  --library native \
  -c /local/ci/generator/config.json \
  --openapi-generator-ignore-list "README.md,docs/*.md,src/main/java/org/openapitools/*,gradle*,*.gradle,git_push.sh,build.sbt,.travis.yml,.github,api,.gitignore" \
  -o /local

#Cleanup couple of files
rm -rf .openapi-generator
rm -rf src/main/java/org
rm -rf gradle
rm -rf .github
rm -rf api
rm -rf src/test
rm src/main/AndroidManifest.xml

mvn install:install-file \
   -Dfile="target/common-models-${VERSION}.jar" \
   -DgroupId="xyz.fokion.common.models" \
   -DartifactId="common-models"\
   -Dversion="${VERSION}" \
   -Dpackaging="jar" \
   -DgeneratePom=true
