# Informe: Ollama remoto (Qwen) para TaskBoard

Documento pensado para **pasar a un agente o administrador en el equipo donde corre Qwen bajo Ollama**. Describe qué hay que desplegar o comprobar en ese equipo, **qué datos hay que devolver** al responsable de TaskBoard en el minipc, y cómo se enlaza la aplicación.

---

## 1) Objetivo

- El **backend TaskBoard** (FastAPI en Docker, contenedor `taskboard-api`) genera sugerencias de tareas llamando a una API compatible con OpenAI: **`POST /v1/chat/completions`**.
- Esa API la expone **Ollama** en el puerto **11434** por defecto.
- El modelo deseado es la familia **Qwen** (por ejemplo `qwen2.5:3b-instruct-q4_K_M`), pero el nombre exacto debe coincidir con el que figure en `ollama list` en el servidor Ollama.

**Flujo resumido:**

```text
Navegador / app Flutter → Caddy (taskboard-web) → taskboard-api (Docker)
                                                      → http://<IP_OLLAMA>:11434/v1/chat/completions
```

---

## 2) Rol del equipo con Ollama (servidor de inferencia)

Ese equipo **no** necesita instalar TaskBoard ni Docker del proyecto. Solo debe:

1. Tener **Ollama** instalado y en ejecución.
2. Tener **descargado** el modelo Qwen que se vaya a usar.
3. **Escuchar en la red local** (no solo en `127.0.0.1`), para que el minipc (u otro host donde corre `taskboard-api`) pueda conectar.
4. Permitir tráfico **TCP entrante al puerto 11434** desde la IP del minipc o desde la subred LAN acordada.

---

## 3) Checklist en el equipo Ollama (qué debe hacer el agente)

### 3.1 Instalar y arrancar Ollama

- Instalación según SO oficial: [https://ollama.com](https://ollama.com).
- Comprobar servicio activo, por ejemplo:
  - `systemctl status ollama` (Linux con systemd), o el método equivalente en Windows/macOS.

### 3.2 Exponer Ollama en la LAN

Por defecto Ollama puede quedar enlazado solo a **localhost**, y entonces **nadie desde otro equipo podrá conectar**.

- Definir la variable de entorno **`OLLAMA_HOST=0.0.0.0:11434`** para el proceso que ejecuta Ollama (usuario, servicio systemd, etc.).
- Reiniciar Ollama tras el cambio.

Comprobación **en el propio servidor Ollama**:

```bash
ss -tlnp | grep 11434
# Debe mostrar escucha en *:11434 o 0.0.0.0:11434, no solo 127.0.0.1:11434
```

### 3.3 Descargar el modelo Qwen

Ejemplo (ajustar el nombre al acordado con el equipo de TaskBoard):

```bash
ollama pull qwen2.5:3b-instruct-q4_K_M
```

Listar modelos disponibles:

```bash
ollama list
```

Anotar el **nombre exacto** de la columna `NAME` (es el valor que usará TaskBoard en `LOCAL_LLM_MODEL`).

### 3.4 Firewall

- Abrir **TCP 11434** desde:
  - la **IP del minipc** (más restrictivo), o
  - toda la subred LAN (por ejemplo `192.168.1.0/24`), según política de red.

### 3.5 Prueba de API desde el propio servidor

```bash
curl -sS http://127.0.0.1:11434/api/tags | head -c 400
```

Debe devolver JSON con la lista de modelos.

---

## 4) Información que el agente debe **recopilar y entregar** al minipc

Estos datos son los que hacen falta para configurar TaskBoard sin adivinar:

| Dato | Ejemplo | Uso en TaskBoard |
|------|---------|------------------|
| **IP o hostname LAN** del servidor Ollama | `192.168.1.50` | Base URL del cliente HTTP |
| **Puerto API** | `11434` | Si es el predeterminado, suele ser 11434 |
| **Nombre exacto del modelo** | `qwen2.5:3b-instruct-q4_K_M` | Variable `LOCAL_LLM_MODEL` |
| **¿Escucha en todas las interfaces?** | sí / no | Si no, no funcionará desde el minipc |
| **Regla de firewall aplicada** | “permitido desde <IP-LAN-SERVIDOR>” | Diagnóstico si hay rechazo de conexión |

**URL base recomendada para TaskBoard** (sin barra final):

```text
http://<IP_OLLAMA>:11434
```

Opcional pero muy útil: desde el **minipc** (no hace falta en el servidor Ollama), el administrador debería poder ejecutar:

```bash
curl -sS --connect-timeout 5 "http://<IP_OLLAMA>:11434/api/tags" | head -c 400
```

Si esto falla por timeout o “connection refused”, el problema está en red, firewall o `OLLAMA_HOST`, no en TaskBoard.

---

## 5) Configuración en el minipc (TaskBoard API)

Ruta típica del despliegue Docker: `/mnt/datos/docker/taskboard-api/`.

Editar el archivo **`.env`** del servicio `taskboard-api`:

1. **Desactivar DeepSeek** para que el backend use Ollama: dejar **`DEEPSEEK_API_KEY` vacío** (sin valor).
2. Apuntar Ollama al equipo remoto:

```env
OLLAMA_BASE_URL=http://<IP_OLLAMA>:11434
LOCAL_LLM_MODEL=<nombre_exacto_de_ollama_list>
```

3. Reiniciar el contenedor:

```bash
cd /mnt/datos/docker/taskboard-api
docker compose up -d
```

### 5.1 Comprobar conectividad **desde dentro del contenedor** `taskboard-api`

```bash
docker exec taskboard-api python -c "
import urllib.request
u = 'http://<IP_OLLAMA>:11434/api/tags'
print(urllib.request.urlopen(u, timeout=5).read()[:300])
"
```

Si aquí falla pero `curl` desde el minipc funciona, revisar reglas de firewall entre el host Docker y la LAN (poco habitual; lo normal es que funcione igual).

---

## 6) Comportamiento del backend (para evitar confusiones)

- Si **`DEEPSEEK_API_KEY`** tiene valor, el backend **usa DeepSeek** y **no** llama a Ollama.
- Si **`DEEPSEEK_API_KEY`** está vacío, usa **`OLLAMA_BASE_URL`** (local o remoto; es indistinto para el código).

---

## 7) Seguridad y buenas prácticas

- **No exponer 11434 a Internet** sin túnel cifrado (VPN, WireGuard, etc.). En LAN doméstica suele ser aceptable con firewall acotado.
- La API de Ollama **no usa por defecto** la misma autenticación que TaskBoard; quien pueda alcanzar el puerto puede usar el modelo. Por eso el firewall por IP/subred es importante.
- Preferir **IP estática** o **reserva DHCP** en el servidor Ollama para no romper la URL si cambia la IP.

---

## 8) Diagnóstico rápido de fallos

| Síntoma | Causa probable |
|---------|----------------|
| `ConnectError` / connection refused desde `taskboard-api` | Ollama solo en 127.0.0.1; firewall; IP incorrecta; Ollama parado |
| Timeout | Firewall intermedio, IP equivocada, red distinta (VLAN invitados, etc.) |
| HTTP 4xx/5xx desde Ollama | Modelo no instalado o nombre distinto a `LOCAL_LLM_MODEL` |
| TaskBoard sigue usando nube | `DEEPSEEK_API_KEY` no está vacío en `.env` del contenedor |

Logs del API (minipc):

```bash
docker logs taskboard-api 2>&1 | tail -80
```

---

## 9) Referencias en el repositorio TaskBoard

- Backend (ruta IA): `backend/app/routers/ai.py`
- Variables de entorno (plantilla): `backend/.env.example`
- Despliegue Docker operativo (minipc): `/mnt/datos/docker/taskboard-api/` (`docker-compose.yml`, `.env`)
- Funcionalidad de usuario (contexto): `docs/IA_ASISTENTE.md` (parte del flujo sigue describiendo Supabase; el despliegue actual con API propia usa FastAPI + `OLLAMA_BASE_URL` / `DEEPSEEK_API_KEY` como arriba)

---

*Informe generado para coordinación entre el equipo del servidor Ollama (Qwen) y el administrador de TaskBoard en el minipc.*
