# 🎫 Sistema de Gestión de Tickets Empresariales

Sistema automatizado de atención al cliente basado en **n8n**, **PostgreSQL** y **IA (Groq/LLaMA)**, desplegado sobre una VPS Azure con SSL automático vía Caddy.

El sistema recibe correos electrónicos de clientes, los clasifica automáticamente con IA, decide si escalar o resolver, y mantiene **trazabilidad completa** de cada ticket a lo largo de su ciclo de vida.

---

## 📐 Arquitectura

```
┌──────────────┐     ┌──────────────────────┐     ┌──────────────────┐
│   Gmail      │────▶│   n8n (Workflows)    │────▶│  PostgreSQL      │
│   Clientes   │     │   - Clasificación IA │     │  - tickets       │
│              │◀────│   - Escalamiento     │     │  - historial     │
│   Áreas      │     │   - Notificaciones   │     │  - triggers      │
└──────────────┘     └──────────────────────┘     └──────────────────┘
                              │                          │
                         ┌────┘                     ┌────┘
                         ▼                          ▼
                  ┌──────────────┐          ┌──────────────────┐
                  │    Caddy     │          │  Dashboard HTML  │
                  │  (SSL/HTTPS) │          │  (Visualizador)  │
                  └──────────────┘          └──────────────────┘
```

---

## 📁 Estructura del Proyecto

```
gestion-tickets/
├── n8n-docker/                          # Infraestructura n8n + Caddy + PostgreSQL (n8n)
│   ├── docker-compose.yml               # Servicios: caddy, n8n, postgres
│   ├── Caddyfile                        # Reverse proxy con SSL automático
│   ├── certs/                           # Certificados SSL (auto-generados por Caddy)
│   └── n8n_data/                        # Datos persistentes de n8n
│
├── tickets-app/                         # Base de datos de tickets
│   ├── docker-compose.yml               # Servicio: postgres-tickets (puerto 5433)
│   └── init.sql                         # Schema: tablas, triggers, vistas
│
├── Sistema de Gestión de Tickets Empresariales (1).json   # Workflow principal de n8n
├── API Tickets - JSON Webhook.json      # Workflow API para el dashboard (opcional)
├── dashboard.html                       # Visualizador de trazabilidad (opcional)
└── readme.md                            # Este archivo
```

---

## 🔧 Requisitos Previos

- **VPS** con Ubuntu 20.04+ (Azure, AWS, DigitalOcean, etc.)
- **Docker** y **Docker Compose** instalados
- **Dominio o DNS** apuntando a la IP de la VPS (ej: `n8n-carlos-proyecto.eastus2.cloudapp.azure.com`)
- **Cuenta de Gmail** con OAuth2 configurado para n8n
- **API Key de Groq** (para clasificación con IA LLaMA 3.3)

---

## 🚀 Instalación

## 🎥 Guía de Instalación

[🔗 Ver video en Google Drive](https://drive.google.com/file/d/1CXq72zZRF7P5uw6pPOS5PMh2O5TFM1HE/view?usp=sharing)

### Paso 1 — Instalar Docker en la VPS

```bash
# Conectar por SSH a la VPS
ssh usuario@tu-vps-ip

# Instalar Docker
sudo apt update && sudo apt install -y docker.io docker-compose

# Verificar instalación
docker --version
docker-compose --version
```

### Paso 2 — Desplegar n8n + Caddy + PostgreSQL

```bash
# Crear carpeta y copiar archivos
mkdir -p ~/n8n-docker
cd ~/n8n-docker

# Copiar docker-compose.yml y Caddyfile (desde n8n-docker/)
# Luego levantar los servicios
docker-compose up -d
```

**Servicios que se levantan:**

| Servicio | Imagen | Puerto | Función |
|----------|--------|--------|---------|
| `caddy` | `caddy:2.11.2` | 80, 443 | Reverse proxy + SSL automático |
| `n8n` | `n8nio/n8n:2.13.2` | 5678 (interno) | Motor de workflows |
| `postgres` | `postgres:15` | 5432 (interno) | BD interna de n8n |

> ⚠️ **Importante:** El `Caddyfile` debe tener tu dominio real. Caddy genera el certificado SSL automáticamente.

### Paso 3 — Desplegar la Base de Datos de Tickets

```bash
# Crear carpeta y copiar archivos
mkdir -p ~/tickets-app
cd ~/tickets-app

# Copiar docker-compose.yml e init.sql (desde tickets-app/)
# Levantar el servicio
docker-compose up -d
```

**Servicio:**

| Servicio | Puerto Externo | Base de Datos | Usuario |
|----------|---------------|---------------|---------|
| `postgres-tickets` | `5433` | `tickets` | `tickets_user` |

> 📝 La BD se conecta a la red `n8n-docker_default` para que n8n pueda comunicarse con ella internamente.

### Paso 4 — Verificar que todo esté corriendo

```bash
docker ps
```

Deberías ver 4 contenedores activos:
```
caddy           (puertos 80, 443)
n8n             (puerto 5678 interno)
postgres        (BD de n8n)
postgres-tickets (BD de tickets, puerto 5433)
```

---

## ⚙️ Configuración de n8n

### 1. Acceder a n8n

Abrir en el navegador:
```
https://n8n-carlos-proyecto.eastus2.cloudapp.azure.com/
```

Crear cuenta de administrador en el primer acceso.

### 2. Configurar Credenciales

En n8n ir a **Settings → Credentials** y configurar:

| Credencial | Tipo | Detalles |
|------------|------|----------|
| Gmail account | Gmail OAuth2 | Cuenta que **recibe** correos de clientes |
| Gmail account 2 | Gmail OAuth2 | Cuenta que **envía** respuestas del sistema |
| Postgres account | PostgreSQL | Host: `postgres-tickets`, Puerto: `5432`, DB: `tickets`, User: `tickets_user`, Pass: `tickets2025seguro` |
| Groq account | Groq API | API Key de Groq para clasificación con IA |

> 📝 **Nota sobre PostgreSQL:** Dentro de Docker, el host es el nombre del servicio (`postgres-tickets`) y el puerto interno es `5432` (no `5433`, ese es el puerto externo).

### 3. Importar el Workflow Principal

1. Ir a **Workflows** → **⋮** (menú) → **Import from file**
2. Seleccionar: `Sistema de Gestión de Tickets Empresariales (1).json`
3. Abrir el workflow y **verificar** que todas las credenciales estén asignadas correctamente
4. **Activar** el workflow (toggle en la esquina superior derecha)

---

## 🔄 Flujo del Sistema

### Flujo Principal (Recepción → Resolución)

```
1. 📧 RECEPCIÓN
   Gmail Trigger → Marcar como leído → Evitar loop → Extraer variables

2. 🧠 ANÁLISIS IA (Groq / LLaMA 3.3)
   Clasificación automática:
   ├── Categoría: CRITICA | SIMPLE
   ├── Sentimiento: POSITIVO | NEUTRO | NEGATIVO_LEVE | NEGATIVO_FUERTE
   ├── Complejidad: ALTA | BAJA
   └── Lenguaje agresivo: true | false

3. 📝 REGISTRO
   Crear ticket en BD → Enviar confirmación al cliente → Actualizar análisis IA

4. 🔀 MOTOR DE REGLAS (¿Requiere escalamiento?)
   SI escalar (CRITICA, NEGATIVO_FUERTE, agresivo, ALTA complejidad, +2 repetidos):
   │
   ├── Lenguaje agresivo / negativo fuerte:
   │   └── 🟠 Escalado a Atención al Usuario
   │       → Historial → Reenviar a olayacarlosolaya66@gmail.com
   │
   └── Categoría crítica / alta complejidad / repetidos:
       └── 🔴 Escalado a Asesoría Jurídica
           → Historial → Reenviar a olayacarlosolaya65@gmail.com

   NO escalar:
   └── 🟢 Resuelto Automáticamente
       → Historial → Notificar resolución al cliente

5. 🔒 CIERRE POR HUMANO
   Trigger respuesta del área → Extraer ticket ID (UUID del subject)
   → Validar → Historial: Cerrado → Notificar cierre al cliente
```

### Estados del Ticket

| Estado | Descripción | Color |
|--------|-------------|-------|
| `Recibido` | Ticket recién creado por correo entrante | 🔵 Azul |
| `Escalado a humano` | Requiere atención de un área especializada | 🟠 Naranja |
| `Resuelto automáticamente` | Caso simple resuelto sin intervención humana | 🟣 Púrpura |
| `Cerrado por humano` | Área responsable respondió y cerró el caso | 🟢 Verde |

---

## 🗄️ Base de Datos

### Tabla `tickets`

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `ticket_id` | UUID (PK) | Identificador único auto-generado |
| `email_id` | VARCHAR(100) | ID del correo en Gmail |
| `thread_id` | VARCHAR(100) | ID del hilo de Gmail |
| `email` | VARCHAR(255) | Correo del cliente |
| `subject` | TEXT | Asunto del correo |
| `message` | TEXT | Cuerpo del mensaje |
| `received_at` | TIMESTAMPTZ | Fecha de recepción del correo |
| `categoria` | VARCHAR(10) | CRITICA / SIMPLE (asignada por IA) |
| `sentimiento` | VARCHAR(20) | POSITIVO / NEUTRO / NEGATIVO_LEVE / NEGATIVO_FUERTE |
| `complejidad` | VARCHAR(5) | ALTA / BAJA |
| `lenguaje_agresivo` | BOOLEAN | Detectado por IA |
| `estado` | VARCHAR(50) | Estado actual (sincronizado por trigger) |
| `created_at` | TIMESTAMPTZ | Fecha de creación en BD |
| `updated_at` | TIMESTAMPTZ | Última actualización |

### Tabla `ticket_historial`

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | UUID (PK) | Identificador único |
| `ticket_id` | UUID (FK) | Referencia al ticket |
| `estado` | VARCHAR(50) | Estado en esta transición |
| `accion` | TEXT | Descripción detallada de la acción |
| `fecha` | TIMESTAMPTZ | Fecha/hora de la transición |

### Triggers Automáticos

| Trigger | Evento | Función |
|---------|--------|---------|
| `trg_log_ticket_creado` | `AFTER INSERT ON tickets` | Registra automáticamente el primer historial ("Recibido") |
| `trg_sync_estado` | `AFTER INSERT ON ticket_historial` | Sincroniza el estado del ticket con la última entrada del historial |

### Vista

| Vista | Descripción |
|-------|-------------|
| `v_tickets_7dias` | Tickets no resueltos del mismo email/categoría en los últimos 7 días (para detectar repetidos) |

---

## 📊 Dashboard de Trazabilidad (Opcional)

### Instalar el API Webhook

1. En n8n, importar: `API Tickets - JSON Webhook.json`
2. Activar el workflow
3. Endpoint disponible en:
   ```
   GET https://n8n-carlos-proyecto.eastus2.cloudapp.azure.com/webhook/tickets-api
   ```

### Usar el Dashboard

1. Abrir `dashboard.html` en cualquier navegador (doble click)
2. Verificar que la URL del API esté correcta
3. Presionar **CARGAR DATOS**

**Funcionalidades del dashboard:**
- 📈 8 tarjetas de estadísticas en tiempo real
- 🔍 Filtros por estado (Recibido, Escalado, Resuelto, Cerrado)
- 🔎 Búsqueda por email, asunto o ID de ticket
- 📋 Tabla completa con categoría, sentimiento, complejidad
- 🕐 **Timeline expandible** con el ciclo de vida completo de cada ticket

---

## 🌐 Variables de Entorno

### n8n (`n8n-docker/docker-compose.yml`)

| Variable | Valor | Descripción |
|----------|-------|-------------|
| `N8N_HOST` | `n8n-carlos-proyecto.eastus2.cloudapp.azure.com` | Dominio público |
| `N8N_PROTOCOL` | `https` | Protocolo (Caddy maneja SSL) |
| `WEBHOOK_URL` | `https://n8n-carlos-proyecto...com/` | URL base para webhooks |
| `N8N_ENCRYPTION_KEY` | `K2025FERMENTACIONCAFE` | Clave de encriptación de credenciales |
| `GENERIC_TIMEZONE` | `America/Bogota` | Zona horaria |
| `DB_TYPE` | `postgresdb` | Tipo de BD para n8n internamente |
| `EXECUTIONS_DATA_SAVE_ON_*` | `all` | Guardar todas las ejecuciones |

### PostgreSQL Tickets (`tickets-app/docker-compose.yml`)

| Variable | Valor |
|----------|-------|
| `POSTGRES_USER` | `tickets_user` |
| `POSTGRES_PASSWORD` | `tickets2025seguro` |
| `POSTGRES_DB` | `tickets` |

---

## 🛠️ Comandos Útiles

```bash
# Ver logs de n8n
cd ~/n8n-docker && docker-compose logs -f n8n

# Ver logs de la BD de tickets
cd ~/tickets-app && docker-compose logs -f postgres-tickets

# Reiniciar todos los servicios
cd ~/n8n-docker && docker-compose restart
cd ~/tickets-app && docker-compose restart

# Acceder a la BD de tickets directamente
docker exec -it postgres-tickets psql -U tickets_user -d tickets

# Consultar tickets desde la terminal
docker exec -it postgres-tickets psql -U tickets_user -d tickets \
  -c "SELECT ticket_id, email, estado, created_at FROM tickets ORDER BY created_at DESC LIMIT 10;"

# Consultar historial de un ticket específico
docker exec -it postgres-tickets psql -U tickets_user -d tickets \
  -c "SELECT estado, accion, fecha FROM ticket_historial WHERE ticket_id = 'UUID-AQUI' ORDER BY fecha;"

# Backup de la base de datos
docker exec postgres-tickets pg_dump -U tickets_user tickets > backup_tickets_$(date +%Y%m%d).sql
```

---

## 🔐 Seguridad

> ⚠️ **Antes de pasar a producción, cambiar:**

- [ ] Contraseña de PostgreSQL (`tickets2025seguro` y `n8n2025seguro`)
- [ ] `N8N_ENCRYPTION_KEY` por una clave más segura
- [ ] Restringir los correos de las áreas (actualmente `olayacarlosolaya65@`, `olayacarlosolaya66@`)
- [ ] Configurar firewall en la VPS (abrir solo puertos 80, 443 y 22)
- [ ] No exponer el puerto `5433` de PostgreSQL a internet

---

## 📋 Trazabilidad — Opcional

El sistema registra **todas las transiciones de estado, fechas y acciones** para garantizar trazabilidad completa:

| Evento | Se registra |
|--------|-------------|
| Ticket creado | ✅ Trigger automático `trg_log_ticket_creado` |
| Análisis de IA completado | ✅ Campos `categoria`, `sentimiento`, `complejidad`, `lenguaje_agresivo` |
| Escalado a Atención al Usuario | ✅ Historial con razón de escalamiento |
| Escalado a Asesoría Jurídica | ✅ Historial con razón de escalamiento |
| Resuelto automáticamente | ✅ Historial con categoría y complejidad |
| Cerrado por humano | ✅ Historial con solución proporcionada |
| Cambio de estado | ✅ Trigger `trg_sync_estado` sincroniza automáticamente |
| Fecha de cada transición | ✅ Campo `fecha` con `TIMESTAMPTZ` |

---

## 👥 Autores

- **Carlos Enrique Olaya Hernández** — Desarrollo, configuración y despliegue

---
