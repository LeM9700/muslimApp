#!/usr/bin/env bash
# Échoue si les sons d'adhan sont encore les sons de substitution.
# À lancer en CI avant tout build de release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$ROOT/assets/audio/.placeholder" ]]; then
  echo "✗ Sons d'adhan de substitution : lancer scripts/adhan/prepare_adhan.sh" >&2
  exit 1
fi
echo "✓ Sons d'adhan réels"
