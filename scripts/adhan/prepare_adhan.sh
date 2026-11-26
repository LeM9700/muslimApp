#!/usr/bin/env bash
# Prépare tous les fichiers audio de l'adhan à partir d'un enregistrement.
#
# Usage :
#   scripts/adhan/prepare_adhan.sh \
#     --source adhan.mp3 \
#     --short 0:00.5-0:09.2 \      # « Allahu akbar, Allahu akbar »
#     --long-start 0:00.5 \        # début de l'extrait de 30 s
#     [--fajr adhan_fajr.mp3]      # adhan du Fajr (facultatif)
#     [--test]                     # audio NON publiable (ex. sans licence) :
#                                  # marque les sons comme « test » et bloque
#                                  # tout build de release (check_release_audio.sh)
#
# Produit :
#   android/app/src/main/res/raw/adhan_{short,long}.ogg   (notification Android)
#   assets/audio/notification/adhan_{short,long}.caf      (notification iOS)
#   assets/audio/adhan_{short,long}.mp3                   (aperçu dans l'app)
#   assets/audio/adhan_full.mp3 [+ adhan_fajr_full.mp3]   (lecteur intégral)
#
# [⚠️ PROD] Après avoir remplacé les sons :
#   - incrémenter IosSoundInstaller.soundsVersion (sinon iOS garde l'ancien) ;
#   - passer les canaux Android en _v2 dans AdhanSoundResolver (le son d'un
#     canal existant ne change jamais).
set -euo pipefail

SOURCE="" SHORT="" LONG_START="" FAJR="" TEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --short) SHORT="$2"; shift 2 ;;
    --long-start) LONG_START="$2"; shift 2 ;;
    --fajr) FAJR="$2"; shift 2 ;;
    --test) TEST=1; shift ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done
[[ -f "$SOURCE" && -n "$SHORT" && -n "$LONG_START" ]] || {
  sed -n '2,15p' "$0"; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg requis" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RAW="$ROOT/android/app/src/main/res/raw"
NOTIF="$ROOT/assets/audio/notification"
AUDIO="$ROOT/assets/audio"
mkdir -p "$RAW" "$NOTIF" "$AUDIO"

SHORT_START="${SHORT%-*}"
SHORT_END="${SHORT#*-}"
# iOS refuse (silencieusement) un son de 30 s ou plus : marge de sécurité.
LONG_DURATION=29.5

# Normalisation EBU R128 (-16 LUFS, niveau courant des podcasts/notifications)
# + mono : un adhan n'a pas besoin de stéréo, et le fichier pèse 2× moins.
NORM="loudnorm=I=-16:TP=-1.5:LRA=11"
FFMPEG=(ffmpeg -hide_banner -loglevel error -y)

render() { # $1=source $2=filtre $3=ss $4=to|"" $5..=sortie+options
  local src="$1" filter="$2" ss="$3" to="$4"; shift 4
  local range=(-ss "$ss"); [[ -n "$to" ]] && range+=(-to "$to")
  "${FFMPEG[@]}" "${range[@]}" -i "$src" -af "$filter" -ac 1 "$@"
}

LONG_END_FILTER="afade=t=in:d=0.05,afade=t=out:st=$(echo "$LONG_DURATION - 2" | bc):d=2,$NORM"
SHORT_FILTER="afade=t=in:d=0.05,areverse,afade=t=in:d=0.4,areverse,$NORM"

echo "→ Extrait court ($SHORT_START → $SHORT_END)"
render "$SOURCE" "$SHORT_FILTER" "$SHORT_START" "$SHORT_END" \
  -ar 44100 -c:a libvorbis -q:a 4 "$RAW/adhan_short.ogg"
render "$SOURCE" "$SHORT_FILTER" "$SHORT_START" "$SHORT_END" \
  -ar 22050 -c:a adpcm_ima_qt -f caf "$NOTIF/adhan_short.caf"
render "$SOURCE" "$SHORT_FILTER" "$SHORT_START" "$SHORT_END" \
  -ar 44100 -c:a libmp3lame -b:a 96k "$AUDIO/adhan_short.mp3"

echo "→ Extrait de ${LONG_DURATION} s (à partir de $LONG_START)"
render "$SOURCE" "atrim=duration=$LONG_DURATION,$LONG_END_FILTER" "$LONG_START" "" \
  -ar 44100 -c:a libvorbis -q:a 4 "$RAW/adhan_long.ogg"
render "$SOURCE" "atrim=duration=$LONG_DURATION,$LONG_END_FILTER" "$LONG_START" "" \
  -ar 22050 -c:a adpcm_ima_qt -f caf "$NOTIF/adhan_long.caf"
render "$SOURCE" "atrim=duration=$LONG_DURATION,$LONG_END_FILTER" "$LONG_START" "" \
  -ar 44100 -c:a libmp3lame -b:a 96k "$AUDIO/adhan_long.mp3"

echo "→ Adhan intégral"
render "$SOURCE" "$NORM" 0 "" -ar 44100 -c:a libmp3lame -b:a 96k "$AUDIO/adhan_full.mp3"
if [[ -n "$FAJR" ]]; then
  render "$FAJR" "$NORM" 0 "" -ar 44100 -c:a libmp3lame -b:a 96k "$AUDIO/adhan_fajr_full.mp3"
fi

rm -f "$AUDIO/.placeholder" "$AUDIO/.test_audio"
if [[ "$TEST" == 1 ]]; then
  # Marqueur versionnable : s'il est commité par erreur, les builds de
  # release échouent au lieu de publier un audio sans licence.
  echo "Audio de test, non publiable : $(basename "$SOURCE")" > "$AUDIO/.test_audio"
  echo "⚠️  Sons marqués comme TEST (assets/audio/.test_audio) : ne pas publier."
fi

echo "→ Vérification des durées"
for f in "$NOTIF"/*.caf; do
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  if (( $(echo "$d >= 30" | bc) )); then
    echo "✗ $f dure ${d}s (iOS exige < 30 s)" >&2; exit 1
  fi
  echo "  ✓ $(basename "$f") : ${d}s"
done
du -ch "$RAW"/adhan_* "$NOTIF"/*.caf "$AUDIO"/*.mp3 | tail -1 | sed 's/^/  Poids total : /'
