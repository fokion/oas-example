# OAS example

This repository demonstrates how to generate OpenAPI-based code in two related modules and reuse the generated "common" models inside a "service" project.

- common: Holds shared OpenAPI components/schemas and generates a reusable Java models JAR published to your local Maven repository.
- service: Generates a Spring Boot server that imports and uses the models from the common Maven artifact.

The entry point for code generation in both modules is the generate.sh script.

## Prerequisites
- Docker (used to run openapitools/openapi-generator-cli and optionally jq)
- Java (JDK 17 recommended; common builds with Java 11 target, service with Java 17)
- Maven 3+
- Node.js and npm (for Redocly CLI used to bundle/lint specs)

## Project layout
- common/
  - specs/openapi.json: OpenAPI spec for shared models
  - generate.sh: Generates Java code and installs the artifact to local Maven
  - package.json: Contains the version used for the artifact (version field)
  - ci/generator/config.json: OpenAPI Generator config (apiPackage, modelPackage, etc.)
- service/
  - specs/openapi.json: Service API spec that references common schemas
  - generate.sh: Generates Spring server code and depends on common models
  - ci/util.sh: Utility to build import-mappings and ignore lists from the common spec
  - ci/generator/pom.xml: Template POM used by generate.sh

## How it works
1) Generate and publish the common models JAR locally
- From the common directory:
  - ./generate.sh
  - This will:
    - Run OpenAPI Generator (Docker) against common/specs/openapi.json
    - Produce Java models under package xyz.fokion.common.models
    - Build target/common-models-<version>.jar and install it to your local Maven repository with coordinates:
      - groupId: xyz.fokion.common.models
      - artifactId: common-models
      - version: taken from common/package.json (e.g., 1.0.0)

2) Generate the service with dependency on common
- From the service directory:
  - ./generate.sh [SPRING_BOOT_VERSION]
    - SPRING_BOOT_VERSION is optional (defaults to 3.5.4)
  - This will:
    - Copy the common directory locally (for schema discovery/import-mapping)
    - Use util.sh to generate import mappings and ignore lists from common/specs/openapi.json
    - Run OpenAPI Generator (Docker) against service/specs/openapi.json using the mappings
    - Replace pom.xml from ci/generator/pom.xml and patch:
      - the version element from service/package.json
      - the spring-boot.version property from the script arg or default
      - the common-models.version property from common/package.json
    - Run mvn install

After generation, service/pom.xml contains the dependency on the local artifact (coordinates shown in plain text):
- groupId: xyz.fokion.common.models
- artifactId: common-models
- version: value of common-models.version (coming from common/package.json)

## Typical workflow
1. cd common && npm install && npm run build && ./generate.sh
2. cd service && npm install && npm run setup && npm run build && ./generate.sh
   - npm run setup copies ../common to service/common for the generator helper scripts.

## Working with the specs
- Bundling (creates generated/openapi.yaml):
  - cd common && npm run build
  - cd service && npm run build
- Linting (uses Redocly):
  - cd common && npm test
  - cd service && npm test
- HTML docs (Redocly):
  - cd common && npm run html
  - cd service && npm run html

## Notes and troubleshooting
- If jq is not installed locally, generate.sh will attempt to use Docker image ghcr.io/jqlang/jq.
- Ensure Docker daemon is running before executing the generate.sh scripts.
- The service/specs/openapi.json references schemas from common/specs/openapi.json; do not remove the copied common directory before running service/generate.sh.
- If Maven cannot find the common-models dependency, re-run common/generate.sh to reinstall the artifact to your local repository.


