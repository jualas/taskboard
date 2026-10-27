#!/usr/bin/env bash
# flutter analyze + flutter test del frontend (lo usan los agentes, las personas y el CI).
#   --vs-main     compara los avisos con origin/main recién descargado (o main si no hay remoto)
#   --base <ref>  compara con otra referencia (p. ej. origin/<rama base> de un PR)
#   --strict      falla con cualquier aviso de analyze (como el CI, que ya no admite ninguno)
#   --no-test     no ejecuta flutter test (el CI ya lo lanza con cobertura)
# Falla si fallan los tests, si hay avisos de analyze nuevos respecto a la base o, con --strict, si hay alguno.
# Usa flutter local si existe; si no, la imagen Docker cirruslabs (y devuelve la propiedad de los ficheros).
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
IMAGE="ghcr.io/cirruslabs/flutter:stable"
BASE=""
RUN_TESTS=1
STRICT=0
usage() { echo "uso: $0 [--vs-main | --base <ref>] [--strict] [--no-test]" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vs-main)
      if git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
        git -C "$ROOT" fetch -q origin main
        BASE="origin/main"
      else
        BASE="main"
      fi ;;
    --base) [[ $# -ge 2 ]] || usage; BASE="$2"; shift ;;
    --strict) STRICT=1 ;;
    --no-test) RUN_TESTS=0 ;;
    *) usage ;;
  esac
  shift
done

run_flutter() { # $1 = directorio frontend, $2 = comandos
  if command -v flutter >/dev/null 2>&1; then
    (cd "$1" && bash -c "$2")
  else
    docker run --rm -v "$1":/app -w /app "$IMAGE" \
      bash -c "$2; rc=\$?; chown -R $(id -u):$(id -g) /app; exit \$rc"
  fi
}

# Resumen de avisos sin ruta ni línea, para comparar ramas.
SUMMARY='flutter analyze 2>&1 | grep "•" | sed -E "s/ • [^•]*:[0-9]+:[0-9]+ •/ •/" | sort | uniq -c'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CMDS="flutter pub get >/dev/null && $SUMMARY > .analyze.txt"
[[ $RUN_TESTS -eq 1 ]] && CMDS="$CMDS; flutter test"

echo "== analyze$([[ $RUN_TESTS -eq 1 ]] && echo ' + test') (rama actual)"
run_flutter "$ROOT/frontend" "$CMDS" && TEST_OK=1 || TEST_OK=0
mv "$ROOT/frontend/.analyze.txt" "$TMP/branch.txt"
cat "$TMP/branch.txt"

NEW_WARNINGS=0
if [[ $STRICT -eq 1 && -s "$TMP/branch.txt" ]]; then
  echo "== --strict: analyze tiene avisos"; NEW_WARNINGS=1
fi
if [[ -n "$BASE" ]]; then
  echo "== analyze en $BASE"
  WT="$TMP/base-wt"
  git -C "$ROOT" worktree add -q --detach "$WT" "$BASE"
  run_flutter "$WT/frontend" "flutter pub get >/dev/null && $SUMMARY > .analyze.txt" || true
  cp "$WT/frontend/.analyze.txt" "$TMP/base.txt"
  git -C "$ROOT" worktree remove --force "$WT"
  # Avisos cuyo recuento sube respecto a la base.
  NEW="$(awk 'NR==FNR{c=$1;$1="";m[$0]=c;next}{c=$1;$1="";if(c>m[$0]+0)print c-m[$0]" nuevo(s):"$0}' \
    "$TMP/base.txt" "$TMP/branch.txt")"
  if [[ -n "$NEW" ]]; then
    echo "== Avisos nuevos respecto a $BASE"; echo "$NEW"; NEW_WARNINGS=1
  else
    echo "== Sin avisos nuevos respecto a $BASE"
  fi
fi

if [[ $RUN_TESTS -eq 1 ]]; then
  [[ $TEST_OK -eq 1 ]] && echo "== Tests: OK" || echo "== Tests: FALLAN"
fi
[[ $TEST_OK -eq 1 && $NEW_WARNINGS -eq 0 ]]
