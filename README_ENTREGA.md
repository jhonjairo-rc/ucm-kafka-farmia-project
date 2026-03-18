# FarmIA Kafka Pipeline

**Pipeline de streaming para sensores agrícolas IoT y ventas en línea**

Máster NTIC — Universidad Complutense de Madrid
Asignatura: Kafka y Procesamiento en Tiempo Real

---

## Índice

1. [Descripción del Proyecto](#descripción-del-proyecto)
2. [Arquitectura General](#arquitectura-general)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Requisitos Previos](#requisitos-previos)
5. [Tarea 1: Generación de Datos Sintéticos con Datagen](#tarea-1-generación-de-datos-sintéticos-con-datagen)
   - [Contexto y Objetivo](#contexto-y-objetivo)
   - [¿Qué es el Datagen Source Connector?](#qué-es-el-datagen-source-connector)
   - [Schema Avro: Diseño y Decisiones](#schema-avro-diseño-y-decisiones)
   - [Configuración del Connector](#configuración-del-connector)
   - [¿Cómo llega el schema al container?](#cómo-llega-el-schema-al-container)
   - [Verificación y Validación](#verificación-y-validación)
6. [Tarea 2: Integración de MySQL con Kafka Connect](#tarea-2-integración-de-mysql-con-kafka-connect)
   - [Contexto y Objetivo](#contexto-y-objetivo-1)
   - [Diseño de la Tabla MySQL](#diseño-de-la-tabla-mysql)
   - [Configuración del JDBC Source Connector](#configuración-del-jdbc-source-connector)
   - [Modo `timestamp` en detalle](#modo-timestamp-en-detalle)
   - [SMTs (Single Message Transforms)](#smts-single-message-transforms)
   - [¿Cómo se genera el nombre del topic?](#cómo-se-genera-el-nombre-del-topic)
   - [Verificación y Validación](#verificación-y-validación-1)
7. [Tarea 3: Procesamiento de Sensores con ksqlDB](#tarea-3-procesamiento-de-sensores-con-ksqldb)
   - [Contexto y Objetivo](#contexto-y-objetivo-2)
   - [¿Por qué ksqlDB?](#por-qué-ksqldb)
   - [Queries de ksqlDB: Explicación Detallada](#queries-de-ksqldb-explicación-detallada)
   - [Verificación y Validación](#verificación-y-validación-2)
8. [Tarea 4: Procesamiento de Ventas con ksqlDB](#tarea-4-procesamiento-de-ventas-con-ksqldb)
   - [Contexto y Objetivo](#contexto-y-objetivo-3)
   - [Conceptos Clave: Windowed Aggregations](#conceptos-clave-windowed-aggregations)
   - [Queries de ksqlDB: Explicación Detallada](#queries-de-ksqldb-explicación-detallada-1)
   - [Verificación y Validación](#verificación-y-validación-3)
9. [Tarea 5: Integración de MongoDB con Kafka Connect](#tarea-5-integración-de-mongodb-con-kafka-connect)
   - [Contexto y Objetivo](#contexto-y-objetivo-4)
   - [Configuración del MongoDB Sink Connector](#configuración-del-mongodb-sink-connector)
   - [Verificación y Validación](#verificación-y-validación-4)
10. [Ejecución Completa del Pipeline](#ejecución-completa-del-pipeline)
11. [Problemas Detectados y Soluciones](#problemas-detectados-y-soluciones)
    - [Problema: campo `price` ilegible en el topic `sales-transactions`](#problema-campo-price-ilegible-en-el-topic-sales-transactions)
    - [Ficheros modificados](#ficheros-modificados)
    - [Procedimiento de aplicación del fix](#procedimiento-de-aplicación-del-fix)
12. [Comandos Útiles](#comandos-útiles)

---

## Descripción del Proyecto

FarmIA es una empresa agrícola que integra sensores IoT en sus campos para monitorizar temperatura, humedad y fertilidad del suelo. Además, opera una plataforma de ventas en línea de productos agrícolas (fertilizantes, semillas, pesticidas, equipamiento, suministros, suelo).

Este proyecto construye un pipeline end-to-end con Apache Kafka que:

1. **Genera datos sintéticos** de sensores IoT usando Datagen Connector
2. **Captura transacciones de ventas** desde MySQL usando JDBC Source Connector
3. **Detecta anomalías** en los sensores (temperatura > 35°C o humedad < 20%) con ksqlDB
4. **Agrega ventas por categoría** en ventanas de 1 minuto con ksqlDB
5. **Persiste alertas** en MongoDB usando MongoDB Sink Connector

---

## Arquitectura General

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
│  │  Kafka Cluster KRaft (3 controllers + 3 brokers)          │         │
│  │  + Schema Registry + Control Center                       │         │
│  └───────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Diagrama de Flujo de Datos

```mermaid
%%{init: {'theme': 'neutral'}}%%
graph LR
    subgraph "Fuentes de Datos"
        DG1[Datagen: Sensores IoT]
        DG2[Datagen: Transacciones]
        MySQL[(MySQL)]
    end

    subgraph "Topics Kafka"
        T1[sensor-telemetry]
        T2[_transactions]
        T3[sales-transactions]
        T4[sensor-alerts]
        T5[sales-summary]
    end

    subgraph "Procesamiento ksqlDB"
        KS1[sensor_telemetry_stream]
        KS2[sensor_alerts_stream<br/>temp > 35 OR humidity < 20]
        KS3[sales_transactions_stream]
        KS4[sales_summary_table<br/>GROUP BY category<br/>WINDOW 1 MIN]
    end

    subgraph "Destinos"
        MongoDB[(MongoDB<br/>sensor_alerts)]
    end

    DG1 -->|Source Datagen| T1
    DG2 -->|Source Datagen| T2
    T2 -->|JDBC Sink| MySQL
    MySQL -->|JDBC Source| T3

    T1 --> KS1 --> KS2 --> T4
    T3 --> KS3 --> KS4 --> T5
    T4 -->|MongoDB Sink| MongoDB
```

### Diagrama de Interacción entre Servicios

```mermaid
sequenceDiagram
    participant DG as Datagen Connector
    participant KC as Kafka Connect
    participant K as Kafka Brokers
    participant SR as Schema Registry
    participant MySQL as MySQL
    participant KSQL as ksqlDB
    participant MongoDB as MongoDB

    Note over DG,MongoDB: Fase 1: Ingesta de datos
    DG->>KC: Genera datos sensores
    KC->>SR: Registra schema Avro
    KC->>K: Produce a sensor-telemetry
    DG->>KC: Genera transacciones
    KC->>K: Produce a _transactions
    KC->>MySQL: Escribe en sales_transactions
    KC->>K: Lee de MySQL, produce a sales-transactions

    Note over DG,MongoDB: Fase 2: Procesamiento ksqlDB
    KSQL->>K: Consume sensor-telemetry
    KSQL->>K: Filtra anomalías → sensor-alerts
    KSQL->>K: Consume sales-transactions
    KSQL->>K: Agrega por categoría → sales-summary

    Note over DG,MongoDB: Fase 3: Persistencia
    KC->>K: Consume sensor-alerts
    KC->>MongoDB: Escribe en colección sensor_alerts
```

### Infraestructura Docker

El entorno se compone de 13 contenedores definidos en `1.environment/docker-compose.yaml`:

| Servicio | Imagen | Puerto | Rol |
|---|---|---|---|
| controller-1/2/3 | `cp-kafka:7.8.0` | 9095-9097 | KRaft controllers (quorum de metadatos, reemplazan ZooKeeper) |
| broker-1/2/3 | `cp-kafka:7.8.0` | 9092-9094 | Kafka brokers (almacenan y sirven mensajes) |
| schema-registry | `cp-schema-registry:7.8.0` | 8081 | Registro centralizado de schemas Avro |
| connect | `cp-kafka-connect:7.8.0` | 8083 | Ejecuta los connectors (source y sink) |
| ksqldb-server | `cp-ksqldb-server:7.8.0` | 8088 | Motor de procesamiento SQL sobre Kafka |
| ksqldb-cli | `cp-ksqldb-cli:7.8.0` | — | Cliente CLI para ejecutar queries ksqlDB |
| control-center | `cp-enterprise-control-center:7.8.0` | 9021 | UI web de monitorización de Confluent |
| mysql | `mysql:8.3` | 3306 | Base de datos relacional (transacciones de ventas) |
| mongodb | `mongo:8.0` | 27017 | Base de datos documental (alertas de sensores) |

**¿Por qué KRaft y no ZooKeeper?** A partir de Kafka 3.3+, KRaft es el modo recomendado. Elimina la dependencia de ZooKeeper para la gestión de metadatos del cluster, simplificando la arquitectura y mejorando la latencia de los cambios de metadatos (elección de líder, creación de topics, etc.).

**¿Por qué 3 controllers y 3 brokers?** Para simular un entorno productivo con alta disponibilidad. Con 3 controllers, el quorum soporta la caída de 1 controller. Con 3 brokers, podemos usar replication-factor 3 para los topics, tolerando la pérdida de hasta 2 réplicas.

---

## Estructura del Proyecto

```
ucm-farmia/
├── 0.tarea/                                    # Directorio principal de la tarea
│   ├── connectors/                             # Configuraciones de Kafka Connect (JSON)
│   │   ├── source-datagen-_transactions.json   # (proporcionado) Genera transacciones → _transactions
│   │   ├── sink-mysql-_transactions.json       # (proporcionado) Escribe _transactions → MySQL
│   │   ├── source-datagen-sensor-telemetry.json    # Tarea 1: Genera datos IoT → sensor-telemetry
│   │   ├── source-mysql-sales_transactions.json    # Tarea 2: Lee MySQL → sales-transactions
│   │   └── sink-mongodb-sensor_alerts.json         # Tarea 5: Escribe alertas → MongoDB
│   ├── datagen/                                # Schemas Avro para Datagen
│   │   ├── sensor-telemetry.avsc               # Schema de sensores IoT (Tarea 1)
│   │   └── transactions.avsc                   # Schema de transacciones (proporcionado)
│   ├── ksqldb/                                 # Procesamiento streaming
│   │   ├── 01-sensor-alerts.sql                # Tarea 3: Detección de anomalías
│   │   ├── 02-sales-summary.sql                # Tarea 4: Agregación de ventas
│   │   └── run-ksqldb.sh                       # Ejecuta ambos .sql vía ksqldb-cli
│   ├── topics/
│   │   └── create-topics.sh                    # Crea los 4 topics (3 particiones, RF=3)
│   ├── validation/
│   │   └── validate.sh                         # Validación end-to-end del pipeline
│   ├── sql/
│   │   └── transactions.sql                    # DDL de la tabla sales_transactions (NO MODIFICAR)
│   ├── src/                                    # Stubs Java vacíos — NO UTILIZAR
│   ├── setup.sh                                # Setup completo del entorno
│   ├── start_connectors.sh                     # Lanza los 5 conectores
│   └── shutdown.sh                             # Detiene el entorno
├── 1.environment/                              # Infraestructura Docker
│   ├── docker-compose.yaml                     # 13 servicios: controllers, brokers, connect, ksqldb, etc.
│   ├── .env                                    # TAG=7.8.0, CLUSTER_ID
│   └── mysql/
│       ├── init.sql                            # Inicialización de MySQL (usuario, permisos)
│       └── mysql-connector-java-5.1.45.jar     # Driver JDBC para MySQL
└── README.md
```

---

## Requisitos Previos

- **Docker** ≥ 24.0 y **Docker Compose** ≥ 2.20
- **curl** y **jq** (para interactuar con las APIs REST)
- ~8 GB de RAM disponible para Docker (los servicios Confluent son pesados)

---

## Tarea 1: Generación de Datos Sintéticos con Datagen

### Contexto y Objetivo

La primera tarea consiste en simular las lecturas de los sensores IoT que FarmIA tiene desplegados en sus campos agrícolas. En un entorno real, estos sensores enviarían datos directamente a Kafka a través de un producer (MQTT → Kafka, por ejemplo). En el lab, simulamos esta fuente de datos usando el **Datagen Source Connector**.

**Objetivo:** configurar un source connector que genere eventos continuos en el topic `sensor-telemetry` con datos realistas de sensores (temperatura, humedad, fertilidad del suelo).

**Output:** topic Kafka `sensor-telemetry` con mensajes serializados en Avro.

### ¿Qué es el Datagen Source Connector?

El Datagen Source Connector (`io.confluent.kafka.connect.datagen.DatagenConnector`) es un connector de Confluent diseñado para generar datos sintéticos. Funciona dentro de Kafka Connect y produce mensajes a un topic de Kafka a un ritmo configurable.

**¿Por qué Datagen y no un producer Python?**

- Datagen se ejecuta dentro de Kafka Connect, por lo que aprovecha toda su infraestructura: tolerancia a fallos, monitorización, gestión de offsets y serialización Avro nativa.
- No necesitas escribir código — solo un schema Avro y una configuración JSON.
- En un entorno de evaluación, demuestra dominio de Kafka Connect como framework.

**¿Cómo genera datos?**

Datagen lee un schema Avro que incluye anotaciones especiales en `arg.properties`. Estas anotaciones le dicen al connector cómo generar el valor de cada campo:
- `options`: elige aleatoriamente de una lista de valores fijos
- `range`: genera un número aleatorio entre `min` y `max`
- `iteration`: genera valores incrementales con un `start` y un `step`

### Schema Avro: Diseño y Decisiones

El schema se encuentra en `0.tarea/datagen/sensor-telemetry.avsc`.

```json
{
  "namespace": "com.farmia.iot",
  "name": "SensorTelemetry",
  "type": "record",
  "fields": [
    {
      "name": "sensor_id",
      "type": {
        "type": "string",
        "arg.properties": {
          "options": ["sensor_001", "sensor_002", ..., "sensor_010"]
        }
      }
    },
    {
      "name": "timestamp",
      "type": {
        "type": "long",
        "arg.properties": {
          "iteration": { "start": 1767225600000, "step": 1000 }
        }
      }
    },
    {
      "name": "temperature",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 15.0, "max": 45.0 } }
      }
    },
    {
      "name": "humidity",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 10.0, "max": 80.0 } }
      }
    },
    {
      "name": "soil_fertility",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 20.0, "max": 100.0 } }
      }
    }
  ]
}
```

#### Decisiones de diseño clave

**1. Rangos de `temperature` (15.0 - 45.0) y `humidity` (10.0 - 80.0)**

Las reglas de anomalía de la Tarea 3 son: temperatura > 35°C o humedad < 20%. Si los rangos fueran demasiado estrechos (e.g., 20-30°C), nunca generaríamos anomalías. Si fueran demasiado extremos, todas las lecturas serían anómalas. Con estos rangos:

- **Temperatura:** el rango 15-45 hace que ~33% de las lecturas superen los 35°C → `(45-35)/(45-15) = 33%`
- **Humedad:** el rango 10-80 hace que ~14% de las lecturas caigan por debajo de 20% → `(20-10)/(80-10) = 14%`

Esto asegura un flujo constante de alertas sin saturar el sistema — ideal para verificar que el procesamiento funciona en la Tarea 3.

**2. `sensor_id` con 10 sensores fijos**

Usar `options` en lugar de un generador aleatorio simula un escenario realista: FarmIA tiene un número finito de sensores desplegados. Esto también permite hacer análisis por sensor (e.g., "¿qué sensor genera más alertas?") y particionar por `sensor_id` como key del mensaje.

**3. `timestamp` con `iteration`**

El campo `iteration` genera timestamps incrementales (cada 1 segundo), simulando lecturas periódicas del sensor. El `start` (1767225600000) corresponde al 1 de enero de 2026. En un entorno real, usaríamos el timestamp del sistema, pero `iteration` es lo que Datagen soporta para campos long con secuencia controlada.

**4. `soil_fertility` como campo informativo**

El enunciado incluye este campo en la estructura pero no define reglas de anomalía para él. Lo mantenemos disponible con un rango realista (20-100) para futuras extensiones.

### Configuración del Connector

El fichero de configuración está en `0.tarea/connectors/source-datagen-sensor-telemetry.json`.

```json
{
  "name": "source-datagen-sensor-telemetry",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "sensor-telemetry",
    "schema.filename": "/home/appuser/sensor-telemetry.avsc",
    "schema.keyfield": "sensor_id",
    "max.interval": 1000,
    "iterations": 10000000,
    "tasks.max": "1",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter"
  }
}
```

#### Desglose de cada propiedad

| Propiedad | Valor | Explicación |
|---|---|---|
| `connector.class` | `DatagenConnector` | Clase Java del connector. Kafka Connect la carga desde el plugin path. |
| `kafka.topic` | `sensor-telemetry` | Topic destino donde se publican los eventos generados. |
| `schema.filename` | `/home/appuser/sensor-telemetry.avsc` | Ruta al schema Avro **dentro del container** `connect`. El fichero se copia ahí durante el `setup.sh` (ver siguiente sección). |
| `schema.keyfield` | `sensor_id` | Campo del schema que se usa como message key. Esto asegura que eventos del mismo sensor van a la misma partición (ordenamiento por sensor). |
| `max.interval` | `1000` | Intervalo máximo en ms entre mensajes. Con valor 1000, genera ~1 msg/segundo. |
| `iterations` | `10000000` | Número total de mensajes a generar. Suficiente para un lab de larga duración. |
| `tasks.max` | `1` | Un solo task es suficiente para un lab. En producción se usarían más para paralelismo. |
| `value.converter` | `AvroConverter` | El value se serializa en Avro binario antes de enviarse a Kafka. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL interna del Schema Registry (dentro de la red Docker). |
| `key.converter` | `StringConverter` | La key se serializa como string plano (el `sensor_id`). |

### ¿Cómo llega el schema al container?

A diferencia de un montaje por volumen, en este proyecto el schema se copia manualmente al container durante el setup. En el fichero `0.tarea/setup.sh`:

```bash
docker cp ../0.tarea/datagen/sensor-telemetry.avsc connect:/home/appuser/
```

Esto copia el fichero local `0.tarea/datagen/sensor-telemetry.avsc` a la ruta `/home/appuser/sensor-telemetry.avsc` dentro del container `connect`. Por eso en el connector configuramos `"schema.filename": "/home/appuser/sensor-telemetry.avsc"`.

**¿Por qué no un volumen Docker?** Se podría montar un volumen en el `docker-compose.yaml` para que el fichero estuviera disponible automáticamente sin necesidad del `docker cp`. Sería más limpio, pero el enfoque de copia manual es el patrón que sigue el proyecto base proporcionado por el profesor y funciona correctamente.

**Importante:** como el schema se copia y no se monta, si modificas el `.avsc` necesitas volver a ejecutar el `docker cp` y reiniciar el connector para que tome los cambios.

### Verificación y Validación

#### Verificar el connector

```bash
curl -s http://localhost:8083/connectors/source-datagen-sensor-telemetry/status | jq
```

Respuesta esperada:
```json
{
    "name": "source-datagen-sensor-telemetry",
    "connector": {
        "state": "RUNNING",
        "worker_id": "connect:8083"
    },
    "tasks": [
        {
            "id": 0,
            "state": "RUNNING",
            "worker_id": "connect:8083"
        }
    ]
}
```

Tanto el `connector` como el `task` deben estar en estado `RUNNING`.

#### Consumir mensajes del topic

```bash
# Consumir 5 mensajes (formato Avro → se muestra como bytes codificados)
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-telemetry \
  --from-beginning \
  --max-messages 5
```

**Nota:** El `kafka-console-consumer` muestra Avro como bytes codificados (texto ilegible). Para ver el contenido deserializado, usar el `kafka-avro-console-consumer` desde el container de Schema Registry:

```bash
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-telemetry \
  --from-beginning \
  --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081
```

Salida esperada (ejemplo):
```json
{"sensor_id":"sensor_003","timestamp":1767225600000,"temperature":38.2,"humidity":45.1,"soil_fertility":67.3}
{"sensor_id":"sensor_007","timestamp":1767225601000,"temperature":22.8,"humidity":12.4,"soil_fertility":89.1}
{"sensor_id":"sensor_001","timestamp":1767225602000,"temperature":28.5,"humidity":55.7,"soil_fertility":42.6}
```

Observa que:
- `temperature` de 38.2 → supera 35°C → generará alerta HIGH_TEMPERATURE en Tarea 3
- `humidity` de 12.4 → por debajo de 20% → generará alerta LOW_HUMIDITY en Tarea 3

#### Verificar el schema en Schema Registry

```bash
# Listar subjects registrados
curl -s http://localhost:8081/subjects | jq

# Ver el schema del topic sensor-telemetry
curl -s http://localhost:8081/subjects/sensor-telemetry-value/versions/latest | jq
```

El schema registrado debe coincidir con nuestro `sensor-telemetry.avsc` (sin las anotaciones `arg.properties`, que son solo para el Datagen y no forman parte del schema Avro estándar).

#### Verificar en Control Center

Abrir http://localhost:9021 en el navegador:
1. **Topics** → `sensor-telemetry` → se ven los eventos en tiempo real
2. **Schema Registry** → subject `sensor-telemetry-value` → se ve el schema Avro
3. **Connect** → connector `source-datagen-sensor-telemetry` → estado RUNNING

---

## Tarea 2: Integración de MySQL con Kafka Connect

### Contexto y Objetivo

FarmIA opera una plataforma de ventas en línea de productos agrícolas (fertilizantes, semillas, pesticidas, equipamiento, suministros, suelo). Las transacciones se almacenan en una base de datos MySQL. El objetivo es llevar esos datos a Kafka para poder procesarlos en streaming en la Tarea 4.

**Input:** tabla `sales_transactions` en MySQL con columnas `transaction_id`, `product_id`, `category`, `quantity`, `price`, `timestamp`.

**Output:** topic Kafka `sales-transactions` con los registros serializados en Avro.

### Cómo se puebla la tabla MySQL

La tabla `sales_transactions` no tiene datos estáticos. Se puebla automáticamente mediante dos connectors proporcionados:

1. **`source-datagen-_transactions`**: genera transacciones sintéticas con el schema `transactions.avsc` y las publica en el topic `_transactions`.
2. **`sink-mysql-_transactions`**: lee del topic `_transactions` y escribe las filas en la tabla MySQL `sales_transactions`.

Este circuito (Datagen → `_transactions` → MySQL) simula un sistema de ventas que genera transacciones continuamente, proporcionando datos frescos para que el JDBC Source los capture.

```
source-datagen-_transactions     sink-mysql-_transactions       source-mysql-sales_transactions
        │                                │                                │
        ▼                                ▼                                ▼
   Genera datos ──→ _transactions ──→ MySQL(sales_transactions) ──→ sales-transactions
   (topic auxiliar)                   (tabla real)                  (topic de negocio)
```

#### El topic `_transactions`

El topic `_transactions` no se crea en el script `create-topics.sh` y no aparece en el enunciado de la tarea. Sin embargo, es imprescindible para que el pipeline funcione.

**¿Quién lo crea?** Se **autocrea** cuando el connector Datagen (`source-datagen-_transactions`) empieza a producir mensajes. Kafka tiene habilitado por defecto `auto.create.topics.enable=true`, de modo que cuando un producer escribe a un topic que no existe, Kafka lo crea sobre la marcha.

Al autocrearse, usa la configuración por defecto del broker (1 partición, replication factor 1). Para este topic es aceptable porque es un **topic interno/auxiliar** que solo sirve de puente entre el Datagen y el JDBC Sink que escribe en MySQL. No se consume en ksqlDB ni se procesa en ninguna tarea — es infraestructura proporcionada por el profesor.

#### Schema del topic `_transactions`

El topic usa el schema Avro definido en `0.tarea/datagen/transactions.avsc`:

```json
{
  "namespace": "com.farmia.sales",
  "name": "SalesTransaction",
  "type": "record",
  "fields": [...]
}
```

| Campo | Tipo | Generación |
|---|---|---|
| `transaction_id` | string | Regex `tx[1-9]{5}` → ej: `tx34521` |
| `product_id` | string | Regex `prod_[1-9]{3}` → ej: `prod_472` |
| `category` | string | Aleatorio entre: fertilizers, seeds, pesticides, equipment, supplies, soil |
| `quantity` | int | Rango 1-10 |
| `price` | float | Rango 10.00-200.00 |

El connector Datagen lo referencia en su configuración:

```json
"schema.filename": "/home/appuser/transactions.avsc",
"schema.keyfield": "transaction_id"
```

El fichero `.avsc` se copia al container `connect` durante el `setup.sh`:

```bash
docker cp ../0.tarea/datagen/transactions.avsc connect:/home/appuser/
```

#### ¿Por qué el schema no tiene campo `timestamp`?

Observa que el schema Avro tiene **5 campos**, pero la tabla MySQL tiene **6 columnas** (incluye `timestamp`). Esto es intencional: el campo `timestamp` no viene del Datagen, sino que lo añade MySQL automáticamente con `DEFAULT CURRENT_TIMESTAMP` en el momento de la inserción. De esta forma, cada fila registra el instante exacto en que fue escrita en la base de datos, no un timestamp sintético generado por Datagen.

Este es precisamente el campo que después usa el JDBC Source Connector en modo `timestamp` para detectar filas nuevas.

### Diseño de la Tabla MySQL

La tabla está definida en `0.tarea/sql/transactions.sql` (proporcionada, no se modifica):

```sql
CREATE TABLE IF NOT EXISTS db.sales_transactions (
    transaction_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    category VARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, timestamp)
);
```

Aspectos relevantes:

- **`timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP`**: MySQL asigna automáticamente la fecha/hora de inserción. Esta columna es la que usa el JDBC connector en modo incremental.
- **PRIMARY KEY compuesta** (`transaction_id`, `timestamp`): permite múltiples registros del mismo `transaction_id` si tienen diferentes timestamps.

### Configuración del JDBC Source Connector

El fichero está en `0.tarea/connectors/source-mysql-sales_transactions.json`:

```json
{
  "name": "source-mysql-sales_transactions",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "tasks.max": "1",
    "connection.url": "jdbc:mysql://mysql:3306/db?user=user&password=password&useSSL=false",
    "table.whitelist": "sales_transactions",
    "mode": "timestamp",
    "timestamp.column.name": "timestamp",
    "topic.prefix": "",
    "poll.interval.ms": 5000,
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "transforms": "castPrice,createKey,extractString,routeTopic",
    "transforms.castPrice.type": "org.apache.kafka.connect.transforms.Cast$Value",
    "transforms.castPrice.spec": "price:float64",
    "transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
    "transforms.createKey.fields": "transaction_id",
    "transforms.extractString.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
    "transforms.extractString.field": "transaction_id",
    "transforms.routeTopic.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.routeTopic.regex": "sales_transactions",
    "transforms.routeTopic.replacement": "sales-transactions"
  }
}
```

#### Desglose de propiedades: Conexión y Modo

| Propiedad | Valor | Explicación |
|---|---|---|
| `connection.url` | `jdbc:mysql://mysql:3306/db?...` | URL JDBC al container MySQL. `mysql` es el hostname en la red Docker. `useSSL=false` desactiva SSL (entorno de lab). |
| `table.whitelist` | `sales_transactions` | Lista de tablas a leer. Solo necesitamos una. |
| `mode` | `timestamp` | Modo incremental que detecta filas nuevas por su `timestamp`. |
| `timestamp.column.name` | `timestamp` | Columna `TIMESTAMP` de MySQL usada para tracking incremental. |
| `topic.prefix` | `""` | Prefijo vacío — el nombre del topic se controla mediante la SMT `RegexRouter`. |
| `poll.interval.ms` | `5000` | Cada 5 segundos el connector consulta MySQL buscando filas nuevas. |
| `value.converter` | `AvroConverter` | Serializa los registros en Avro. El schema se genera automáticamente a partir de la estructura de la tabla MySQL. |
| `key.converter` | `StringConverter` | La key se serializa como string plano. |

### Modo `timestamp` en detalle

El connector en modo `timestamp` detecta filas nuevas comparando el valor de la columna `timestamp` con el último valor procesado:

```
┌──────────────────────────────────────────────────────────┐
│                    JDBC Source - modo timestamp           │
│                                                           │
│  El connector almacena internamente:                     │
│    last_timestamp = 2026-01-15 10:30:00                  │
│                                                           │
│  En cada poll (cada 5s), ejecuta conceptualmente:        │
│                                                           │
│    SELECT * FROM sales_transactions                      │
│    WHERE timestamp > '2026-01-15 10:30:00'               │
│    ORDER BY timestamp ASC                                │
│                                                           │
│  → Obtiene solo las filas nuevas                         │
│  → Actualiza last_timestamp al máximo encontrado         │
│  → Publica las filas en el topic                         │
└──────────────────────────────────────────────────────────┘
```

**Limitaciones del modo `timestamp`:** si dos INSERTs ocurren en el mismo milisegundo con exactamente el mismo `timestamp`, el connector podría perder uno. En un entorno de producción se usaría `timestamp+incrementing` para combinar ambas estrategias. Para este lab, con el Datagen generando ~1 transacción/segundo, el modo `timestamp` es suficiente.

### SMTs (Single Message Transforms)

Las SMTs son transformaciones ligeras que se aplican a cada mensaje **dentro del connector**, antes de que se publique en Kafka. No requieren código — se configuran declarativamente en el JSON.

Usamos 4 SMTs encadenadas (se ejecutan en el orden declarado en `"transforms"`):

```
MySQL Row → [castPrice] → [createKey] → [extractString] → [routeTopic] → Kafka
```

**SMT 1: `castPrice` (Cast$Value) — Conversión de tipo DECIMAL a double**

```json
"transforms.castPrice.type": "org.apache.kafka.connect.transforms.Cast$Value",
"transforms.castPrice.spec": "price:float64"
```

Esta SMT resuelve un problema de incompatibilidad de tipos entre MySQL y Avro. La columna `price` en MySQL está definida como `DECIMAL(10,2)`. Cuando el JDBC Source Connector lee este tipo, el mapeo por defecto a Avro es:

```
MySQL DECIMAL(10,2) → Avro bytes con logicalType "decimal" (precisión 10, escala 2)
```

El tipo Avro `bytes` con logical type `decimal` almacena el valor como una secuencia de bytes en complemento a dos, no como un número legible. Esto provoca que al visualizar los mensajes en Control Center (o cualquier consumidor que no implemente la decodificación del logical type `decimal`), el campo `price` se muestre como **caracteres ilegibles** en lugar de un número.

**¿Por qué ocurre esto?** El flujo completo de datos es:

```
1. Datagen genera price como float (Avro)     → topic _transactions
2. JDBC Sink escribe float en MySQL DECIMAL    → MySQL convierte sin problema (float → DECIMAL)
3. JDBC Source lee MySQL DECIMAL               → serializa como Avro bytes (logicalType: decimal)
4. En el topic sales-transactions              → price aparece como bytes ilegibles
```

La discrepancia está en el paso 3: el JDBC Source genera el schema Avro a partir de los tipos de MySQL (no del schema Avro original del Datagen). MySQL `DECIMAL(10,2)` se mapea a `bytes`, no a `float` ni `double`.

**¿Por qué no funciona `numeric.mapping=best_fit`?** La propiedad `numeric.mapping=best_fit` del JDBC Source Connector solo convierte `DECIMAL` a `int`/`long` cuando la escala es 0 (es decir, sin decimales). Para `DECIMAL(10,2)` con escala 2, `best_fit` sigue mapeando a `bytes`. Por eso es necesario el SMT `Cast$Value`.

**Resultado:** con esta SMT, el campo `price` se convierte de `DECIMAL` (bytes) a `float64` (double en Avro) **antes** de la serialización, produciendo valores numéricos legibles como `104.21`, `87.59`, etc.

> **Nota:** Esta SMT debe ser la **primera** en la cadena (antes de `createKey`), ya que opera sobre el value del mensaje y necesita acceder al campo `price` antes de cualquier otra transformación.

**SMT 2: `createKey` (ValueToKey)**

```json
"transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
"transforms.createKey.fields": "transaction_id"
```

El JDBC Source Connector por defecto no produce message keys (la key es null). Esta SMT copia el campo `transaction_id` del value al key del mensaje. Tener una key es esencial porque:
- Permite particionar por `transaction_id` (mensajes del mismo ID siempre van a la misma partición)
- ksqlDB necesita la key para crear streams con columnas KEY

**SMT 3: `extractString` (ExtractField$Key)**

```json
"transforms.extractString.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
"transforms.extractString.field": "transaction_id"
```

La SMT anterior (`ValueToKey`) produce una key como struct: `{"transaction_id": "tx12345"}`. Esta SMT extrae el valor del campo para obtener un string plano: `"tx12345"`. Esto es necesario porque el `key.converter` es `StringConverter`, que espera un string simple, no un struct.

**SMT 4: `routeTopic` (RegexRouter)**

```json
"transforms.routeTopic.type": "org.apache.kafka.connect.transforms.RegexRouter",
"transforms.routeTopic.regex": "sales_transactions",
"transforms.routeTopic.replacement": "sales-transactions"
```

El JDBC Source Connector genera el nombre del topic como `topic.prefix + table_name`. Con `topic.prefix = ""` y tabla `sales_transactions`, el topic resultante sería `sales_transactions` (con guion bajo). El enunciado pide el topic `sales-transactions` (con guion). Esta SMT aplica una regex para renombrar el topic.

### ¿Cómo se genera el nombre del topic?

```
topic.prefix = ""
table_name   = "sales_transactions"
─────────────────────────────────────
topic (sin SMT) = "sales_transactions"   ✗ (guion bajo, no es lo que queremos)

+ RegexRouter: sales_transactions → sales-transactions

topic (con SMT) = "sales-transactions"   ✓ (lo que pide el enunciado)
```

**¿Por qué no usar `topic.prefix = "sales-"` directamente?** Porque con `topic.prefix = "sales-"` y tabla `sales_transactions`, el topic resultante sería `sales-sales_transactions` (prefijo + nombre completo de la tabla). El prefijo se concatena al nombre de la tabla, no lo reemplaza.

### Verificación y Validación

#### Estado del connector

```bash
curl -s http://localhost:8083/connectors/source-mysql-sales_transactions/status | jq
```

#### Consumir mensajes deserializados

```bash
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sales-transactions \
  --from-beginning \
  --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081
```

#### Verificar datos en MySQL

```bash
docker exec mysql mysql --user=root --password=password --database=db \
  -e "SELECT transaction_id, category, quantity, price, timestamp FROM sales_transactions LIMIT 5;"
```

---

## Tarea 3: Procesamiento de Sensores con ksqlDB

### Contexto y Objetivo

Los sensores IoT de FarmIA envían datos continuamente al topic `sensor-telemetry` (Tarea 1). Necesitamos un sistema que procese estos datos **en tiempo real** y detecte condiciones anormales que puedan dañar los cultivos.

**Reglas de anomalía (definidas por el enunciado):**
- **HIGH_TEMPERATURE:** temperatura > 35 °C
- **LOW_HUMIDITY:** humedad < 20 %

**Input:** topic `sensor-telemetry` (Avro)
**Output:** topic `sensor-alerts` (Avro)

**Formato de salida esperado:**
```json
{
  "sensor_id": "sensor_001",
  "alert_type": "HIGH_TEMPERATURE",
  "timestamp": 1767225600000,
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
        └────────┬───────────┘
                 │  CSAS (single query)
                 ▼
   ┌──────────────────────────────┐
   │        sensor-alerts          │  (topic Kafka, Avro)
   │  ┌────────────────────────┐  │
   │  │ LOW_HUMIDITY: 12.4%    │  │
   │  │ HIGH_TEMPERATURE: 38.2°│  │
   │  └────────────────────────┘  │
   └──────────────────────────────┘
```

### Queries de ksqlDB: Explicación Detallada

Los ficheros SQL están en `0.tarea/ksqldb/01-sensor-alerts.sql`.

#### Statement 1: Crear el STREAM de entrada

```sql
CREATE STREAM IF NOT EXISTS sensor_telemetry_stream (
    sensor_id      VARCHAR KEY,
    `timestamp`    BIGINT,
    temperature    DOUBLE,
    humidity       DOUBLE,
    soil_fertility DOUBLE
) WITH (
    KAFKA_TOPIC  = 'sensor-telemetry',
    VALUE_FORMAT = 'AVRO'
);
```

**¿Qué hace?** Declara una abstracción de streaming sobre el topic `sensor-telemetry`. No mueve datos ni crea nada nuevo — simplemente le dice a ksqlDB cómo interpretar los mensajes del topic.

**Conceptos clave:**

- **STREAM vs TABLE**: un STREAM es una secuencia inmutable de eventos (append-only). Cada lectura de sensor es un evento nuevo, no una actualización de uno anterior. Por eso usamos STREAM y no TABLE.

- **`sensor_id VARCHAR KEY`**: el campo `sensor_id` es la key del mensaje Kafka. Recordemos que en la Tarea 1 configuramos `"schema.keyfield": "sensor_id"` en el Datagen, así que cada mensaje tiene `sensor_id` como key.

- **`` `timestamp` ``** (con backticks): `timestamp` es una palabra reservada en ksqlDB (referencia al ROWTIME del mensaje). Los backticks la escapan para referirnos a nuestro campo del schema, no al ROWTIME.

- **`VALUE_FORMAT = 'AVRO'`**: le dice a ksqlDB que los valores están en Avro. ksqlDB obtiene el schema del Schema Registry automáticamente.

#### Statement 2: Crear el STREAM de alertas (CSAS)

```sql
CREATE STREAM IF NOT EXISTS sensor_alerts_stream
WITH (
    KAFKA_TOPIC  = 'sensor-alerts',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS   = 3,
    REPLICAS      = 3
) AS
SELECT
    sensor_id,
    CASE
        WHEN temperature > 35 AND humidity < 20 THEN 'HIGH_TEMPERATURE_AND_LOW_HUMIDITY'
        WHEN temperature > 35 THEN 'HIGH_TEMPERATURE'
        WHEN humidity < 20 THEN 'LOW_HUMIDITY'
    END AS alert_type,
    `timestamp`,
    CASE
        WHEN temperature > 35 AND humidity < 20 THEN 'Temperature exceeded 35°C and humidity below 20%'
        WHEN temperature > 35 THEN 'Temperature exceeded 35°C'
        WHEN humidity < 20 THEN 'Humidity below 20%'
    END AS details
FROM sensor_telemetry_stream
WHERE temperature > 35 OR humidity < 20
EMIT CHANGES;
```

**¿Qué hace?** Crea una **persistent query** — una transformación que se ejecuta continuamente en background. Por cada mensaje nuevo en `sensor_telemetry_stream` donde `temperature > 35` o `humidity < 20`, genera un mensaje de alerta y lo escribe en el topic `sensor-alerts`.

**Conceptos clave:**

- **CSAS (CREATE STREAM AS SELECT)**: es la forma en que ksqlDB crea pipelines de procesamiento continuo. A diferencia de un `SELECT` normal (que muestra resultados y termina), un CSAS:
  1. Crea un nuevo topic en Kafka (`sensor-alerts`)
  2. Despliega una query persistente que se ejecuta indefinidamente
  3. Cada evento nuevo que cumpla el `WHERE` genera un mensaje en el topic destino

- **`CASE WHEN` para clasificar alertas**: usamos una expresión `CASE WHEN` para asignar el tipo de alerta. El orden importa: primero comprobamos si se cumplen AMBAS condiciones (`temperature > 35 AND humidity < 20`), y solo después las individuales. Esto evita generar dos alertas separadas para el mismo evento.

- **Una sola query con `WHERE ... OR`**: a diferencia de un enfoque con dos queries separadas (CSAS + INSERT INTO), usamos una única query que cubre ambos tipos de alerta. Esto es más eficiente (un solo consumidor del topic de entrada) y más simple de mantener.

- **¿Qué pasa si un evento cumple AMBAS condiciones?** (temperatura > 35 y humedad < 20): se genera una única alerta de tipo `HIGH_TEMPERATURE_AND_LOW_HUMIDITY`. El `CASE WHEN` evalúa de arriba a abajo y devuelve el primer match, y nuestra primera condición cubre el caso combinado.

- **`PARTITIONS = 3, REPLICAS = 3`**: configuración del topic `sensor-alerts` para que sea consistente con el resto de topics del proyecto (3 particiones, RF=3).

- **`VALUE_FORMAT = 'AVRO'`**: las alertas se serializan en Avro, igual que los datos de entrada. Esto permite que el MongoDB Sink Connector (Tarea 5) las deserialice usando Schema Registry.

- **`EMIT CHANGES`**: obligatorio en ksqlDB para queries sobre streams. Indica que los resultados se emiten conforme llegan nuevos eventos.

### Verificación y Validación

#### Consumir alertas del topic

```bash
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-alerts \
  --from-beginning \
  --max-messages 10 \
  --property schema.registry.url=http://schema-registry:8081
```

Salida esperada:
```json
{"sensor_id":"sensor_003","alert_type":"HIGH_TEMPERATURE","timestamp":1767225600000,"details":"Temperature exceeded 35°C"}
{"sensor_id":"sensor_007","alert_type":"LOW_HUMIDITY","timestamp":1767225601000,"details":"Humidity below 20%"}
```

#### Verificar en ksqlDB CLI

```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

```sql
-- Ver streams creados
SHOW STREAMS;

-- Ver queries persistentes activas
SHOW QUERIES;

-- Ver alertas en tiempo real (Ctrl+C para detener)
SELECT * FROM sensor_alerts_stream EMIT CHANGES LIMIT 5;
```

#### Verificar queries activas

Debes ver 1 query con estado `RUNNING` — la CSAS que filtra anomalías y escribe en `sensor-alerts`.

---

## Tarea 4: Procesamiento de Ventas con ksqlDB

### Contexto y Objetivo

Las transacciones de ventas de FarmIA fluyen al topic `sales-transactions` desde MySQL (Tarea 2). El negocio necesita un resumen en tiempo real de los ingresos por categoría de producto para tomar decisiones rápidas: ¿qué se está vendiendo más ahora?, ¿hay un pico de demanda en fertilizantes?

La solución agrega las ventas en ventanas de 1 minuto, calcula totales y publica los resúmenes.

**Input:** topic `sales-transactions` (Avro)
**Output:** topic `sales-summary` (Avro)

**Formato de salida esperado:**
```json
{
  "category": "fertilizers",
  "total_quantity": 20,
  "total_revenue": 1000.0,
  "window_start": 1767225600000,
  "window_end": 1767225660000
}
```

### Conceptos Clave: Windowed Aggregations

Esta tarea es el corazón del procesamiento streaming y requiere entender dos conceptos fundamentales.

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
• Ideal para promedios móviles

Session (INACTIVITY GAP 5 MINUTES)
──────────────────────────────────────────────────────────
|  sesión 1 (actividad continua)  |   gap   |  sesión 2  |
──────────────────────────────────────────────────────────
• Ventanas dinámicas basadas en actividad
• Se cierra cuando no hay eventos durante el gap
• Ideal para sesiones de usuario
```

Para esta tarea, **Tumbling** es la opción correcta: queremos un total fijo cada minuto, sin solapamiento ni ambigüedad.

#### 2. STREAM vs TABLE en contexto de agregación

Un `GROUP BY` en ksqlDB siempre produce una **TABLE**, no un STREAM. La razón conceptual es que una agregación mantiene estado: el total de ventas de "fertilizers" en la ventana 12:00-12:01 es un valor que se **actualiza** conforme llegan más ventas de esa categoría en ese minuto. Esto es una vista materializada (TABLE), no una secuencia inmutable (STREAM).

### Queries de ksqlDB: Explicación Detallada

Los ficheros SQL están en `0.tarea/ksqldb/02-sales-summary.sql`.

#### Statement 1: Crear el STREAM de entrada

```sql
CREATE STREAM IF NOT EXISTS sales_transactions_stream (
    transaction_id VARCHAR KEY,
    product_id     VARCHAR,
    category       VARCHAR,
    quantity       INT,
    price          DOUBLE,
    `timestamp`    BIGINT
) WITH (
    KAFKA_TOPIC  = 'sales-transactions',
    VALUE_FORMAT = 'AVRO'
);
```

**Puntos importantes:**

- **`transaction_id VARCHAR KEY`**: la key del mensaje, establecida por las SMTs del JDBC connector (Tarea 2).

- **`VALUE_FORMAT = 'AVRO'`**: los datos vienen del JDBC connector que serializa en Avro con Schema Registry.

- **`` `timestamp` ``** (con backticks): igual que en la Tarea 3, escapamos la palabra reservada.

#### Statement 2: Tabla agregada con TUMBLING WINDOW

```sql
CREATE TABLE IF NOT EXISTS sales_summary_table
WITH (
    KAFKA_TOPIC  = 'sales-summary',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS   = 3,
    REPLICAS     = 3
) AS
SELECT
    category,
    SUM(quantity)          AS total_quantity,
    SUM(quantity * price)  AS total_revenue,
    WINDOWSTART            AS window_start,
    WINDOWEND              AS window_end
FROM sales_transactions_stream
    WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY category
EMIT CHANGES;
```

**¿Qué hace?** Crea una persistent query que:
1. Consume el stream `sales_transactions_stream`
2. Agrupa los eventos por `category` en ventanas de 1 minuto
3. Para cada grupo calcula la suma de cantidades y el revenue total
4. Publica los resultados en el topic `sales-summary`

**Conceptos clave:**

- **`WINDOW TUMBLING (SIZE 1 MINUTE)`**: define ventanas fijas de 1 minuto sin solapamiento. ksqlDB asigna cada evento a su ventana según el ROWTIME del mensaje.

- **`SUM(quantity * price) AS total_revenue`**: calcula el ingreso total como suma de (cantidad * precio unitario) para cada categoría dentro de la ventana.

- **`WINDOWSTART` / `WINDOWEND`**: pseudocolumnas de ksqlDB que contienen los límites de la ventana en epoch millis. No necesitan declararse — ksqlDB las genera automáticamente para queries windowed.

- **`GROUP BY category`**: agrupa por categoría de producto. Las categorías posibles son: fertilizers, seeds, pesticides, equipment, supplies, soil (definidas en el schema `transactions.avsc`).

**¿Qué pasa con los mensajes intermedios?**

Cada vez que llega una nueva venta de "fertilizers" dentro de una ventana activa, ksqlDB emite una **actualización** al topic `sales-summary`. Esto significa que puedes ver múltiples mensajes para la misma combinación categoría + ventana:

```json
// Llega la primera venta de fertilizers (qty=2, price=50)
{"category":"fertilizers","total_quantity":2,"total_revenue":100.0,"window_start":...,"window_end":...}

// Llega la segunda venta de fertilizers (qty=5, price=45)
{"category":"fertilizers","total_quantity":7,"total_revenue":325.0,"window_start":...,"window_end":...}
```

El último mensaje emitido para cada ventana es el valor final.

### Verificación y Validación

#### Consumir resúmenes del topic

```bash
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sales-summary \
  --from-beginning \
  --max-messages 10
```

#### Ver en ksqlDB CLI

```sql
-- Resúmenes en tiempo real
SELECT * FROM sales_summary_table EMIT CHANGES LIMIT 5;

-- Ver todas las queries persistentes (Tarea 3 + Tarea 4)
SHOW QUERIES;
```

---

## Tarea 5: Integración de MongoDB con Kafka Connect

### Contexto y Objetivo

Las alertas de anomalías generadas por ksqlDB (Tarea 3) fluyen al topic `sensor-alerts`. Para que el equipo de operaciones de FarmIA pueda consultarlas, analizarlas históricamente y construir dashboards, necesitamos persistirlas en una base de datos. MongoDB es ideal para este caso: los documentos se almacenan directamente sin necesidad de definir un esquema rígido.

**Input:** topic `sensor-alerts` (Avro, producido por ksqlDB en la Tarea 3)
**Output:** colección `sensor_alerts` en MongoDB (base de datos `course`)

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

El fichero está en `0.tarea/connectors/sink-mongodb-sensor_alerts.json`:

```json
{
  "name": "sink-mongodb-sensor_alerts",
  "config": {
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "tasks.max": "1",
    "topics": "sensor-alerts",
    "connection.uri": "mongodb://admin:secret123@mongodb:27017",
    "database": "course",
    "collection": "sensor_alerts",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}
```

#### Desglose de propiedades

| Propiedad | Valor | Explicación |
|---|---|---|
| `connector.class` | `MongoSinkConnector` | Connector oficial de MongoDB para Kafka. Instalado durante el `setup.sh` con `confluent-hub install`. |
| `connection.uri` | `mongodb://admin:secret123@mongodb:27017` | URI de conexión a MongoDB. `mongodb` es el hostname en la red Docker. Las credenciales coinciden con las del `docker-compose.yaml`. |
| `database` | `course` | Base de datos destino. Se crea automáticamente si no existe (MongoDB es schemaless). |
| `collection` | `sensor_alerts` | Colección destino. También se crea automáticamente. |
| `topics` | `sensor-alerts` | Topic de Kafka a consumir. |
| `key.converter` | `StringConverter` | La key del mensaje es un string (el `sensor_id`). |
| `value.converter` | `AvroConverter` | Las alertas fueron escritas en Avro por ksqlDB (Tarea 3), así que usamos AvroConverter para deserializarlas. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL del Schema Registry para resolver el schema Avro de las alertas. |

**¿Por qué AvroConverter y no JsonConverter?** Porque en la Tarea 3 configuramos el stream de alertas con `VALUE_FORMAT = 'AVRO'`. El converter del sink debe coincidir con el formato en que se escribieron los datos en el topic. Si hubiésemos usado `VALUE_FORMAT = 'JSON'` en ksqlDB, usaríamos `JsonConverter` con `schemas.enable = false`.

### Verificación y Validación

#### Estado del connector

```bash
curl -s http://localhost:8083/connectors/sink-mongodb-sensor_alerts/status | jq
```

Respuesta esperada:
```json
{
    "name": "sink-mongodb-sensor_alerts",
    "connector": { "state": "RUNNING", "worker_id": "connect:8083" },
    "tasks": [
        { "id": 0, "state": "RUNNING", "worker_id": "connect:8083" }
    ]
}
```

#### Consultar documentos en MongoDB

```bash
docker exec -it mongodb mongosh --username admin --password secret123 --authenticationDatabase admin
```

```javascript
// Seleccionar base de datos
use course

// Contar documentos
db.sensor_alerts.countDocuments()

// Ver los 5 más recientes
db.sensor_alerts.find().sort({_id: -1}).limit(5).pretty()

// Contar por tipo de alerta
db.sensor_alerts.aggregate([
    { $group: { _id: "$alert_type", count: { $sum: 1 } } },
    { $sort: { count: -1 } }
])

// Buscar alertas de un sensor específico
db.sensor_alerts.find({ sensor_id: "sensor_003" }).limit(5).pretty()
```

Ejemplo de documento en MongoDB:
```json
{
    "_id": ObjectId("..."),
    "sensor_id": "sensor_003",
    "alert_type": "HIGH_TEMPERATURE",
    "timestamp": 1767225600000,
    "details": "Temperature exceeded 35°C"
}
```

#### Verificar flujo continuo

El sink connector consume continuamente. Mientras el Datagen y ksqlDB estén activos, nuevas alertas aparecerán en MongoDB automáticamente:

```bash
# Observar conteo creciente en MongoDB
watch -n 5 'docker exec mongodb mongosh --quiet \
  --username admin --password secret123 --authenticationDatabase admin \
  --eval "db = db.getSiblingDB(\"course\"); print(\"Documentos: \" + db.sensor_alerts.countDocuments());"'
```

---

## Ejecución Completa del Pipeline

### Orden de ejecución

Todos los scripts se ejecutan desde el directorio `0.tarea/`:

```bash
# 1. Levantar infraestructura + instalar plugins
./setup.sh                    # ~60 segundos

# 2. Crear topics de Kafka
./topics/create-topics.sh

# 3. Lanzar los 5 conectores
./start_connectors.sh

# 4. Crear streams y tablas ksqlDB
./ksqldb/run-ksqldb.sh

# 5. Validar el pipeline completo
./validation/validate.sh
```

### Orden de Dependencias

```
T1 (Datagen sensor) ──────────────────→ T3 (ksqlDB alerts) ──→ T5 (MongoDB Sink)
T2 (JDBC MySQL) ──→ T4 (ksqlDB sales)
```

Las tareas 1→3→5 forman la cadena de sensores. Las tareas 2→4 forman la cadena de ventas. Ambas cadenas son independientes entre sí.

### Validación automatizada

```bash
cd 0.tarea
./validation/validate.sh
```

Este script verifica:
1. Topics creados y su configuración (particiones, RF)
2. Estado de los 5 conectores (todos deben estar RUNNING)
3. Mensajes en los topics de entrada y salida
4. Streams, tables y queries en ksqlDB
5. Documentos insertados en MongoDB

### Parada del entorno

```bash
cd 0.tarea
./shutdown.sh
```

> **Nota:** El estado de los contenedores no se persiste. Los datos y el estado del cluster se perderán al detener el entorno.

---

## Problemas Detectados y Soluciones

Durante la fase de testing del pipeline se detectó un problema crítico de visualización de datos que requirió cambios en la configuración del conector JDBC Source. A continuación se documenta el problema, su análisis y la solución aplicada.

### Problema: campo `price` ilegible en el topic `sales-transactions`

**Síntoma:** al inspeccionar los mensajes del topic `sales-transactions` en Confluent Control Center, el campo `price` mostraba caracteres ilegibles en lugar de valores numéricos:

```
{"transaction_id":"tx99122", ..., "price":"\u0018♦", ...}
{"transaction_id":"tx41116", ..., "price":"\u0013♦", ...}
{"transaction_id":"tx72133", ..., "price":"@>", ...}
```

**Causa raíz:** incompatibilidad de tipos entre MySQL y el mapeo automático de Avro.

El flujo de datos que genera este problema es:

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. Datagen (transactions.avsc)                                     │
│     price: float (Avro)              → topic: _transactions         │
│                                                                      │
│  2. JDBC Sink (_transactions → MySQL)                               │
│     float → DECIMAL(10,2)            → MySQL lo convierte OK        │
│                                                                      │
│  3. JDBC Source (MySQL → sales-transactions)   ← AQUÍ ESTÁ EL BUG  │
│     DECIMAL(10,2) → bytes (logicalType: decimal)                    │
│     El JDBC Source NO usa el schema Avro del Datagen.               │
│     Genera un schema NUEVO a partir de los tipos de MySQL.          │
│     MySQL DECIMAL(10,2) se mapea a Avro "bytes" + logicalType       │
│     "decimal" (precisión 10, escala 2).                             │
│                                                                      │
│  4. Control Center muestra los bytes crudos → caracteres ilegibles  │
└─────────────────────────────────────────────────────────────────────┘
```

**El punto clave** es que el JDBC Source Connector genera su propio schema Avro a partir de la estructura de la tabla MySQL. No reutiliza el schema del Datagen (`transactions.avsc`). Por tanto, aunque el Datagen define `price` como `float`, el JDBC Source lee un `DECIMAL(10,2)` de MySQL y lo serializa como `bytes`.

El tipo Avro `bytes` con logical type `decimal` codifica el valor numérico como una secuencia de bytes en complemento a dos. Por ejemplo, el valor `104.21` se almacena como los bytes `0x28B5` (10421 en complemento a dos, con escala 2). Estos bytes no son legibles como texto.

**Schema registrado antes del fix:**

```json
{
  "name": "price",
  "type": {
    "type": "bytes",
    "scale": 2,
    "precision": 10,
    "logicalType": "decimal"
  }
}
```

**Solución descartada: `numeric.mapping=best_fit`**

El JDBC Source Connector tiene una propiedad `numeric.mapping` que controla cómo se mapean los tipos numéricos de SQL a Avro:

| Valor | Comportamiento para DECIMAL(10,2) |
|---|---|
| `none` (default) | `bytes` + logicalType `decimal` |
| `best_fit` | Solo convierte a `int`/`long` si **escala = 0**. Para escala > 0, sigue usando `bytes` |

Como `DECIMAL(10,2)` tiene escala 2, `best_fit` **no resuelve el problema**.

**Solución aplicada: SMT `Cast$Value`**

Se añadió una nueva SMT al principio de la cadena de transformaciones del conector:

```json
"transforms.castPrice.type": "org.apache.kafka.connect.transforms.Cast$Value",
"transforms.castPrice.spec": "price:float64"
```

Esta SMT convierte el campo `price` de `DECIMAL` (bytes) a `float64` (double en Avro) **antes de la serialización**, produciendo valores numéricos legibles.

**Schema registrado después del fix:**

```json
{
  "name": "price",
  "type": "double"
}
```

**Resultado verificado con `kafka-avro-console-consumer`:**

```json
{"transaction_id":"tx95183","product_id":"prod_543","category":"soil","quantity":5,"price":104.21,"timestamp":1773762811000}
{"transaction_id":"tx11191","product_id":"prod_651","category":"fertilizers","quantity":1,"price":123.59,"timestamp":1773762812000}
{"transaction_id":"tx92558","product_id":"prod_514","category":"equipment","quantity":5,"price":26.68,"timestamp":1773762812000}
```

### Ficheros modificados

| Fichero | Cambio | Motivo |
|---|---|---|
| `0.tarea/connectors/source-mysql-sales_transactions.json` | Añadida SMT `castPrice` (`Cast$Value` con spec `price:float64`) al inicio de la cadena de transforms | Convertir `DECIMAL(10,2)` → `double` para que `price` sea un número legible en Avro |

### Procedimiento de aplicación del fix

Si el conector ya ha publicado mensajes con el schema anterior (`bytes`/`decimal`), el fix requiere limpiar el estado previo para que el nuevo schema (`double`) se registre correctamente:

```bash
# 1. Eliminar el conector
curl -X DELETE http://localhost:8083/connectors/source-mysql-sales_transactions

# 2. Eliminar el schema anterior del Schema Registry
curl -X DELETE http://localhost:8081/subjects/sales-transactions-value
curl -X DELETE "http://localhost:8081/subjects/sales-transactions-value?permanent=true"

# 3. Borrar y recrear el topic (para eliminar mensajes con schema antiguo)
docker exec broker-1 kafka-topics --bootstrap-server broker-1:29092 \
  --delete --topic sales-transactions

docker exec broker-1 kafka-topics --bootstrap-server broker-1:29092 \
  --create --topic sales-transactions \
  --partitions 3 --replication-factor 3 \
  --config retention.ms=604800000 --config max.message.bytes=64000

# 4. Recrear el conector con la nueva configuración
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @0.tarea/connectors/source-mysql-sales_transactions.json

# 5. Verificar que price ahora es double
curl -s http://localhost:8081/subjects/sales-transactions-value/versions/latest | jq '.schema | fromjson | .fields[] | select(.name=="price")'
```

> **Lección aprendida:** cuando un dato atraviesa múltiples sistemas (Datagen → Kafka → MySQL → Kafka), cada sistema aplica su propio mapeo de tipos. Es fundamental verificar el schema resultante en cada etapa, especialmente cuando intervienen tipos como `DECIMAL` que no tienen una representación directa y legible en Avro.

---

## Comandos Útiles

```bash
# ─── Docker ────────────────────────────────────────────────────────────────
cd 1.environment
docker compose up -d                              # Levantar todo
docker compose down --remove-orphans              # Parar todo
docker compose down -v                            # Reset completo (borra datos)
docker compose logs connect -f                    # Logs de Connect en tiempo real

# ─── Topics ────────────────────────────────────────────────────────────────
docker exec broker-1 kafka-topics --list --bootstrap-server broker-1:29092
docker exec broker-1 kafka-topics --describe --topic sensor-telemetry --bootstrap-server broker-1:29092

# ─── Consumir mensajes ─────────────────────────────────────────────────────
# Formato plano (Avro = bytes ilegibles)
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-telemetry \
  --from-beginning --max-messages 5

# Formato deserializado (Avro → JSON legible)
docker exec schema-registry kafka-avro-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-telemetry \
  --from-beginning --max-messages 5 \
  --property schema.registry.url=http://schema-registry:8081

# ─── Schema Registry ──────────────────────────────────────────────────────
curl -s http://localhost:8081/subjects | jq
curl -s http://localhost:8081/subjects/sensor-telemetry-value/versions/latest | jq

# ─── Kafka Connect ────────────────────────────────────────────────────────
curl -s http://localhost:8083/connectors | jq
curl -s http://localhost:8083/connectors/source-datagen-sensor-telemetry/status | jq
curl -s http://localhost:8083/connectors/source-mysql-sales_transactions/status | jq
curl -s http://localhost:8083/connectors/sink-mongodb-sensor_alerts/status | jq

# ─── ksqlDB ───────────────────────────────────────────────────────────────
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088

# ─── MySQL ────────────────────────────────────────────────────────────────
docker exec -it mysql mysql --user=root --password=password --database=db

# ─── MongoDB ──────────────────────────────────────────────────────────────
docker exec -it mongodb mongosh --username admin --password secret123 --authenticationDatabase admin

# ─── URLs de servicios ────────────────────────────────────────────────────
# Control Center:   http://localhost:9021
# Schema Registry:  http://localhost:8081
# Kafka Connect:    http://localhost:8083
# ksqlDB:           http://localhost:8088
```
