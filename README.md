# FarmIA - Pipeline de Procesamiento en Tiempo Real con Apache Kafka

## Descripcion del Proyecto

FarmIA está integrando sensores IoT en los campos agrícolas para monitorizar datos como temperatura, humedad y fertilidad del suelo. También recopila datos en tiempo real sobre las transacciones de su plataforma de ventas en línea y quiere procesarlos para generar insights en tiempo real. La meta es construir un pipeline que procese estos datos de streaming y los transforme en información útil para la toma de decisiones y análisis. Este proyecto construye un pipeline de streaming completo usando el ecosistema Apache Kafka para:

1. **Generar datos sinteticos** de sensores IoT usando Kafka Connect Datagen.
2. **Integrar transacciones de ventas** desde MySQL usando Kafka Connect JDBC Source.
3. **Detectar anomalias** en los sensores (temperatura > 35°C o humedad < 20%) con ksqlDB.
4. **Agregar ventas por categoria** de producto en ventanas de 1 minuto con ksqlDB.
5. **Persistir alertas** en MongoDB usando Kafka Connect MongoDB Sink.

## Arquitectura

### Diagrama de Flujo de Datos

![Logotipo](0.tarea/assets/farmia_project__data_flow.svg)

## Estructura del Proyecto

```
ucm-farmia/
├── 0.tarea/                          # Directorio principal de la tarea
│   ├── connectors/                   # Configuraciones de Kafka Connect
│   │   ├── source-datagen-_transactions.json       # (proporcionado) Genera transacciones
│   │   ├── sink-mysql-_transactions.json            # (proporcionado) Escribe en MySQL
│   │   ├── source-datagen-sensor-telemetry.json     # Tarea 1: Genera datos IoT
│   │   ├── source-mysql-sales_transactions.json     # Tarea 2: Lee de MySQL
│   │   └── sink-mongodb-sensor_alerts.json          # Tarea 5: Escribe alertas en MongoDB
│   ├── datagen/                      # Schemas Avro para Datagen
│   │   ├── sensor-telemetry.avsc     # Schema de datos de sensores IoT
│   │   └── transactions.avsc        # Schema de transacciones (proporcionado)
│   ├── ksqldb/                       # Queries ksqlDB
│   │   ├── 01-sensor-alerts.sql      # Tarea 3: Deteccion de anomalias
│   │   ├── 02-sales-summary.sql      # Tarea 4: Resumen de ventas por categoria
│   │   └── run-ksqldb.sh            # Script para ejecutar todas las queries
│   ├── sql/                          # DDL MySQL (NO MODIFICAR)
│   │   └── transactions.sql
│   ├── topics/                       # Creacion de topics
│   │   └── create-topics.sh
│   ├── validation/                   # Scripts de validacion
│   │   └── validate.sh
│   ├── setup.sh                      # Setup completo del entorno
│   ├── start_connectors.sh           # Lanza todos los conectores
│   └── shutdown.sh                   # Detiene el entorno
├── 1.environment/                    # Infraestructura Docker
│   ├── docker-compose.yaml
│   ├── .env                          # TAG=7.8.0, CLUSTER_ID
│   └── mysql/
│       ├── init.sql                  # Inicializacion de MySQL
│       └── mysql-connector-java-5.1.45.jar
└── README.md
```

## Orden de Ejecucion

### Paso 1: Levantar el entorno y preparar la infraestructura

```bash
cd 0.tarea
./setup.sh
```

Este script:
- Inicia todos los contenedores Docker (brokers, connect, ksqlDB, MySQL, MongoDB...)
- Crea la tabla `sales_transactions` en MySQL
- Instala los plugins de conectores (Datagen, JDBC, MongoDB, transform-common)
- Copia el driver JDBC de MySQL al contenedor de Connect
- Copia los schemas Avro al contenedor de Connect
- Reinicia Connect para cargar los plugins

### Paso 2: Crear los topics de Kafka

```bash
cd 0.tarea
./topics/create-topics.sh
```

Crea los 4 topics con 3 particiones y factor de replicacion 3:
- `sensor-telemetry`
- `sales-transactions`
- `sensor-alerts`
- `sales-summary`

### Paso 3: Lanzar los conectores de Kafka Connect

```bash
cd 0.tarea
./start_connectors.sh
```

Lanza los 5 conectores:

| Conector | Tipo | Descripcion |
|---|---|---|
| `source-datagen-_transactions` | Source Datagen | Genera transacciones sinteticas al topic `_transactions` |
| `sink-mysql-_transactions` | JDBC Sink | Escribe transacciones de `_transactions` a MySQL |
| `source-datagen-sensor-telemetry` | Source Datagen | Genera datos IoT al topic `sensor-telemetry` |
| `source-mysql-sales_transactions` | JDBC Source | Lee `sales_transactions` de MySQL al topic `sales-transactions` |
| `sink-mongodb-sensor_alerts` | MongoDB Sink | Escribe alertas de `sensor-alerts` a MongoDB |

### Paso 4: Ejecutar las queries ksqlDB

```bash
cd 0.tarea
./ksqldb/run-ksqldb.sh
```

O manualmente conectandose al CLI de ksqlDB:

```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

Y ejecutar los ficheros SQL en orden:

1. `ksqldb/01-sensor-alerts.sql` - Crea el stream de telemetria y el stream de alertas filtradas
2. `ksqldb/02-sales-summary.sql` - Crea el stream de transacciones y la tabla de resumen por categoria

## Detalle de las Tareas

### Tarea 1: Generacion de Datos Sinteticos (Datagen → sensor-telemetry)

**Objetivo:** configurar un source connector que genere eventos continuos en el topic `sensor-telemetry` con datos realistas de sensores (temperatura, humedad, fertilidad del suelo).

**Output:** topic Kafka `sensor-telemetry` con mensajes serializados en Avro.

**¿Cómo genera datos?**

Datagen lee un schema Avro que incluye anotaciones especiales en `arg.properties`. Estas anotaciones le dicen al connector cómo generar el valor de cada campo:
- `options`: elige aleatoriamente de una lista de valores fijos
- `range`: genera un número aleatorio entre `min` y `max`
- `iteration`: genera valores incrementales con un `start` y un `step`

**Conector:** `source-datagen-sensor-telemetry`

Genera eventos IoT con la estructura:
```json
{
  "sensor_id": "sensor_001",
  "timestamp": 1673548200000,
  "temperature": 35.5,
  "humidity": 23.4,
  "soil_fertility": 78.2
}
```

Schema Avro: `datagen/sensor-telemetry.avsc`

**1. Rangos de `temperature` y `humidity`**

- `temperature`: rango 15.0 - 45.0 (para generar anomalias > 35)
- `humidity`: rango 10.0 - 80.0 (para generar anomalias < 20)

**2. `sensor_id` con 10 sensores fijos**

- `sensor_id`: 10 sensores diferentes (sensor_001 a sensor_010)

**3. `timestamp` con `iteration`**

El campo `iteration` genera timestamps incrementales (cada segundo), simulando lecturas periódicas del sensor. El `start` corresponde al 1 de enero de 2026.

**4. `soil_fertility` como campo informativo**

No se definen reglas de anomalía para este campo. Se mantiene disponible con un rango (20-100).

### Configuración del Connector

El fichero de configuración está en `connectors/source-datagen-sensor-telemetry.json`.

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
| `schema.filename` | `/home/appuser/sensor-telemetry.avsc` | Ruta al schema Avro **dentro del container**. En el fichero `0.tarea/setup.sh` se copia a esta ruta. |
| `schema.keyfield` | `sensor_id` | Campo del schema que se usa como message key. Esto asegura que eventos del mismo sensor van a la misma partición (ordenamiento por sensor). |
| `max.interval` | `1000` | Intervalo máximo en ms entre mensajes. Con valor 1000, genera ~1 msg/segundo. |
| `iterations` | `10000000` | Número total de mensajes (eventos) a generar. |
| `tasks.max` | `1` | Un solo task es suficiente para un lab. En producción se usarían más para paralelismo. |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | El value se serializa en Avro antes de enviarse a Kafka. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL interna del Schema Registry (dentro de la red Docker). |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | La key se serializa como string plano (el `sensor_id`). |


### Tarea 2: Integracion MySQL (MySQL → sales-transactions)

**Objetivo:** Las transacciones se almacenan en una base de datos MySQL. El objetivo es llevar esos datos a Kafka para poder procesarlos en streaming (en la Tarea 4).

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

El topic `_transactions` no se crea en el script `create-topics.sh` y no aparece en la descripción de la tarea. Sin embargo, es imprescindible para que el pipeline funcione.

**¿Quién lo crea?** Se **autocrea** cuando el connector Datagen (`source-datagen-_transactions`) empieza a producir mensajes. Kafka tiene habilitado por defecto `auto.create.topics.enable=true`, de modo que cuando un producer escribe a un topic que no existe, Kafka lo crea sobre la marcha.

Al autocrearse, usa la configuración por defecto del broker (1 partición, replication factor 1). Este topic solo sirve de puente entre el Datagen y el JDBC Sink que escribe en MySQL. No se consume en ksqlDB ni se procesa en ninguna tarea.

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

El schema Avro tiene **5 campos**, pero la tabla MySQL tiene **6 columnas** (incluye `timestamp`). El campo `timestamp` no viene del Datagen, sino que lo añade MySQL automáticamente con `DEFAULT CURRENT_TIMESTAMP` en el momento de la inserción. De esta forma, cada fila registra el instante exacto en que fue escrita en la base de datos.

Este es el campo que después usa el JDBC Source Connector en modo `timestamp` para detectar filas nuevas.

### Aspectos relevantes de la Tabla MySQL

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
    "transforms": "createKey,extractString,routeTopic",
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

#### Desglose de propiedades:

| Propiedad | Valor | Explicación |
|---|---|---|
| `connection.url` | `jdbc:mysql://mysql:3306/db?...` | URL JDBC al container MySQL. `mysql` es el hostname en la red Docker. |
| `table.whitelist` | `sales_transactions` | Lista de tablas a leer. |
| `mode` | `timestamp` | Modo incremental que detecta filas nuevas por su `timestamp`. |
| `timestamp.column.name` | `timestamp` | Columna `TIMESTAMP` de MySQL usada para detectar nuevos registros (tracking incremental). |
| `topic.prefix` | `""` | Prefijo vacío, el nombre del topic se controla mediante la SMT `RegexRouter`. |
| `poll.interval.ms` | `5000` | Cada 5 segundos el connector consulta MySQL buscando filas nuevas. |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | Serializa en Avro antes de enviarse a Kafka. El schema se genera automáticamente a partir de la estructura de la tabla MySQL. |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | La key se serializa como string plano. |

### SMTs (Single Message Transforms)

Las SMTs son transformaciones ligeras que se aplican a cada mensaje **(dentro del connector)**, antes de que se publique en Kafka. No requieren código, se configuran declarativamente en el JSON.

Usamos 3 SMTs encadenadas (se ejecutan en el orden declarado en `"transforms"`):

```
MySQL Row → [createKey] → [extractString] → [routeTopic] → Kafka
```

**SMT 1: `createKey` (ValueToKey)**

```json
"transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
"transforms.createKey.fields": "transaction_id"
```

El JDBC Source Connector por defecto envia mensajes con key = null. Esta SMT copia el campo `transaction_id` del value al key del mensaje. Tener una key es esencial porque:
- Permite particionar por `transaction_id` (mensajes del mismo ID siempre van a la misma partición)
- ksqlDB necesita la key para crear streams con columnas KEY

**SMT 2: `extractString` (ExtractField$Key)**

```json
"transforms.extractString.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
"transforms.extractString.field": "transaction_id"
```

La SMT anterior (`ValueToKey`) produce una key como struct: `{"transaction_id": "tx12345"}`. Esta SMT extrae el valor del campo para obtener un string plano: `"tx12345"`. Esto es necesario porque el `key.converter` es `StringConverter`, que espera un string simple, no un struct.

**SMT 3: `routeTopic` (RegexRouter)**

```json
"transforms.routeTopic.type": "org.apache.kafka.connect.transforms.RegexRouter",
"transforms.routeTopic.regex": "sales_transactions",
"transforms.routeTopic.replacement": "sales-transactions"
```

El JDBC Source Connector genera el nombre del topic como `topic.prefix + table_name`. Con `topic.prefix = ""` y tabla `sales_transactions`, el topic resultante sería `sales_transactions` (con guion bajo). Con la tabla `sales_transactions` y cualquier prefijo, no se obtiene `sales-transactions` directamente. Esta SMT aplica una regex para renombrar el topic.


La cadena de SMTs resuelve los tres problemas en secuencia:

```
Mensaje original de MySQL
  key:   null
  value: {transaction_id: "tx12345", product_id: "prod_001", category: "fertilizers", ...}
  topic: "sales_transactions"
         │
         ▼
  SMT 1: ValueToKey (createKey)
  ─────────────────────────────
  Copia el campo "transaction_id" del value al key.

  key:   {"transaction_id": "tx12345"}   ← struct, no string
  value: {transaction_id: "tx12345", product_id: "prod_001", ...}
  topic: "sales_transactions"
         │
         ▼
  SMT 2: ExtractField$Key (extractString)
  ────────────────────────────────────────
  Extrae el valor del campo "transaction_id" del struct de la key,
  convirtiendo la key en un string plano.

  key:   "tx12345"                       ← string plano
  value: {transaction_id: "tx12345", product_id: "prod_001", ...}
  topic: "sales_transactions"
         │
         ▼
  SMT 3: RegexRouter (routeTopic)
  ───────────────────────────────
  Aplica una regex al nombre del topic para renombrarlo.
  sales_transactions → sales-transactions

  key:   "tx12345"
  value: {transaction_id: "tx12345", product_id: "prod_001", ...}
  topic: "sales-transactions"            ← nombre correcto
         │
         ▼
  Mensaje publicado en Kafka ✓
```

### Tarea 3: Procesamiento de Sensores (ksqlDB)

Stream `sensor_alerts_stream` que filtra `sensor_telemetry_stream`:
- **temperatura > 35°C** → alerta `HIGH_TEMPERATURE`
- **humedad < 20%** → alerta `LOW_HUMIDITY`
- **ambas condiciones** → alerta `HIGH_TEMPERATURE_AND_LOW_HUMIDITY`

Estructura de salida en `sensor-alerts`:
```json
{
  "sensor_id": "sensor_001",
  "alert_type": "HIGH_TEMPERATURE",
  "timestamp": 1673548200000,
  "details": "Temperature exceeded 35°C"
}
```

### Tarea 4: Resumen de Ventas (ksqlDB)

Tabla `sales_summary_table` con ventana tumbling de 1 minuto:
- Agrupa por `category`
- Calcula `total_quantity` (SUM) y `total_revenue` (SUM de quantity * price)

Estructura de salida en `sales-summary`:
```json
{
  "category": "fertilizers",
  "total_quantity": 20,
  "total_revenue": 1000.0,
  "window_start": 1673548200000,
  "window_end": 1673548260000
}
```

### Tarea 5: Integracion MongoDB (sensor-alerts → MongoDB)

Conector: `sink-mongodb-sensor_alerts`

- Lee del topic `sensor-alerts`
- Escribe en la coleccion `sensor_alerts` de la base de datos `course` en MongoDB

## Comandos de Validacion

### Validacion automatizada

```bash
cd 0.tarea
./validation/validate.sh
```

### Validacion manual

**Verificar topics:**
```bash
docker exec broker-1 kafka-topics --list --bootstrap-server broker-1:29092
docker exec broker-1 kafka-topics --describe --bootstrap-server broker-1:29092 --topic sensor-telemetry
```

**Verificar conectores:**
```bash
curl -s http://localhost:8083/connectors | jq
curl -s http://localhost:8083/connectors/source-datagen-sensor-telemetry/status | jq
curl -s http://localhost:8083/connectors/source-mysql-sales_transactions/status | jq
curl -s http://localhost:8083/connectors/sink-mongodb-sensor_alerts/status | jq
```

**Verificar mensajes en topics:**
```bash
docker exec broker-1 kafka-console-consumer --bootstrap-server broker-1:29092 --topic sensor-telemetry --from-beginning --max-messages 5
docker exec broker-1 kafka-console-consumer --bootstrap-server broker-1:29092 --topic sales-transactions --from-beginning --max-messages 5
docker exec broker-1 kafka-console-consumer --bootstrap-server broker-1:29092 --topic sensor-alerts --from-beginning --max-messages 5
docker exec broker-1 kafka-console-consumer --bootstrap-server broker-1:29092 --topic sales-summary --from-beginning --max-messages 5
```

**Verificar queries ksqlDB:**
```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```
```sql
SHOW STREAMS;
SHOW TABLES;
SHOW QUERIES;
SELECT * FROM sensor_alerts_stream EMIT CHANGES LIMIT 5;
SELECT * FROM sales_summary_table EMIT CHANGES LIMIT 5;
```

**Verificar datos en MongoDB:**
```bash
docker exec mongodb mongosh --username admin --password secret123 --authenticationDatabase admin --eval "db = db.getSiblingDB('course'); db.sensor_alerts.countDocuments(); db.sensor_alerts.find().sort({_id:-1}).limit(5).pretty();"
```

## URLs de los Servicios

| Servicio | URL |
|---|---|
| Control Center | http://localhost:9021 |
| Schema Registry | http://localhost:8081 |
| Kafka Connect REST | http://localhost:8083 |
| ksqlDB | http://localhost:8088 |

## Parada del Entorno

```bash
cd 0.tarea
./shutdown.sh
```

> **Nota:** El estado de los contenedores no se persiste. Los datos y el estado del cluster se perderan al detener el entorno.
