{{flutter_js}}
{{flutter_build_config}}

// Desactivamos Service Worker para evitar servir bundles obsoletos
// entre navegadores/proxies mientras estabilizamos despliegue.
_flutter.loader.load({});
