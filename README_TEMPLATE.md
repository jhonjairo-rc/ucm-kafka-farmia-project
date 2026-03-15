# 🌾 FarmIA Kafka Pipeline

**Pipeline de streaming para sensores agrícolas IoT y ventas en línea**

Máster NTIC — Universidad Complutense de Madrid
Asignatura: Kafka y Procesamiento en Tiempo Real

---

## 📋 Índice

1. [Descripción del Proyecto](#-descripción-del-proyecto)
2. [Arquitectura General](#-arquitectura-general)
3. [Estructura del Proyecto](#-estructura-del-proyecto)
4. [Requisitos Previos](#-requisitos-previos)
5. [Tarea 1: Generación de Datos Sintéticos con Datagen](#-tarea-1-generación-de-datos-sintéticos-con-datagen)
   - [Contexto y Objetivo](#contexto-y-objetivo)
   - [¿Qué es el Datagen Source Connector?](#qué-es-el-datagen-source-connector)
   - [Schema Avro: Diseño y Decisiones](#schema-avro-diseño-y-decisiones)
   - [Configuración del Connector](#configuración-del-connector)
   - [Paso a Paso: Ejecución](#paso-a-paso-ejecución)
   - [Verificación y Validación](#verificación-y-validación)
6. [Tarea 2: Integración de MySQL con Kafka Connect](#-tarea-2-integración-de-mysql-con-kafka-connect)
7. [Tarea 3: Procesamiento de Sensores con ksqlDB](#-tarea-3-procesamiento-de-sensores-con-ksqldb)
8. [Tarea 4: Procesamiento de Ventas con ksqlDB](#-tarea-4-procesamiento-de-ventas-con-ksqldb)
9. [Tarea 5: Integración de MongoDB con Kafka Connect](#-tarea-5-integración-de-mongodb-con-kafka-connect)
10. [Comandos Útiles](#-comandos-útiles)

---

## 📖 Descripción del Proyecto

FarmIA es una empresa agrícola que integra sensores IoT en sus campos para monitorizar temperatura, humedad y fertilidad del suelo. Además, opera una plataforma de ventas en línea de productos agrícolas.

Este proyecto construye un pipeline end-to-end con Apache Kafka que:

1. **Genera datos sintéticos** de sensores IoT usando Datagen Connector
2. **Captura transacciones de ventas** desde MySQL usando JDBC Source Connector
3. **Detecta anomalías** en los sensores (temperatura alta, humedad baja) con ksqlDB
4. **Agrega ventas por categoría** en ventanas de 1 minuto con ksqlDB
5. **Persiste alertas** en MongoDB usando MongoDB Sink Connector

---

## 🏗️ Arquitectura General

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FarmIA Kafka Pipeline                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    Kafka Connect     ┌──────────────────┐             │
│  │   Datagen    │ ──────────────────▶  │ sensor-telemetry │             │
│  │  (Sensores)  │   Source Connector   │     (Topic)      │             │
│  └─────────────┘                       └────────┬─────────┘             │
│                                                  │                      │
│                                          ksqlDB  │  Tarea 3             │
│                                                  ▼                      │
│                                        ┌──────────────────┐            │
│                                        │  sensor-alerts    │            │
│                                        │     (Topic)       │            │
│                                        └────────┬─────────┘            │
│                                                  │                      │
│                                      Kafka Connect│  Tarea 5            │
│                                       Sink        ▼                     │
│                                        ┌──────────────────┐            │
│                                        │    MongoDB        │            │
│                                        │ sensor_alerts     │            │
│                                        └──────────────────┘            │
│                                                                         │
│  ┌─────────────┐    Kafka Connect     ┌──────────────────┐             │
│  │    MySQL     │ ──────────────────▶  │sales-transactions│             │
│  │ (Ventas)     │   JDBC Source        │     (Topic)      │             │
│  └─────────────┘                       └────────┬─────────┘             │
│                                                  │                      │
│                                          ksqlDB  │  Tarea 4             │
│                                                  ▼                      │
│                                        ┌──────────────────┐            │
│                                        │  sales-summary    │            │
│                                        │     (Topic)       │            │
│                                        └──────────────────┘            │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────┐         │
│  │              Kafka Broker (KRaft) + Schema Registry       │         │
│  └───────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```
farmia-kafka-pipeline/
├── docker-compose.yml              # Infraestructura completa (8 servicios)
├── README.md                       # Documentación (este fichero)
├── .gitignore
│
├── config/
│   └── .env                        # Variables de entorno centralizadas
│
├── schemas/
│   └── sensor-telemetry.avsc       # Schema Avro para sensores IoT (T1)
│
├── connectors/
│   ├── datagen-sensor-telemetry.json     # Datagen Source Connector (T1)
│   ├── jdbc-mysql-transactions.json      # JDBC Source Connector (T2)
│   └── mongodb-sink-sensor-alerts.json   # MongoDB Sink Connector (T5)
│
├── mysql/
│   └── init.sql                    # DDL + datos iniciales de ventas (T2)
│
├── ksqldb/
│   ├── task3-sensor-alerts.sql     # Queries de detección de anomalías (T3)
│   └── task4-sales-summary.sql     # Queries de agregación de ventas (T4)
│
├── mongodb/
│   └── (reservado para scripts de init opcionales)
│
├── scripts/
│   ├── setup-all.sh                # Setup completo (5 tareas en secuencia)
│   ├── setup-task1.sh              # Setup automatizado para T1
│   ├── setup-task2.sh              # Setup automatizado para T2
│   ├── setup-task3.sh              # Setup automatizado para T3
│   ├── setup-task4.sh              # Setup automatizado para T4
│   ├── setup-task5.sh              # Setup automatizado para T5
│   └── simulate-sales.sh           # Simulador de ventas en MySQL
│
└── docs/
    └── (capturas de pantalla)
```

---

## ⚙️ Requisitos Previos

- **Docker** ≥ 24.0 y **Docker Compose** ≥ 2.20
- **curl** (para interactuar con las APIs REST)
- **python3** (para formatear JSON en terminal)
- ~8 GB de RAM disponible para Docker (los servicios Confluent son pesados)

---

## 🔬 Tarea 1: Generación de Datos Sintéticos con Datagen

### Contexto y Objetivo

La primera tarea consiste en simular las lecturas de los sensores IoT que FarmIA tiene desplegados en sus campos agrícolas. En un entorno real, estos sensores enviarían datos directamente a Kafka a través de un producer (MQTT → Kafka, por ejemplo). En el lab, simulamos esta fuente de datos usando el **Datagen Source Connector**.

**Objetivo:** configurar un source connector que genere eventos continuos en el topic `sensor-telemetry` con datos realistas de sensores (temperatura, humedad, fertilidad del suelo).

**Output:** topic Kafka `sensor-telemetry` con mensajes serializados en Avro.

### ¿Qué es el Datagen Source Connector?

El Datagen Source Connector (`io.confluent.kafka.connect.datagen.DatagenConnector`) es un connector de Confluent diseñado específicamente para generar datos sintéticos. Funciona dentro de Kafka Connect y produce mensajes a un topic de Kafka a un ritmo configurable.

**¿Por qué Datagen y no un producer Python?**

- Datagen se ejecuta dentro de Kafka Connect, por lo que aprovecha toda su infraestructura: tolerancia a fallos, monitorización, gestión de offsets y serialización Avro nativa.
- No necesitas escribir código — solo un schema Avro y una configuración JSON.
- En un entorno de evaluación, demuestra dominio de Kafka Connect como framework (que es lo que pide la tarea).

**¿Cómo genera datos?**

Datagen lee un schema Avro que incluye anotaciones especiales en `arg.properties`. Estas anotaciones le dicen al connector cómo generar el valor de cada campo:
- `options`: elige aleatoriamente de una lista de valores fijos
- `range`: genera un número aleatorio entre `min` y `max`
- `iteration`: genera valores incrementales con un `start` y un `step`

### Schema Avro: Diseño y Decisiones

El schema se encuentra en `schemas/sensor-telemetry.avsc`.

```json
{
  "namespace": "com.farmia.iot",
  "name": "SensorTelemetry",
  "type": "record",
  "fields": [
    {
      "name": "sensor_id",
      "type": "string",
      "arg.properties": {
        "options": ["sensor_001", "sensor_002", ..., "sensor_010"]
      }
    },
    {
      "name": "timestamp",
      "type": "long",
      "arg.properties": {
        "iteration": { "start": 1704067200000, "step": 5000 }
      }
    },
    {
      "name": "temperature",
      "type": "double",
      "arg.properties": {
        "range": { "min": 10.0, "max": 45.0 }
      }
    },
    {
      "name": "humidity",
      "type": "double",
      "arg.properties": {
        "range": { "min": 5.0, "max": 80.0 }
      }
    },
    {
      "name": "soil_fertility",
      "type": "double",
      "arg.properties": {
        "range": { "min": 20.0, "max": 100.0 }
      }
    }
  ]
}
```

#### Decisiones de diseño clave

**1. Rangos de `temperature` (10.0 - 45.0) y `humidity` (5.0 - 80.0)**

Las reglas de anomalía de la Tarea 3 son: temperatura > 35°C o humedad < 20%. Si los rangos fueran demasiado estrechos (e.g., 20-30°C), nunca generaríamos anomalías. Si fueran demasiado extremos, todas las lecturas serían anómalas. Con estos rangos:

- **Temperatura:** el rango 10-45 hace que ~28% de las lecturas superen los 35°C → `(45-35)/(45-10) = 28.6%`
- **Humedad:** el rango 5-80 hace que ~20% de las lecturas caigan por debajo de 20% → `(20-5)/(80-5) = 20%`

Esto asegura un flujo constante de alertas sin saturar el sistema — ideal para verificar que el procesamiento funciona en la Tarea 3.

**2. `sensor_id` con 10 sensores fijos**

Usar `options` en lugar de un generador aleatorio simula un escenario realista: FarmIA tiene un número finito de sensores desplegados. Esto también permite hacer análisis por sensor (e.g., "¿qué sensor genera más alertas?") y particionar por `sensor_id` como key del mensaje.

**3. `timestamp` con `iteration`**

El campo `iteration` genera timestamps incrementales (cada 5 segundos), simulando lecturas periódicas del sensor. El `start` corresponde al 1 de enero de 2024. En un entorno real, usaríamos el timestamp del sistema, pero `iteration` es lo que Datagen soporta para campos long con secuencia controlada.

**4. `soil_fertility` como campo informativo**

El enunciado incluye este campo en la estructura pero no define reglas de anomalía para él. Lo mantenemos disponible con un rango realista (20-100) para futuras extensiones.

### Configuración del Connector

El fichero de configuración está en `connectors/datagen-sensor-telemetry.json`.

```json
{
  "name": "datagen-sensor-telemetry",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "sensor-telemetry",
    "max.interval": 1000,
    "iterations": -1,
    "schema.filename": "/schemas/sensor-telemetry.avsc",
    "schema.keyfield": "sensor_id",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "tasks.max": "1"
  }
}
```

#### Desglose de cada propiedad

| Propiedad | Valor | Explicación |
|---|---|---|
| `connector.class` | `DatagenConnector` | Clase Java del connector. Kafka Connect la carga desde el plugin path. |
| `kafka.topic` | `sensor-telemetry` | Topic destino donde se publican los eventos generados. |
| `max.interval` | `1000` | Intervalo máximo en ms entre mensajes. Con valor 1000, genera ~1 msg/segundo. |
| `iterations` | `-1` | Número total de mensajes a generar. `-1` = infinito (no para nunca). |
| `schema.filename` | `/schemas/sensor-telemetry.avsc` | Ruta al schema Avro **dentro del container**. Funciona porque en `docker-compose.yml` montamos `./schemas:/schemas:ro`. |
| `schema.keyfield` | `sensor_id` | Campo del schema que se usa como message key. Esto asegura que eventos del mismo sensor van a la misma partición (ordenamiento por sensor). |
| `key.converter` | `StringConverter` | La key se serializa como string plano (el `sensor_id`). |
| `value.converter` | `AvroConverter` | El value se serializa en Avro binario. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL interna del Schema Registry (dentro de la red Docker). |
| `tasks.max` | `1` | Un solo task es suficiente para un lab. En producción se usarían más para paralelismo. |

#### ¿Cómo llega el schema al container?

En el `docker-compose.yml`, el servicio `kafka-connect` tiene este volumen:

```yaml
volumes:
  - ./schemas:/schemas:ro
```

Esto monta la carpeta local `schemas/` (donde está el `.avsc`) en la ruta `/schemas/` dentro del container, en modo solo lectura (`:ro`). Por eso en el connector configuramos `"schema.filename": "/schemas/sensor-telemetry.avsc"`.

### Paso a Paso: Ejecución

#### 1. Levantar la infraestructura

```bash
# Desde la raíz del proyecto
docker compose --env-file config/.env up -d
```

Esto arranca los 8 servicios. El orden de dependencias está gestionado por `depends_on` con health checks:

```
kafka (broker) → schema-registry → kafka-connect → ...
                                 → ksqldb-server → ksqldb-cli
              → mysql
              → mongodb
              → kafka-ui
```

**Nota:** Kafka Connect tarda ~90 segundos en arrancar porque instala los plugins (Datagen, JDBC, MongoDB) al inicio. Esto es intencional — cada vez que se recrea el container, se instalan las últimas versiones. En producción, crearíamos una imagen Docker custom con los plugins preinstalados.

#### 2. Verificar que los servicios están sanos

```bash
docker compose ps
```

Todos los servicios deben mostrar `healthy` o `running`. Si `kafka-connect` muestra `starting`, esperar unos minutos.

#### 3. Ejecutar el setup de la Tarea 1

```bash
chmod +x scripts/setup-task1.sh
./scripts/setup-task1.sh
```

El script:
1. Crea los 4 topics (`sensor-telemetry`, `sales-transactions`, `sensor-alerts`, `sales-summary`) con 3 particiones cada uno
2. Espera a que Kafka Connect esté ready
3. Registra el Datagen connector vía la REST API
4. Verifica que se están generando mensajes

#### 4. Alternativamente, hacerlo manualmente

Si prefieres ejecutar paso a paso para entender cada acción:

```bash
# Crear el topic
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --create \
  --topic sensor-telemetry \
  --partitions 3 \
  --replication-factor 1

# Registrar el connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connectors/datagen-sensor-telemetry.json
```

### Verificación y Validación

Una vez ejecutado el setup, hay varias formas de verificar que todo funciona:

#### Verificar el connector

```bash
# Estado del connector
curl http://localhost:8083/connectors/datagen-sensor-telemetry/status | python3 -m json.tool
```

Respuesta esperada:
```json
{
    "name": "datagen-sensor-telemetry",
    "connector": {
        "state": "RUNNING",
        "worker_id": "kafka-connect:8083"
    },
    "tasks": [
        {
            "id": 0,
            "state": "RUNNING",
            "worker_id": "kafka-connect:8083"
        }
    ]
}
```

Tanto el `connector` como el `task` deben estar en estado `RUNNING`.

#### Consumir mensajes del topic

```bash
# Consumir 5 mensajes (formato Avro → se muestra como bytes)
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-telemetry \
  --from-beginning \
  --max-messages 5
```

**Nota:** El `kafka-console-consumer` muestra Avro como bytes codificados (texto ilegible). Para ver el contenido deserializado, usar el `kafka-avro-console-consumer`:

```bash
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-telemetry \
  --from-beginning \
  --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081
```

Salida esperada (ejemplo):
```json
{"sensor_id":"sensor_003","timestamp":1704067200000,"temperature":38.2,"humidity":45.1,"soil_fertility":67.3}
{"sensor_id":"sensor_007","timestamp":1704067205000,"temperature":22.8,"humidity":12.4,"soil_fertility":89.1}
{"sensor_id":"sensor_001","timestamp":1704067210000,"temperature":28.5,"humidity":55.7,"soil_fertility":42.6}
```

Observa que:
- `temperature` de 38.2 → supera 35°C → generará alerta HIGH_TEMPERATURE en Tarea 3
- `humidity` de 12.4 → por debajo de 20% → generará alerta LOW_HUMIDITY en Tarea 3

#### Verificar el schema en Schema Registry

```bash
# Listar subjects registrados
curl http://localhost:8081/subjects | python3 -m json.tool

# Ver el schema del topic sensor-telemetry
curl http://localhost:8081/subjects/sensor-telemetry-value/versions/latest | python3 -m json.tool
```

El schema registrado debe coincidir con nuestro `sensor-telemetry.avsc` (sin las anotaciones `arg.properties`, que son solo para el Datagen y no forman parte del schema Avro estándar).

#### Verificar en Kafka UI

Abrir http://localhost:8080 en el navegador:
1. **Topics** → `sensor-telemetry` → pestaña "Messages" → se ven los eventos en tiempo real
2. **Schema Registry** → subject `sensor-telemetry-value` → se ve el schema Avro registrado
3. **Kafka Connect** → connector `datagen-sensor-telemetry` → estado RUNNING

#### Verificar offsets y particiones

```bash
# Ver offsets por partición (cuántos mensajes hay)
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic sensor-telemetry \
  --time -1

# Describir el topic
docker exec kafka kafka-topics \
  --bootstrap-server kafka:29092 \
  --describe \
  --topic sensor-telemetry
```

---

## 📦 Tarea 2: Integración de MySQL con Kafka Connect

### Contexto y Objetivo

FarmIA opera una plataforma de ventas en línea de productos agrícolas (fertilizantes, semillas, pesticidas, herramientas, sistemas de riego). Las transacciones se almacenan en una base de datos MySQL. El objetivo es llevar esos datos a Kafka para poder procesarlos en streaming en la Tarea 4.

**Input:** tabla `transactions` en MySQL con columnas `transaction_id`, `timestamp`, `product_id`, `category`, `quantity`, `price`.

**Output:** topic Kafka `sales-transactions` con los registros serializados en Avro.

### ¿Por qué JDBC Source Connector y no Debezium (CDC)?

La tarea pide "leer datos de una base de datos relacional", lo cual se puede resolver con dos enfoques:

| Aspecto | JDBC Source Connector | Debezium (CDC) |
|---|---|---|
| **Mecanismo** | Polling: ejecuta un `SELECT` periódico buscando filas nuevas | Binlog: lee el log de transacciones de MySQL en tiempo real |
| **Latencia** | Segundos (depende del `poll.interval.ms`) | Milisegundos (casi inmediato) |
| **Detecta DELETEs** | No | Sí |
| **Detecta UPDATEs** | Solo con modo `timestamp+incrementing` | Sí (captura before/after) |
| **Requisitos en MySQL** | Solo `SELECT` sobre la tabla | Binlog habilitado, permisos de replicación |
| **Complejidad** | Baja — solo necesita una conexión JDBC | Media — requiere configurar binlog, slots, etc. |
| **Formato del mensaje** | Fila plana (los campos de la tabla) | Envelope con `before`, `after`, `op`, `source` |

Para esta tarea elegimos **JDBC** porque:
1. El enunciado pide integrar datos de ventas "provenientes de MySQL", no capturar cambios — un enfoque de polling es suficiente
2. El formato de salida es más simple (fila plana → más fácil de procesar en ksqlDB en la Tarea 4)
3. La complejidad del connector es menor, permitiendo enfocarnos en el procesamiento streaming

### Diseño de la Tabla MySQL

```sql
CREATE TABLE transactions (
    id             INT          AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(20)  NOT NULL UNIQUE,
    timestamp      BIGINT       NOT NULL,
    product_id     VARCHAR(20)  NOT NULL,
    category       VARCHAR(50)  NOT NULL,
    quantity       INT          NOT NULL,
    price          DOUBLE       NOT NULL,
    updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

#### Decisiones de diseño clave

**1. Columna `id` (AUTO_INCREMENT) separada de `transaction_id`**

El JDBC Source Connector en modo `timestamp+incrementing` necesita una columna numérica que **siempre crezca** con cada nueva fila. El `transaction_id` es un string (`tx10001`, `tx10002`...) que no sirve para esto. La columna `id` es un entero auto-incremental que cumple perfectamente este rol.

**2. Columna `updated_at` con `ON UPDATE CURRENT_TIMESTAMP`**

Esta es la columna de tracking temporal del connector. La cláusula `ON UPDATE CURRENT_TIMESTAMP` es clave: MySQL actualiza automáticamente este campo cada vez que **cualquier columna** de la fila cambia. Esto permite al connector detectar UPDATEs sin lógica adicional en la aplicación.

El connector almacena internamente el último par (`id`, `updated_at`) procesado. En cada poll, ejecuta conceptualmente:

```sql
SELECT * FROM transactions
WHERE id > :last_id OR updated_at > :last_updated_at
ORDER BY updated_at, id ASC
```

Esto garantiza que:
- INSERTs → detectados por `id` creciente
- UPDATEs → detectados por `updated_at` cambiante
- No se releen filas ya procesadas (eficiente)
- No se pierden filas incluso con resolución temporal limitada (fiable)

**3. `timestamp` como BIGINT (epoch millis) y no como DATETIME**

El enunciado define `timestamp` como epoch millis (`1673548200000`). Mantenerlo como `BIGINT` en MySQL evita conversiones y asegura que el valor llega a Kafka exactamente como se espera en la Tarea 4.

### Configuración del JDBC Connector

El fichero está en `connectors/jdbc-mysql-transactions.json`:

```json
{
  "name": "jdbc-mysql-transactions",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "connection.url": "jdbc:mysql://mysql:3306/farmia?useSSL=false&allowPublicKeyRetrieval=true",
    "connection.user": "farmia_user",
    "connection.password": "farmia_password",
    "table.whitelist": "transactions",
    "mode": "timestamp+incrementing",
    "incrementing.column.name": "id",
    "timestamp.column.name": "updated_at",
    "poll.interval.ms": 5000,
    "batch.max.rows": 100,
    "topic.prefix": "sales-",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "transforms": "dropTechnicalFields,castTimestampToString,insertTopic,insertPartition",
    "transforms.dropTechnicalFields.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
    "transforms.dropTechnicalFields.exclude": "id,updated_at",
    "transforms.castTimestampToString.type": "org.apache.kafka.connect.transforms.Cast$Value",
    "transforms.castTimestampToString.spec": "timestamp:int64",
    "transforms.insertTopic.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.insertTopic.topic.field": "_kafka_topic",
    "transforms.insertPartition.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.insertPartition.partition.field": "_kafka_partition",
    "tasks.max": "1"
  }
}
```

#### Desglose de propiedades: Conexión y Modo

| Propiedad | Valor | Explicación |
|---|---|---|
| `connection.url` | `jdbc:mysql://mysql:3306/farmia?...` | URL JDBC al container MySQL. `mysql` es el hostname en la red Docker. `useSSL=false` desactiva SSL (lab). `allowPublicKeyRetrieval=true` permite la autenticación con caching_sha2_password de MySQL 8. |
| `connection.user/password` | `farmia_user/farmia_password` | Credenciales del usuario MySQL (definidas en `.env` y creadas por el init.sql). |
| `table.whitelist` | `transactions` | Lista de tablas a leer. Solo necesitamos una. Se podría usar `table.blacklist` para excluir tablas en lugar de incluir. |
| `mode` | `timestamp+incrementing` | Modo combinado que detecta tanto INSERTs como UPDATEs. Ver sección detallada más abajo. |
| `incrementing.column.name` | `id` | Columna AUTO_INCREMENT para detectar INSERTs. |
| `timestamp.column.name` | `updated_at` | Columna TIMESTAMP con `ON UPDATE CURRENT_TIMESTAMP` para detectar UPDATEs. |
| `poll.interval.ms` | `5000` | Cada 5 segundos el connector consulta MySQL buscando filas nuevas o modificadas. |
| `batch.max.rows` | `100` | Máximo de filas por batch. Si hay 500 filas nuevas, las procesa en 5 batches de 100. |
| `topic.prefix` | `sales-` | Se concatena con el nombre de la tabla: `sales-` + `transactions` = `sales-transactions`. |
| `value.converter` | `AvroConverter` | Serializa los registros en Avro. El schema se genera automáticamente a partir de la estructura de la tabla MySQL (DDL → Avro schema). |

#### Modo `timestamp+incrementing` en detalle

El modo combina dos estrategias de detección para cubrir tanto INSERTs como UPDATEs:

```
                    ¿Fila nueva?              ¿Fila modificada?
                    (INSERT)                  (UPDATE)
                        │                          │
                        ▼                          ▼
              incrementing.column              timestamp.column
              (id AUTO_INCREMENT)              (updated_at ON UPDATE)
                        │                          │
                        ▼                          ▼
              WHERE id > último_id     WHERE updated_at > último_timestamp
                        │                          │
                        └──────────┬───────────────┘
                                   ▼
                          OR (unión de ambos)
                                   │
                                   ▼
                        Filas nuevas + modificadas
                        se publican en el topic
```

La query que ejecuta el connector en cada poll es conceptualmente:

```sql
SELECT * FROM transactions
WHERE id > :last_incrementing_id
   OR updated_at > :last_timestamp
ORDER BY updated_at, id ASC
```

**¿Por qué no solo `incrementing`?** Porque el modo `incrementing` solo detecta filas nuevas (id creciente). Si alguien corrige el precio de una transacción existente con un `UPDATE`, el `id` no cambia y el connector nunca vería la modificación.

**¿Por qué no solo `timestamp`?** Porque `timestamp` tiene un problema de resolución: si dos INSERTs ocurren en el mismo milisegundo con el mismo `updated_at`, el connector podría perder una. La columna `id` garantiza que ningún INSERT se pierda, independientemente de la resolución temporal.

**La columna `updated_at` en MySQL:**

```sql
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
```

- `DEFAULT CURRENT_TIMESTAMP`: se inicializa automáticamente al insertar la fila
- `ON UPDATE CURRENT_TIMESTAMP`: se actualiza automáticamente cuando cualquier campo de la fila cambia

Esto significa que no necesitamos lógica en la aplicación — MySQL actualiza `updated_at` por nosotros en cada INSERT y UPDATE.

#### SMTs (Single Message Transforms)

Las SMTs son transformaciones ligeras que se aplican a cada mensaje **dentro del connector**, antes de que se publique en Kafka. No requieren código — se configuran declarativamente en el JSON.

Usamos 4 SMTs encadenadas (se ejecutan en el orden declarado en `"transforms"`):

```
MySQL Row → [dropTechnicalFields] → [castTimestampToString] → [insertTopic] → [insertPartition] → Kafka
```

**SMT 1: `dropTechnicalFields` (ReplaceField$Value)**

```json
"transforms.dropTechnicalFields.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",
"transforms.dropTechnicalFields.exclude": "id,updated_at"
```

Elimina las columnas técnicas `id` y `updated_at` del mensaje. Estas columnas son de infraestructura (tracking del connector) y no son datos de negocio. El mensaje en Kafka solo contendrá: `transaction_id`, `timestamp`, `product_id`, `category`, `quantity`, `price` — exactamente los campos que pide el enunciado.

**Antes:** `{id: 1, transaction_id: "tx10001", timestamp: ..., ..., updated_at: ...}`
**Después:** `{transaction_id: "tx10001", timestamp: ..., product_id: ..., category: ..., quantity: ..., price: ...}`

**SMT 2: `castTimestampToString` (Cast$Value)**

```json
"transforms.castTimestampToString.type": "org.apache.kafka.connect.transforms.Cast$Value",
"transforms.castTimestampToString.spec": "timestamp:int64"
```

Asegura que el campo `timestamp` se serializa como `int64` (long) en Avro. El JDBC connector a veces infiere tipos de forma inconsistente dependiendo del driver MySQL — este Cast garantiza que el tipo es siempre `long`, compatible con la declaración del stream ksqlDB en la Tarea 4.

**SMT 3: `insertTopic` (InsertField$Value)**

```json
"transforms.insertTopic.type": "org.apache.kafka.connect.transforms.InsertField$Value",
"transforms.insertTopic.topic.field": "_kafka_topic"
```

Añade un campo `_kafka_topic` con el nombre del topic (`sales-transactions`) al mensaje. Esto es metadata de trazabilidad: si el mensaje se mueve a otro sistema (data lake, warehouse), siempre se sabe de qué topic Kafka vino.

**SMT 4: `insertPartition` (InsertField$Value)**

```json
"transforms.insertPartition.type": "org.apache.kafka.connect.transforms.InsertField$Value",
"transforms.insertPartition.partition.field": "_kafka_partition"
```

Añade un campo `_kafka_partition` con el número de partición. Junto con `_kafka_topic`, permite trazar el linaje completo del dato.

**Resultado final del mensaje en Kafka:**

```json
{
  "transaction_id": "tx10001",
  "timestamp": 1710000000000,
  "product_id": "prod_001",
  "category": "fertilizers",
  "quantity": 2,
  "price": 50.0,
  "_kafka_topic": "sales-transactions",
  "_kafka_partition": 0
}
```

Limpio (sin campos técnicos), con metadata de trazabilidad, y con tipos garantizados.

#### ¿Cómo se genera el nombre del topic?

El JDBC connector construye el nombre del topic como: `topic.prefix + table_name`. En nuestro caso:

```
topic.prefix = "sales-"
table_name   = "transactions"
─────────────────────────────
topic        = "sales-transactions"  ✓ (exactamente lo que pide el enunciado)
```

Esto es una convención nativa del connector, no una SMT. Las SMTs que usamos transforman el **contenido** del mensaje, no el routing.

#### ¿Cómo se mapea la tabla MySQL a Avro (después de SMTs)?

Después de aplicar `dropTechnicalFields`, los campos que llegan al topic son:

| Campo en Kafka | Origen MySQL | Tipo Avro |
|---|---|---|
| `transaction_id` | `VARCHAR(20)` | `string` |
| `timestamp` | `BIGINT` | `long` (garantizado por Cast SMT) |
| `product_id` | `VARCHAR(20)` | `string` |
| `category` | `VARCHAR(50)` | `string` |
| `quantity` | `INT` | `int` |
| `price` | `DOUBLE` | `double` |
| `_kafka_topic` | (inyectado por SMT) | `string` |
| `_kafka_partition` | (inyectado por SMT) | `int` |

Este schema se registra automáticamente en Schema Registry bajo el subject `sales-transactions-value`.

### Paso a Paso: Ejecución

#### 1. Prerequisito: infraestructura levantada

```bash
# Si no lo has hecho ya
docker compose --env-file config/.env up -d
```

#### 2. Verificar que MySQL tiene datos

```bash
docker exec -it mysql mysql -u farmia_user -pfarmia_password farmia \
  -e "SELECT id, transaction_id, category, quantity, price FROM transactions LIMIT 5;"
```

Salida esperada:
```
+----+----------------+-------------+----------+-------+
| id | transaction_id | category    | quantity | price |
+----+----------------+-------------+----------+-------+
|  1 | tx10001        | fertilizers |        2 |    50 |
|  2 | tx10002        | seeds       |       10 |    15 |
|  3 | tx10003        | pesticides  |        1 |   120 |
|  4 | tx10004        | tools       |        3 |    35 |
|  5 | tx10005        | irrigation  |        1 |   250 |
+----+----------------+-------------+----------+-------+
```

#### 3. Ejecutar el setup de la Tarea 2

```bash
./scripts/setup-task2.sh
```

El script verifica MySQL, registra el JDBC connector, y confirma que los datos llegan al topic.

#### 4. Verificar los datos en Kafka

```bash
# Consumir mensajes deserializados (Avro → JSON)
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sales-transactions \
  --from-beginning \
  --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081
```

Salida esperada:
```json
{"transaction_id":"tx10001","timestamp":1710000000000,"product_id":"prod_001","category":"fertilizers","quantity":2,"price":50.0,"_kafka_topic":"sales-transactions","_kafka_partition":0}
{"transaction_id":"tx10002","timestamp":1710000000100,"product_id":"prod_002","category":"seeds","quantity":10,"price":15.0,"_kafka_topic":"sales-transactions","_kafka_partition":0}
```

Observa que los campos técnicos `id` y `updated_at` han sido eliminados por la SMT `dropTechnicalFields`, y se han añadido `_kafka_topic` y `_kafka_partition` por las SMTs `InsertField`.

#### 5. Simular nuevas ventas en tiempo real

Para probar que el connector detecta filas nuevas continuamente:

```bash
# En un terminal: simular ventas (1 cada 3 segundos)
./scripts/simulate-sales.sh

# En otro terminal: consumir los mensajes en tiempo real
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sales-transactions \
  --property schema.registry.url=http://schema-registry:8081
```

El simulador inserta filas aleatorias en MySQL. El JDBC connector las detecta en el siguiente poll (≤5 segundos) y las publica en el topic.

#### 6. Alternativamente, insertar manualmente

```bash
docker exec -it mysql mysql -u farmia_user -pfarmia_password farmia \
  -e "INSERT INTO transactions (transaction_id, timestamp, product_id, category, quantity, price)
      VALUES ('tx_manual_01', UNIX_TIMESTAMP(NOW())*1000, 'prod_001', 'fertilizers', 5, 75.0);"
```

### Verificación y Validación

#### Estado del connector

```bash
curl http://localhost:8083/connectors/jdbc-mysql-transactions/status | python3 -m json.tool
```

Respuesta esperada:
```json
{
    "name": "jdbc-mysql-transactions",
    "connector": { "state": "RUNNING", "worker_id": "kafka-connect:8083" },
    "tasks": [
        { "id": 0, "state": "RUNNING", "worker_id": "kafka-connect:8083" }
    ]
}
```

#### Verificar el offset almacenado

El JDBC connector almacena su progreso (último `id` leído) en el topic interno `_connect-offsets`:

```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic _connect-offsets \
  --from-beginning \
  --property print.key=true \
  --max-messages 10
```

Verás algo como:
```
["jdbc-mysql-transactions",{"query":"incrementing"}]  {"incrementing":15,"timestamp_nanos":...,"timestamp":1710000000000}
```

Esto indica que el connector ha procesado hasta el `id=15` y el `updated_at` correspondiente. El modo `timestamp+incrementing` almacena ambos valores para su lógica combinada de detección.

#### Schema en Schema Registry

```bash
curl http://localhost:8081/subjects/sales-transactions-value/versions/latest | python3 -m json.tool
```

El schema Avro generado automáticamente incluirá todos los campos de la tabla MySQL.

#### Conteo de mensajes

```bash
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic sales-transactions \
  --time -1
```

Debe mostrar al menos 15 mensajes (los datos iniciales del `init.sql`).

---

## 🔔 Tarea 3: Procesamiento de Sensores con ksqlDB

### Contexto y Objetivo

Los sensores IoT de FarmIA envían datos continuamente al topic `sensor-telemetry` (Tarea 1). Necesitamos un sistema que procese estos datos **en tiempo real** y detecte condiciones anormales que puedan dañar los cultivos.

**Reglas de anomalía (definidas por el enunciado):**
- **HIGH_TEMPERATURE:** temperatura > 35 °C
- **LOW_HUMIDITY:** humedad < 20 %

**Input:** topic `sensor-telemetry` (Avro)
**Output:** topic `sensor-alerts` (JSON)

**Formato de salida esperado:**
```json
{
  "sensor_id": "sensor_001",
  "alert_type": "HIGH_TEMPERATURE",
  "timestamp": 1673548200000,
  "details": "Temperature exceeded 35°C"
}
```

### ¿Por qué ksqlDB?

La tarea permite elegir entre Flink, ksqlDB y Kafka Streams. Elegimos ksqlDB por:

| Aspecto | ksqlDB | Kafka Streams | Flink |
|---|---|---|---|
| **Lenguaje** | SQL | Java/Scala | Java/Scala/SQL |
| **Despliegue** | Servicio ya incluido en el stack Confluent | Aplicación standalone JVM | Cluster separado (JobManager + TaskManagers) |
| **Curva de aprendizaje** | Baja (si conoces SQL) | Media | Alta |
| **Ideal para** | Transformaciones, filtros, agregaciones simples | Lógica compleja, topologías custom | Procesamiento masivo, exactly-once avanzado |
| **Integración con Schema Registry** | Nativa y automática | Manual (configurar serdes) | Manual |

Para las reglas de esta tarea (filtros con `WHERE` y agregaciones con `GROUP BY`), ksqlDB es la herramienta más directa. No necesitamos compilar código, crear JARs ni desplegar aplicaciones — todo se hace con sentencias SQL.

### Arquitectura del Procesamiento

```
┌─────────────────────┐
│  sensor-telemetry   │  (topic Kafka, Avro, ~1 msg/s del Datagen)
│  ┌───────────────┐  │
│  │ temp: 38.2    │──┼──────┐
│  │ hum:  45.1    │  │      │
│  └───────────────┘  │      │
│  ┌───────────────┐  │      │
│  │ temp: 22.8    │──┼──┐   │
│  │ hum:  12.4    │  │  │   │
│  └───────────────┘  │  │   │
└─────────────────────┘  │   │
                         │   │
              ksqlDB     │   │
         ┌───────────────┘   │
         │                   │
         ▼                   ▼
   ┌──────────┐      ┌──────────────┐
   │ WHERE    │      │ WHERE        │
   │ hum < 20 │      │ temp > 35    │
   └────┬─────┘      └──────┬───────┘
        │                    │
        │  INSERT INTO       │  CSAS
        ▼                    ▼
   ┌──────────────────────────────┐
   │        sensor-alerts          │  (topic Kafka, JSON)
   │  ┌────────────────────────┐  │
   │  │ LOW_HUMIDITY: 12.4%    │  │
   │  │ HIGH_TEMPERATURE: 38.2°│  │
   │  └────────────────────────┘  │
   └──────────────────────────────┘
```

### Los Queries de ksqlDB: Explicación Detallada

Los ficheros SQL están en `ksqldb/task3-sensor-alerts.sql`. Vamos statement por statement.

#### Statement 1: Crear el STREAM de entrada

```sql
CREATE STREAM IF NOT EXISTS sensor_telemetry (
    sensor_id      VARCHAR KEY,
    `timestamp`    BIGINT,
    temperature    DOUBLE,
    humidity       DOUBLE,
    soil_fertility DOUBLE
) WITH (
    KAFKA_TOPIC  = 'sensor-telemetry',
    VALUE_FORMAT = 'AVRO',
    KEY_FORMAT   = 'KAFKA'
);
```

**¿Qué hace?** Declara una abstracción de streaming sobre el topic `sensor-telemetry`. No mueve datos ni crea nada nuevo — simplemente le dice a ksqlDB cómo interpretar los mensajes del topic.

**Conceptos clave:**

- **STREAM vs TABLE**: un STREAM es una secuencia inmutable de eventos (append-only). Cada mensaje de sensor es un evento nuevo, no una actualización de uno anterior. Por eso usamos STREAM y no TABLE.

- **`sensor_id VARCHAR KEY`**: el campo `sensor_id` es la key del mensaje Kafka. Recordemos que en la Tarea 1 configuramos `"schema.keyfield": "sensor_id"` en el Datagen, así que cada mensaje tiene `sensor_id` como key.

- **`` `timestamp` ``** (con backticks): `timestamp` es una palabra reservada en ksqlDB (referencia al ROWTIME del mensaje). Los backticks la escapan para referirnos a nuestro campo del schema, no al ROWTIME.

- **`VALUE_FORMAT = 'AVRO'`**: le dice a ksqlDB que los valores están en Avro. ksqlDB obtiene el schema del Schema Registry automáticamente. Podríamos omitir la declaración de campos y dejar que ksqlDB los infiera, pero declararlos explícitamente da mayor control y documentación.

- **`KEY_FORMAT = 'KAFKA'`**: formato por defecto para keys en Kafka Connect. Indica que la key es un string serializado con el serializador nativo de Kafka (no Avro).

#### Statement 2: Crear el STREAM de alertas (CSAS)

```sql
CREATE STREAM IF NOT EXISTS sensor_alerts_high_temp
WITH (
    KAFKA_TOPIC  = 'sensor-alerts',
    VALUE_FORMAT = 'JSON',
    PARTITIONS   = 3
) AS
SELECT
    sensor_id,
    'HIGH_TEMPERATURE' AS alert_type,
    `timestamp`        AS `timestamp`,
    'Temperature exceeded 35°C (actual: '
        + CAST(ROUND(temperature * 100.0) / 100.0 AS VARCHAR)
        + '°C)' AS details
FROM sensor_telemetry
WHERE temperature > 35.0
EMIT CHANGES;
```

**¿Qué hace?** Crea una **persistent query** — una transformación que se ejecuta continuamente en background. Por cada mensaje nuevo en `sensor_telemetry` donde `temperature > 35.0`, genera un mensaje de alerta y lo escribe en el topic `sensor-alerts`.

**Conceptos clave:**

- **CSAS (CREATE STREAM AS SELECT)**: es la forma en que ksqlDB crea pipelines de procesamiento continuo. A diferencia de un `SELECT` normal (que muestra resultados y termina), un CSAS:
  1. Crea un nuevo topic en Kafka (`sensor-alerts`)
  2. Despliega una query persistente que se ejecuta indefinidamente
  3. Cada evento nuevo que cumpla el `WHERE` genera un mensaje en el topic destino

- **`VALUE_FORMAT = 'JSON'`**: escribimos las alertas en JSON en lugar de Avro. Esto simplifica la integración con MongoDB (Tarea 5) y hace las alertas más legibles para debugging.

- **`PARTITIONS = 3`**: número de particiones del topic `sensor-alerts`. Lo especificamos para que coincida con los demás topics del proyecto.

- **`CAST(ROUND(temperature * 100.0) / 100.0 AS VARCHAR)`**: redondea la temperatura a 2 decimales para el campo `details`. El truco `ROUND(x * 100) / 100` es necesario porque ksqlDB no tiene una función `ROUND(x, decimals)`.

- **`EMIT CHANGES`**: obligatorio en ksqlDB para queries sobre streams. Indica que los resultados se emiten conforme llegan nuevos eventos (push query semántica).

#### Statement 3: INSERT INTO para LOW_HUMIDITY

```sql
INSERT INTO sensor_alerts_high_temp
SELECT
    sensor_id,
    'LOW_HUMIDITY' AS alert_type,
    `timestamp`    AS `timestamp`,
    'Humidity below 20% (actual: '
        + CAST(ROUND(humidity * 100.0) / 100.0 AS VARCHAR)
        + '%)' AS details
FROM sensor_telemetry
WHERE humidity < 20.0
EMIT CHANGES;
```

**¿Qué hace?** Crea una **segunda persistent query** que también escribe en el mismo topic `sensor-alerts`, pero para condiciones de baja humedad.

**¿Por qué INSERT INTO y no otro CSAS?**

No se pueden crear dos streams con el mismo `KAFKA_TOPIC`. El topic `sensor-alerts` ya fue creado por el CSAS anterior. La forma correcta de añadir más datos al mismo topic desde una query diferente es `INSERT INTO <stream_existente>`.

**¿Qué pasa si un evento cumple AMBAS condiciones?** (temperatura > 35 y humedad < 20)

Se generan **dos alertas separadas** — una `HIGH_TEMPERATURE` y una `LOW_HUMIDITY`. Esto es intencional y consistente con sistemas de monitorización reales donde cada condición anómala tiene su propia alerta, su propia severidad y su propio tratamiento.

### Paso a Paso: Ejecución

#### 1. Prerequisito: Tarea 1 activa

El Datagen connector debe estar produciendo datos en `sensor-telemetry`. Verifica con:

```bash
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic sensor-telemetry --time -1
```

#### 2. Ejecutar el setup automatizado

```bash
./scripts/setup-task3.sh
```

El script envía los statements a ksqlDB vía su API REST y verifica que las alertas se generan.

#### 3. Alternativamente, ejecutar manualmente en ksqlDB CLI

```bash
# Abrir el CLI de ksqlDB
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

Luego pegar cada statement del fichero `ksqldb/task3-sensor-alerts.sql` uno por uno.

#### 4. Verificar en ksqlDB CLI

```sql
-- Ver streams creados
SHOW STREAMS;

-- Ver queries persistentes activas
SHOW QUERIES;

-- Ver alertas en tiempo real (Ctrl+C para detener)
SELECT * FROM SENSOR_ALERTS_HIGH_TEMP EMIT CHANGES;
```

### Verificación y Validación

#### Consumir alertas del topic

```bash
# Las alertas están en JSON, así que kafka-console-consumer las muestra legibles
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-alerts \
  --from-beginning \
  --max-messages 10
```

Salida esperada:
```json
{"SENSOR_ID":"sensor_003","ALERT_TYPE":"HIGH_TEMPERATURE","timestamp":1704067200000,"DETAILS":"Temperature exceeded 35°C (actual: 38.21°C)"}
{"SENSOR_ID":"sensor_007","ALERT_TYPE":"LOW_HUMIDITY","timestamp":1704067205000,"DETAILS":"Humidity below 20% (actual: 12.43%)"}
{"SENSOR_ID":"sensor_001","ALERT_TYPE":"HIGH_TEMPERATURE","timestamp":1704067215000,"DETAILS":"Temperature exceeded 35°C (actual: 42.67°C)"}
```

**Nota:** los nombres de campo aparecen en MAYÚSCULAS. Esto es comportamiento por defecto de ksqlDB — convierte los identificadores a uppercase. No afecta la funcionalidad pero es algo a tener en cuenta si tu consumidor downstream es case-sensitive.

#### Verificar queries activas

```bash
curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json" \
  -d '{"ksql": "SHOW QUERIES;"}' | python3 -m json.tool
```

Debes ver 2 queries con estado `RUNNING`:
- Una para `HIGH_TEMPERATURE` (el CSAS)
- Una para `LOW_HUMIDITY` (el INSERT INTO)

#### Conteo de alertas

```bash
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic sensor-alerts \
  --time -1
```

Dado los rangos del Datagen (~28% de lecturas con temp > 35 y ~20% con humedad < 20), después de unos minutos deberías ver un flujo constante de alertas, aproximadamente 40-50% de los eventos generan al menos una alerta.

#### Kafka UI

En http://localhost:8080 → topic `sensor-alerts` → Messages: puedes ver las alertas formateadas en JSON en tiempo real.

---

## 📊 Tarea 4: Procesamiento de Ventas con ksqlDB

### Contexto y Objetivo

Las transacciones de ventas de FarmIA fluyen al topic `sales-transactions` desde MySQL (Tarea 2). El negocio necesita un resumen en tiempo real de los ingresos por categoría de producto para tomar decisiones rápidas: ¿qué se está vendiendo más ahora?, ¿hay un pico de demanda en fertilizantes?

La solución agrega las ventas en ventanas de 1 minuto, calcula totales y publica los resúmenes.

**Input:** topic `sales-transactions` (Avro)
**Output:** topic `sales-summary` (JSON)

**Formato de salida esperado:**
```json
{
  "category": "fertilizers",
  "total_quantity": 20,
  "total_revenue": 1000.0,
  "window_start": 1673548200000,
  "window_end": 1673548260000
}
```

### Conceptos Clave: Windowed Aggregations

Esta tarea es el corazón del procesamiento streaming y requiere entender tres conceptos fundamentales.

#### 1. Tumbling Window vs Hopping Window vs Session Window

```
Tumbling (SIZE 1 MINUTE) — la que usamos
──────────────────────────────────────────────────────────
|  ventana 1  |  ventana 2  |  ventana 3  |  ventana 4  |
| 12:00-12:01 | 12:01-12:02 | 12:02-12:03 | 12:03-12:04 |
──────────────────────────────────────────────────────────
• Ventanas fijas, sin solapamiento
• Cada evento pertenece a exactamente una ventana
• Ideal para reportes periódicos: "ventas por minuto"

Hopping (SIZE 1 MINUTE, ADVANCE BY 30 SECONDS)
──────────────────────────────────────────────────────────
|  ventana 1: 12:00-12:01  |
      |  ventana 2: 12:00:30-12:01:30  |
            |  ventana 3: 12:01-12:02  |
──────────────────────────────────────────────────────────
• Ventanas que se solapan
• Un evento puede pertenecer a múltiples ventanas
• Ideal para promedios móviles: "media de los últimos 5 min, actualizada cada minuto"

Session (INACTIVITY GAP 5 MINUTES)
──────────────────────────────────────────────────────────
|  sesión 1 (actividad continua)  |   gap   |  sesión 2  |
──────────────────────────────────────────────────────────
• Ventanas dinámicas basadas en actividad
• Se cierra cuando no hay eventos durante el gap
• Ideal para sesiones de usuario: "duración de sesión de compra"
```

Para esta tarea, **Tumbling** es la opción correcta: queremos un total fijo cada minuto, sin solapamiento ni ambigüedad.

#### 2. Event Time vs Processing Time

```
Evento de venta creado a las 12:00:45 (event time = timestamp en MySQL)
    ↓
    [MySQL] → [JDBC Connector poll cada 5s] → [Kafka] → [ksqlDB]
    ↓                                                      ↓
    12:00:45                                            12:00:52
    (event time)                                     (processing time)
```

Si usáramos processing time (ROWTIME), el evento se contaría en la ventana 12:00-12:01 **o** 12:01-12:02 dependiendo de la latencia del JDBC connector. Usando event time (el campo `timestamp`), siempre se cuenta en la ventana correcta: 12:00-12:01.

Por eso configuramos `TIMESTAMP = 'timestamp'` en el stream — le dice a ksqlDB que use nuestro campo como event time.

#### 3. Grace Period

```
Ventana 12:00-12:01 cierra a las 12:01:00
    ↓
    Grace period de 30 segundos
    ↓
Eventos con timestamp 12:00:XX que lleguen hasta las 12:01:30
se aceptan y se cuentan en la ventana 12:00-12:01
    ↓
Después de 12:01:30, eventos tardíos para esa ventana se descartan
```

En un entorno real, los eventos pueden llegar desordenados (red, retransmisiones, batching del JDBC connector). El `GRACE PERIOD 30 SECONDS` da un margen para eventos tardíos. Sin él, cualquier evento que llegue después de que la ventana cierre se perdería.

### Los Queries de ksqlDB: Explicación Detallada

Los ficheros SQL están en `ksqldb/task4-sales-summary.sql`.

#### Statement 1: Crear el STREAM de entrada

```sql
CREATE STREAM IF NOT EXISTS sales_transactions (
    transaction_id  VARCHAR,
    `timestamp`     BIGINT,
    product_id      VARCHAR,
    category        VARCHAR,
    quantity        INT,
    price           DOUBLE,
    _kafka_topic    VARCHAR,
    _kafka_partition INT
) WITH (
    KAFKA_TOPIC  = 'sales-transactions',
    VALUE_FORMAT = 'AVRO',
    TIMESTAMP    = 'timestamp'
);
```

**Puntos importantes:**

- **`TIMESTAMP = 'timestamp'`**: esta es la cláusula más importante del statement. Le dice a ksqlDB que el event time de cada mensaje es el valor del campo `timestamp` (epoch millis del momento de la venta). Sin esto, ksqlDB usaría ROWTIME (cuando Kafka recibió el mensaje), y las ventanas no se alinearían con el momento real de la venta.

- **No hay KEY**: a diferencia del stream de sensores (que tenía `sensor_id` como key), el JDBC connector no produce message keys por defecto (la key es null). Esto no es un problema porque la agregación agrupa por `category`, no por key.

- **Sin `id` ni `updated_at`**: las SMTs del JDBC connector (Tarea 2) eliminan estos campos técnicos antes de publicar en Kafka. El stream solo declara los campos que realmente llegan al topic.

- **`_kafka_topic` y `_kafka_partition`**: campos de metadata inyectados por las SMTs `InsertField`. Los declaramos en el stream para que ksqlDB los reconozca, aunque no los usamos en la agregación. Están disponibles para trazabilidad si se necesitan.

#### Statement 2: Tabla agregada con TUMBLING WINDOW

```sql
CREATE TABLE IF NOT EXISTS sales_summary
WITH (
    KAFKA_TOPIC  = 'sales-summary',
    VALUE_FORMAT = 'JSON',
    PARTITIONS   = 3
) AS
SELECT
    category                              AS category,
    SUM(quantity)                          AS total_quantity,
    ROUND(SUM(CAST(quantity AS DOUBLE) * price) * 100.0) / 100.0
                                          AS total_revenue,
    WINDOWSTART                           AS window_start,
    WINDOWEND                             AS window_end
FROM sales_transactions
    WINDOW TUMBLING (SIZE 1 MINUTE, GRACE PERIOD 30 SECONDS)
GROUP BY category
EMIT CHANGES;
```

**¿Por qué TABLE y no STREAM?**

Un `GROUP BY` en ksqlDB siempre produce una **TABLE**. La razón conceptual es que una agregación mantiene estado: el total de ventas de "fertilizers" en la ventana 12:00-12:01 es un valor que se **actualiza** conforme llegan más ventas de esa categoría en ese minuto. Esto es una vista materializada (TABLE), no una secuencia inmutable (STREAM).

**¿Qué pasa con los mensajes intermedios?**

Cada vez que llega una nueva venta de "fertilizers" dentro de una ventana activa, ksqlDB emite una **actualización** al topic `sales-summary`. Esto significa que puedes ver múltiples mensajes para la misma combinación categoría+ventana:

```json
// Llega la primera venta de fertilizers (qty=2, price=50)
{"CATEGORY":"fertilizers","TOTAL_QUANTITY":2,"TOTAL_REVENUE":100.0,"WINDOW_START":...,"WINDOW_END":...}

// Llega la segunda venta de fertilizers (qty=5, price=45)
{"CATEGORY":"fertilizers","TOTAL_QUANTITY":7,"TOTAL_REVENUE":325.0,"WINDOW_START":...,"WINDOW_END":...}
```

El último mensaje emitido para cada ventana es el valor final. Los consumidores downstream deben manejar esto (usar upsert por categoría+ventana, o solo procesar el último valor).

**`CAST(quantity AS DOUBLE) * price`**: quantity es INT y price es DOUBLE. Casteamos quantity a DOUBLE antes de multiplicar para evitar overflow y obtener precisión decimal en el resultado.

**`ROUND(... * 100.0) / 100.0`**: redondea el revenue a 2 decimales, igual que hicimos en la Tarea 3.

**`WINDOWSTART` / `WINDOWEND`**: pseudocolumnas de ksqlDB que contienen los límites de la ventana en epoch millis. No necesitan declararse — ksqlDB las genera automáticamente para queries windowed.

### Paso a Paso: Ejecución

#### 1. Prerequisito: datos en sales-transactions

El JDBC connector debe estar activo. Idealmente, lanza el simulador de ventas para generar datos frescos:

```bash
# En un terminal aparte
./scripts/simulate-sales.sh 1    # 1 venta por segundo
```

Esto es importante porque las ventanas de 1 minuto necesitan datos con timestamps **recientes** para producir output visible. Las 15 filas iniciales del `init.sql` tienen todas el mismo timestamp (el momento de creación del container) y se agregan en una sola ventana.

#### 2. Ejecutar el setup automatizado

```bash
./scripts/setup-task4.sh
```

El script crea el stream y la tabla, inserta 20 transacciones rápidas para generar datos, y verifica que los resúmenes aparecen en el topic.

#### 3. Ejecutar manualmente en ksqlDB CLI

```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

Pegar los statements de `ksqldb/task4-sales-summary.sql` uno por uno.

### Verificación y Validación

#### Consumir resúmenes del topic

```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sales-summary \
  --from-beginning \
  --max-messages 10
```

Salida esperada:
```json
{"CATEGORY":"fertilizers","TOTAL_QUANTITY":15,"TOTAL_REVENUE":725.0,"WINDOW_START":1710000060000,"WINDOW_END":1710000120000}
{"CATEGORY":"seeds","TOTAL_QUANTITY":25,"TOTAL_REVENUE":200.0,"WINDOW_START":1710000060000,"WINDOW_END":1710000120000}
{"CATEGORY":"tools","TOTAL_QUANTITY":4,"TOTAL_REVENUE":430.0,"WINDOW_START":1710000060000,"WINDOW_END":1710000120000}
```

#### Ver en ksqlDB CLI

```sql
-- Resúmenes en tiempo real
SELECT * FROM SALES_SUMMARY EMIT CHANGES;

-- Ver streams y tablas creados
SHOW STREAMS;
SHOW TABLES;

-- Ver todas las queries persistentes (Tarea 3 + Tarea 4)
SHOW QUERIES;
```

#### Verificar el flujo completo con el simulador

Para una demo convincente, abrir 3 terminales:

```bash
# Terminal 1: Simular ventas
./scripts/simulate-sales.sh 1

# Terminal 2: Ver resúmenes en ksqlDB
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
# > SELECT * FROM SALES_SUMMARY EMIT CHANGES;

# Terminal 3: Consumir el topic sales-summary
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sales-summary
```

Cada minuto se abrirá una nueva ventana, y verás los totales actualizarse por categoría conforme llegan ventas del simulador.

---

## 💾 Tarea 5: Integración de MongoDB con Kafka Connect

### Contexto y Objetivo

Las alertas de anomalías generadas por ksqlDB (Tarea 3) fluyen al topic `sensor-alerts`. Para que el equipo de operaciones de FarmIA pueda consultarlas, analizarlas históricamente y construir dashboards, necesitamos persistirlas en una base de datos. MongoDB es ideal para este caso: los documentos JSON de alertas se almacenan directamente sin necesidad de definir un esquema rígido.

**Input:** topic `sensor-alerts` (JSON, producido por ksqlDB en la Tarea 3)
**Output:** colección `sensor_alerts` en MongoDB (base de datos `farmia`)

### Source Connector vs Sink Connector

En las Tareas 1 y 2 usamos **Source Connectors** (datos entran a Kafka). Ahora usamos un **Sink Connector** (datos salen de Kafka):

```
Source Connectors (T1, T2)          Sink Connector (T5)
─────────────────────────           ─────────────────────
Sistema externo → Kafka             Kafka → Sistema externo

  [Datagen] → sensor-telemetry      sensor-alerts → [MongoDB]
  [MySQL]   → sales-transactions
```

El flujo completo cierra el ciclo:
```
Datagen → sensor-telemetry → ksqlDB (filtro) → sensor-alerts → MongoDB
```

### Configuración del MongoDB Sink Connector

El fichero está en `connectors/mongodb-sink-sensor-alerts.json`:

```json
{
  "name": "mongodb-sink-sensor-alerts",
  "config": {
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "connection.uri": "mongodb://root:mongopassword@mongodb:27017",
    "database": "farmia",
    "collection": "sensor_alerts",
    "topics": "sensor-alerts",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": false,
    "document.id.strategy": "...KafkaMetaDataStrategy",
    "writemodel.strategy": "...InsertOneDefaultStrategy",
    "errors.tolerance": "all",
    "errors.deadletterqueue.topic.name": "dlq-mongodb-sensor-alerts",
    "errors.deadletterqueue.topic.replication.factor": 1,
    "errors.deadletterqueue.context.headers.enable": true,
    "tasks.max": "1"
  }
}
```

#### Desglose de propiedades

| Propiedad | Valor | Explicación |
|---|---|---|
| `connector.class` | `MongoSinkConnector` | Connector oficial de MongoDB para Kafka. Instalado al arrancar Kafka Connect (`mongodb/kafka-connect-mongodb:1.13.1`). |
| `connection.uri` | `mongodb://root:mongopassword@mongodb:27017` | URI de conexión a MongoDB. `mongodb` es el hostname en la red Docker. Las credenciales coinciden con las variables del `.env`. |
| `database` | `farmia` | Base de datos destino. Se crea automáticamente si no existe (MongoDB es schemaless). |
| `collection` | `sensor_alerts` | Colección destino. También se crea automáticamente. |
| `topics` | `sensor-alerts` | Topic(s) de Kafka a consumir. Puede ser una lista separada por comas para múltiples topics. |
| `value.converter` | `JsonConverter` | Las alertas se escribieron en JSON en la Tarea 3 (`VALUE_FORMAT = 'JSON'`), así que usamos JsonConverter para deserializarlas. |
| `value.converter.schemas.enable` | `false` | Crítico: ksqlDB escribe JSON sin schema embebido (plain JSON, no JSON+Schema). Si dejamos `true`, el connector esperaría un envelope `{"schema":{...}, "payload":{...}}` y fallaría. |
| `document.id.strategy` | `KafkaMetaDataStrategy` | Cómo generar el `_id` de MongoDB. Esta estrategia usa `topic+partition+offset` como ID, lo que garantiza unicidad y permite reprocessing idempotente. |
| `writemodel.strategy` | `InsertOneDefaultStrategy` | Cada mensaje se inserta como un documento nuevo. Alternativas: `ReplaceOneDefaultStrategy` (upsert por `_id`), `UpdateOneDefaultStrategy` (actualización parcial). |
| `errors.tolerance` | `all` | Si un mensaje falla (e.g., JSON malformado), no detiene el connector. El mensaje se envía a la Dead Letter Queue. |
| `errors.deadletterqueue.topic.name` | `dlq-mongodb-sensor-alerts` | Topic donde van los mensajes que no se pudieron escribir en MongoDB. Permite investigar errores sin perder datos. |
| `errors.deadletterqueue.context.headers.enable` | `true` | Añade headers al mensaje DLQ con información del error (excepción, stack trace), facilitando el debugging. |

#### ¿Por qué `KafkaMetaDataStrategy` para el `_id`?

MongoDB requiere un campo `_id` único por documento. Las estrategias disponibles son:

| Estrategia | `_id` generado | Uso ideal |
|---|---|---|
| `BsonOidStrategy` (default) | ObjectId aleatorio | Documentos sin identidad natural |
| `KafkaMetaDataStrategy` | `topic+partition+offset` | **Idempotencia**: si reprocesas el topic, no crea duplicados |
| `ProvidedInValueStrategy` | Campo del mensaje (e.g., `sensor_id`) | Cuando el mensaje tiene un ID natural único |
| `UuidStrategy` | UUID aleatorio | Similar a BsonOid pero con formato UUID |

Elegimos `KafkaMetaDataStrategy` porque:
1. Nuestras alertas no tienen un ID natural único (múltiples alertas del mismo sensor)
2. Garantiza **idempotencia**: si el connector se reinicia y reprocesa mensajes, el `_id` basado en offset evita duplicados
3. Permite traceabilidad: desde un documento en MongoDB puedes encontrar el mensaje original en Kafka

#### ¿Por qué `value.converter.schemas.enable = false`?

Este es el error más común al configurar un MongoDB Sink Connector con datos de ksqlDB. Veamos por qué:

ksqlDB con `VALUE_FORMAT = 'JSON'` produce mensajes como:
```json
{"SENSOR_ID":"sensor_003","ALERT_TYPE":"HIGH_TEMPERATURE","timestamp":1704067200000,"DETAILS":"Temperature exceeded 35°C (actual: 38.21°C)"}
```

Con `schemas.enable = true`, el JsonConverter esperaría:
```json
{
  "schema": {"type": "struct", "fields": [...]},
  "payload": {"SENSOR_ID": "sensor_003", ...}
}
```

Como ksqlDB produce plain JSON (sin el envelope schema+payload), debemos poner `schemas.enable = false`. Si no, el connector falla con un error de deserialización y los mensajes van a la Dead Letter Queue.

### Paso a Paso: Ejecución

#### 1. Prerequisitos: Tareas 1 y 3 activas

El Datagen debe estar produciendo datos y ksqlDB generando alertas:

```bash
# Verificar alertas en el topic
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic sensor-alerts --time -1
```

#### 2. Ejecutar el setup automatizado

```bash
./scripts/setup-task5.sh
```

El script verifica MongoDB, registra el sink connector, espera a que procese mensajes, y muestra los documentos insertados.

#### 3. Alternativamente, hacerlo manualmente

```bash
# Registrar el connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connectors/mongodb-sink-sensor-alerts.json
```

### Verificación y Validación

#### Estado del connector

```bash
curl http://localhost:8083/connectors/mongodb-sink-sensor-alerts/status | python3 -m json.tool
```

Respuesta esperada:
```json
{
    "name": "mongodb-sink-sensor-alerts",
    "connector": { "state": "RUNNING", "worker_id": "kafka-connect:8083" },
    "tasks": [
        { "id": 0, "state": "RUNNING", "worker_id": "kafka-connect:8083" }
    ]
}
```

#### Consultar documentos en MongoDB

```bash
docker exec -it mongodb mongosh -u root -p mongopassword
```

```javascript
// Seleccionar base de datos
use farmia

// Contar documentos
db.sensor_alerts.countDocuments()

// Ver los 5 más recientes
db.sensor_alerts.find().sort({_id: -1}).limit(5).pretty()

// Contar por tipo de alerta
db.sensor_alerts.aggregate([
    { $group: { _id: "$ALERT_TYPE", count: { $sum: 1 } } },
    { $sort: { count: -1 } }
])

// Buscar alertas de un sensor específico
db.sensor_alerts.find({ SENSOR_ID: "sensor_003" }).limit(5).pretty()

// Alertas de temperatura en las últimas 24 horas (si el timestamp es reciente)
db.sensor_alerts.find({
    ALERT_TYPE: "HIGH_TEMPERATURE",
    timestamp: { $gt: Date.now() - 86400000 }
}).count()
```

Ejemplo de documento en MongoDB:
```json
{
    "_id": "sensor-alerts+0+42",
    "SENSOR_ID": "sensor_003",
    "ALERT_TYPE": "HIGH_TEMPERATURE",
    "timestamp": 1704067200000,
    "DETAILS": "Temperature exceeded 35°C (actual: 38.21°C)"
}
```

Observa que:
- El `_id` es `topic+partition+offset` (KafkaMetaDataStrategy)
- Los campos están en MAYÚSCULAS (herencia de ksqlDB)
- El documento es un mapeo directo del JSON del topic

#### Verificar la Dead Letter Queue

```bash
# Si todo va bien, debe estar vacío
docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list kafka:29092 \
  --topic dlq-mongodb-sensor-alerts \
  --time -1
```

Si hay mensajes en la DLQ, consúmelos para ver los errores:
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic dlq-mongodb-sensor-alerts \
  --from-beginning \
  --property print.headers=true \
  --max-messages 3
```

#### Verificar flujo continuo

El sink connector consume continuamente. Mientras el Datagen y ksqlDB estén activos, nuevas alertas aparecerán en MongoDB automáticamente:

```bash
# Terminal 1: Observar conteo creciente en MongoDB
watch -n 5 'docker exec mongodb mongosh --quiet -u root -p mongopassword \
  --eval "db = db.getSiblingDB(\"farmia\"); print(db.sensor_alerts.countDocuments());"'

# Terminal 2: Ver alertas llegando al topic
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-alerts
```

---

## 🚀 Ejecución Completa del Pipeline

Para ejecutar las 5 tareas en secuencia con un solo comando:

```bash
# 1. Levantar infraestructura
docker compose --env-file config/.env up -d

# 2. Esperar ~2 minutos a que Kafka Connect arranque

# 3. Ejecutar todas las tareas
./scripts/setup-all.sh
```

El script `setup-all.sh` ejecuta los 5 scripts de setup en orden, respetando dependencias.

### Verificación del Pipeline Completo

Una vez ejecutado, abre estas URLs y herramientas:

| Servicio | URL / Comando | Qué verificar |
|---|---|---|
| **Kafka UI** | http://localhost:8080 | Topics, mensajes, schemas, connectors |
| **ksqlDB CLI** | `docker exec -it ksqldb-cli ksql http://ksqldb-server:8088` | Streams, tables, queries activas |
| **MongoDB** | `docker exec -it mongodb mongosh -u root -p mongopassword` | Documentos en `farmia.sensor_alerts` |
| **MySQL** | `docker exec -it mysql mysql -u farmia_user -pfarmia_password farmia` | Datos en tabla `transactions` |

### Orden de Dependencias

```
T1 (Datagen) ──────────────────────────→ T3 (ksqlDB alerts) ──→ T5 (MongoDB Sink)
T2 (JDBC MySQL) ──→ T4 (ksqlDB sales)
```

Las tareas 1→3→5 forman la cadena de sensores. Las tareas 2→4 forman la cadena de ventas. Ambas cadenas son independientes entre sí.

---

## 🧪 Comandos Útiles

```bash
# ─── Docker ────────────────────────────────────────────────────────────────
docker compose --env-file config/.env up -d          # Levantar todo
docker compose --env-file config/.env down            # Parar todo
docker compose --env-file config/.env down -v         # Reset completo (borra datos)
docker compose logs kafka-connect -f                  # Logs de Connect en tiempo real

# ─── Topics ────────────────────────────────────────────────────────────────
docker exec kafka kafka-topics --list --bootstrap-server kafka:29092
docker exec kafka kafka-topics --describe --topic sensor-telemetry --bootstrap-server kafka:29092

# ─── Consumir mensajes ─────────────────────────────────────────────────────
# Formato plano (Avro = bytes ilegibles)
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-telemetry \
  --from-beginning --max-messages 5

# Formato deserializado (Avro → JSON legible)
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic sensor-telemetry \
  --from-beginning --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081

# ─── Schema Registry ──────────────────────────────────────────────────────
curl http://localhost:8081/subjects | python3 -m json.tool
curl http://localhost:8081/subjects/sensor-telemetry-value/versions/latest | python3 -m json.tool

# ─── Kafka Connect ────────────────────────────────────────────────────────
curl http://localhost:8083/connectors | python3 -m json.tool
curl http://localhost:8083/connectors/datagen-sensor-telemetry/status | python3 -m json.tool

# ─── ksqlDB ───────────────────────────────────────────────────────────────
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088

# ─── MySQL ────────────────────────────────────────────────────────────────
docker exec -it mysql mysql -u farmia_user -pfarmia_password farmia

# ─── MongoDB ──────────────────────────────────────────────────────────────
docker exec -it mongodb mongosh -u root -p mongopassword
```

---

## 📚 Conceptos Clave por Componente

### Kafka Connect

Kafka Connect es un framework para mover datos entre Kafka y sistemas externos sin escribir código. Funciona con **conectores** (plugins) que implementan la lógica de integración.

- **Source Connector**: sistema externo → Kafka (e.g., Datagen, JDBC, Debezium)
- **Sink Connector**: Kafka → sistema externo (e.g., MongoDB, S3, BigQuery)
- **Task**: unidad de paralelismo dentro de un connector
- **Worker**: proceso JVM que ejecuta los tasks

La API REST en el puerto 8083 permite gestionar conectores dinámicamente (crear, pausar, eliminar, ver estado).

### Schema Registry + Avro

Avro es un formato de serialización binario que requiere un schema para leer y escribir datos. Schema Registry centraliza estos schemas y asegura que productores y consumidores sean compatibles.

El flujo es:
1. El producer (Datagen) serializa un mensaje con Avro
2. Antes de enviar, consulta/registra el schema en Schema Registry
3. El mensaje en Kafka lleva un ID de schema (5 bytes) + datos binarios
4. El consumer lee el ID, obtiene el schema del Registry, y deserializa

Esto permite **evolución de schemas** — puedes añadir campos sin romper consumidores existentes.

### Datagen Source Connector

Connector específico de Confluent para generar datos de prueba. Lee un schema Avro con anotaciones `arg.properties` que controlan la generación:

- `options`: valores fijos aleatorios
- `range`: números entre min/max
- `iteration`: secuencia incremental
- `regex`: cadenas que cumplen un patrón

Es la forma estándar de simular fuentes de datos en entornos de desarrollo y testing con el ecosistema Confluent.
