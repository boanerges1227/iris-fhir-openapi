"""Dev-time standalone spec validation; production runtime does not depend on Python."""
import argparse
import json
from pathlib import Path
from openapi_spec_validator import validate_spec


def main():
    # Pass the file to an independent implementation for validation, rather than repeating the generator's own rules.
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+')
    args = parser.parse_args()
    for name in args.files:
        document = json.loads(Path(name).read_text())
        validate_spec(document)
        print(f'OpenAPI valid: {name} ({len(document["paths"])} paths)')


if __name__ == '__main__':
    main()