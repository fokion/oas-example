
#!/bin/bash

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 <swagger-file> <package-name> <mode>"
    echo ""
    echo "Examples:"
    echo "  $0 api.yaml my.package ignore"
    echo "  $0 swagger.json com.example.api import"
    exit 1
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to parse JSON swagger file
parse_json_swagger() {
    local file="$1"

    if command_exists jq; then
        # Use jq if available
        {
            # Extract from components.schemas (OpenAPI 3.x)
            jq -r '.components.schemas // {} | keys[]' "$file" 2>/dev/null || true
            # Extract from definitions (Swagger 2.x)
            jq -r '.definitions // {} | keys[]' "$file" 2>/dev/null || true
        } | sort -u
    else
        # Fallback: use grep and sed for basic extraction
        echo "Warning: jq not found, using basic parsing (may be less accurate)" >&2
        {
            # Look for schema definitions in both formats
            grep -o '"[A-Z][a-zA-Z0-9]*"[[:space:]]*:' "$file" | sed 's/"//g' | sed 's/[[:space:]]*:.*$//' || true
        } | sort -u
    fi
}

# Function to parse YAML swagger file
parse_yaml_swagger() {
    local file="$1"

    if command_exists yq; then
        # Use yq if available
        {
            # Extract from components.schemas (OpenAPI 3.x)
            yq eval '.components.schemas // {} | keys | .[]' "$file" 2>/dev/null || true
            # Extract from definitions (Swagger 2.x)
            yq eval '.definitions // {} | keys | .[]' "$file" 2>/dev/null || true
        } | sort -u
    elif command_exists python3; then
        # Fallback: use Python with yaml module
        python3 -c "
import yaml
import sys

try:
    with open('$file', 'r') as f:
        doc = yaml.safe_load(f)

    schemas = set()

    # OpenAPI 3.x format
    if 'components' in doc and 'schemas' in doc['components']:
        schemas.update(doc['components']['schemas'].keys())

    # Swagger 2.x format
    if 'definitions' in doc:
        schemas.update(doc['definitions'].keys())

    for schema in sorted(schemas):
        print(schema)

except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
            echo "Error: Python3 with yaml module not available" >&2
            exit 1
        }
    else
        # Basic fallback using grep and awk
        echo "Warning: yq and python3 not found, using basic parsing (may be less accurate)" >&2
        {
            # Look for schema definitions (basic pattern matching)
            grep -E '^[[:space:]]*[A-Z][a-zA-Z0-9]*[[:space:]]*:' "$file" | \
            awk -F: '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}' || true
        } | sort -u
    fi
}

# Function to generate the output format
generate_output_for_import() {
    local output=()
    local package_name="$PACKAGE_NAME"

    while IFS= read -r schema_name; do
        if [[ -n "$schema_name" ]]; then
            output+=("${schema_name}=${package_name}.${schema_name}")
        fi
    done

    # Join array elements with commas
    local IFS=','
    echo "${output[*]}"
}
generate_output_for_ignoring() {
    local output=()
    local package_name="$PACKAGE_NAME"
    # Convert package name to directory path (replace . with /)
    local directory="${package_name//./\/}"

    while IFS= read -r schema_name; do
        if [[ -n "$schema_name" ]]; then
            output+=("src/${directory}/${schema_name}.java")
        fi
    done

    # Join array elements with commas
    local IFS=','
    echo "${output[*]}"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 3 ]]; then
        usage
    fi

    local swagger_file="$1"
    export PACKAGE_NAME="$2"
    export MODE="${3:-import}"  # Default to 'import' if not set

    # Check if file exists
    if [[ ! -f "$swagger_file" ]]; then
        echo "Error: File '$swagger_file' not found" >&2
        exit 1
    fi

    # Determine file type and parse accordingly
    case "$swagger_file" in
        *.json)
            schema_names=$(parse_json_swagger "$swagger_file")
            ;;
        *.yaml|*.yml)
            schema_names=$(parse_yaml_swagger "$swagger_file")
            ;;
        *)
            echo "Warning: Unknown file extension, attempting to detect format..." >&2
            # Try to detect format by content
            if head -1 "$swagger_file" | grep -q '^[[:space:]]*{'; then
                schema_names=$(parse_json_swagger "$swagger_file")
            else
                schema_names=$(parse_yaml_swagger "$swagger_file")
            fi
            ;;
    esac
    # Check for mode argument
    if [[ -z "${MODE:-}" ]]; then
        echo "Error: MODE variable not set" >&2
        exit 1
    fi

    # Generate output based on mode
    if [[ -n "$schema_names" ]]; then
        case "$MODE" in
            import)
                echo "$schema_names" | generate_output_for_import
                ;;
            ignore)
                echo "$schema_names" | generate_output_for_ignoring
                ;;
            *)
                echo "Error: Unknown mode '$MODE'. Use 'import' or 'ignore'." >&2
                exit 1
                ;;
        esac
    else
        echo "Warning: No schema definitions found in the swagger file" >&2
    fi
}

# Execute main function
main "$@"
