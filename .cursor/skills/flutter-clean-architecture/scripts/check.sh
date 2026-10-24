#!/usr/bin/env bash
# flutter analyze + flutter test del frontend; con --vs-main compara los avisos con main.
# Usa flutter local si existe; si no, la imagen Docker cirruslabs (y devuelve la propiedad de los ficheros).
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
IMAGE="ghcr.io/cirruslabs/flutter:stable"
VS_MAIN=0
[[ "${1:-}" == "--vs-main" ]] && VS_MAIN=1

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

echo "== analyze + test (rama actual)"
run_flutter "$ROOT/frontend" "flutter pub get >/dev/null && $SUMMARY > .analyze.txt; flutter test" \
  && TEST_OK=1 || TEST_OK=0
mv "$ROOT/frontend/.analyze.txt" "$TMP/branch.txt"
cat "$TMP/branch.txt"

NEW_WARNINGS=0
if [[ $VS_MAIN -eq 1 ]]; then
  echo "== analyze en main"
  WT="$TMP/main-wt"
  git -C "$ROOT" worktree add -q --detach "$WT" main
  run_flutter "$WT/frontend" "flutter pub get >/dev/null && $SUMMARY > .analyze.txt" || true
  cp "$WT/frontend/.analyze.txt" "$TMP/main.txt"
  git -C "$ROOT" worktree remove --force "$WT"
  # Avisos cuyo recuento sube respecto a main.
  NEW="$(awk 'NR==FNR{c=$1;$1="";m[$0]=c;next}{c=$1;$1="";if(c>m[$0]+0)print c-m[$0]" nuevo(s):"$0}' \
    "$TMP/main.txt" "$TMP/branch.txt")"
  if [[ -n "$NEW" ]]; then
    echo "== Avisos nuevos respecto a main"; echo "$NEW"; NEW_WARNINGS=1
  else
    echo "== Sin avisos nuevos respecto a main"
  fi
fi

[[ $TEST_OK -eq 1 ]] && echo "== Tests: OK" || echo "== Tests: FALLAN"
[[ $TEST_OK -eq 1 && $NEW_WARNINGS -eq 0 ]]
