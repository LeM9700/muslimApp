#!/usr/bin/env bash
# Échoue si les adhkar intégrés n'ont pas été relus (texte religieux).
# Passer "reviewed": true dans assets/adhkar/adhkar_fr.json après relecture
# par une personne qualifiée (arabe, phonétique, traduction, références).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/assets/adhkar/adhkar_fr.json"
if python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("reviewed") is True else 1)' "$FILE"; then
  echo "✓ Adhkar relus"
else
  echo "✗ Adhkar non relus : $FILE (\"reviewed\": false)" >&2
  exit 1
fi
