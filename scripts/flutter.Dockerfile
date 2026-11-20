# Flutter fijado para comprobar y compilar el frontend en local (scripts/flutter-check.sh).
# La imagen de cirruslabs va por detrás de las versiones estables, así que se parte de ella
# y se mueve el SDK a la etiqueta oficial de github.com/flutter/flutter.
# Subir FLUTTER_VERSION a la vez que flutter-version en .github/workflows/tests.yml.
FROM ghcr.io/cirruslabs/flutter:3.44.0
ARG FLUTTER_VERSION=3.50.1
RUN git config --global --add safe.directory /sdks/flutter \
 && git -C /sdks/flutter fetch -q --depth 1 origin tag "$FLUTTER_VERSION" \
 && git -C /sdks/flutter checkout -q "$FLUTTER_VERSION" \
 && flutter --disable-analytics \
 && flutter precache --web \
 && flutter --version
