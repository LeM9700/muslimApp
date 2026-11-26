#!/usr/bin/env bash
# Échoue si les sons d'adhan ne sont pas publiables :
#   - assets/audio/.placeholder : tonalités de substitution ;
#   - assets/audio/.test_audio  : audio de test (sans licence pour la prod).
# Lancé par le CI avant tout build destiné au store (tag v*).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
status=0
if [[ -f "$ROOT/assets/audio/.placeholder" ]]; then
  echo "✗ Sons d'adhan de substitution : lancer scripts/adhan/prepare_adhan.sh" >&2
  status=1
fi
if [[ -f "$ROOT/assets/audio/.test_audio" ]]; then
  echo "✗ Sons d'adhan de TEST ($(cat "$ROOT/assets/audio/.test_audio"))" >&2
  status=1
fi
[[ $status == 0 ]] && echo "✓ Sons d'adhan publiables"
exit $status
