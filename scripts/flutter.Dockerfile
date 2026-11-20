# Flutter fijado para comprobar y compilar el frontend en local (scripts/flutter-check.sh).
# La imagen de cirruslabs va por detrás de las versiones estables, así que se parte de ella
# y se mueve el SDK a la etiqueta oficial de github.com/flutter/flutter.
# Subir FLUTTER_VERSION a la vez que flutter-version en .github/workflows/tests.yml.
#
# Sin root: se ejecuta con el uid de quien lanza (docker run -u "$(id -u):$(id -g)"), para que
# los ficheros del repo no cambien de dueño. Por eso el SDK y el HOME admiten cualquier uid.
FROM ghcr.io/cirruslabs/flutter:3.44.0
ARG FLUTTER_VERSION=3.50.1
RUN git config --system --add safe.directory '*' \
 && git -C /sdks/flutter fetch -q --depth 1 origin tag "$FLUTTER_VERSION" \
 && git -C /sdks/flutter checkout -q "$FLUTTER_VERSION" \
 && flutter --disable-analytics \
 && flutter precache --web \
 && flutter --version \
 && useradd -m -d /home/flutter flutter \
 && chmod -R a+rwX /sdks/flutter \
 && chmod 1777 /home/flutter
ENV HOME=/home/flutter PUB_CACHE=/home/flutter/.pub-cache
USER flutter
# Herramienta de compilación, no un servicio.
HEALTHCHECK NONE
