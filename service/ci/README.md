# Import Generator Script

A utility script to generate import mappings from OpenAPI/Swagger specifications.

## Usage

```bash
./util.sh <swagger-file> <package-name> <mode>
```

### Arguments

- `swagger-file`: Path to your OpenAPI/Swagger specification file (JSON or YAML format)
- `package-name`: Base package name for the generated imports
- `mode`: Either 'import' or 'ignore' to generate different output formats

### Examples

```bash
./util.sh api.yaml my.package import
./util.sh swagger.json com.example.api ignore
```

### Output Formats

#### Import Mode
Generates schema mappings in the format: `SchemaName=package.name.SchemaName`

#### Ignore Mode
Generates file paths in the format: `src/package/name/SchemaName.java`

### Requirements

The script supports different parsing methods based on available tools:
- `jq` for JSON parsing (preferred)
- `yq` for YAML parsing (preferred)
- `python3` with yaml module as fallback for YAML
- Basic grep/sed parsing as final fallback