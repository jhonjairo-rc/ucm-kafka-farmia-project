# FarmIA - Pipeline de Procesamiento en Tiempo Real con Apache Kafka

## Descripcion del Proyecto

FarmIA está integrando sensores IoT en los campos agrícolas para monitorizar datos como temperatura, humedad y fertilidad del suelo. También recopila datos en tiempo real sobre las transacciones de su plataforma de ventas en línea y quiere procesarlos para generar insights en tiempo real. La meta es construir un pipeline que procese estos datos de streaming y los transforme en información útil para la toma de decisiones y análisis. Este proyecto construye un pipeline de streaming completo usando el ecosistema Apache Kafka para:

1. **Generar datos sinteticos** de sensores IoT usando Kafka Connect Datagen.
2. **Integrar las transacciones de ventas** desde MySQL usando Kafka Connect JDBC Source.
3. **Detectar anomalías** en los sensores (temperatura > 35°C o humedad < 20%) con ksqlDB.
4. **Agregar las ventas por categoria** en ventanas de 1 minuto con ksqlDB.
5. **Guardar las alertas** en MongoDB usando Kafka Connect MongoDB Sink.

## Arquitectura

### Diagrama de Flujo de Datos

![Logotipo](0.tarea/assets/farmia_project__data_flow.svg)


## Ejecución Completa del Pipeline (Orden de Ejecucion)

### Paso 1: Levantar el entorno y preparar la infraestructura

```bash
cd 0.tarea
./setup.sh
```

Este script se encarga de dejar todo listo para empezar a trabajar. En concreto:
- Levanta todos los contenedores Docker (brokers, Connect, ksqlDB, MySQL, MongoDB, etc.)
- Crea la tabla `sales_transactions` en MySQL
- Instala los plugins necesarios de los conectores (Datagen, JDBC, MongoDB, transform-common)
- Copia el driver JDBC de MySQL al contenedor de Connect
- Copia los schemas Avro al contenedor de Connect
- Reinicia Connect para que cargue correctamente los plugins

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

### Paso 4: Crear streams y tablas ksqlDB (ejecutar las queries ksqlDB)

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

### Paso 5: Validar el pipeline completo

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

### Paso 6: Parada del entorno

```bash
cd 0.tarea
./shutdown.sh
```

> **Nota:** El estado de los contenedores no se persiste. Los datos y el estado del cluster se perderán al detener el entorno.

## Detalle de las Tareas

### Tarea 1: Generacion de Datos Sinteticos (Datagen → sensor-telemetry)

**Objetivo:** configurar un source connector que genere eventos de forma continua en el topic `sensor-telemetry` simulando datos realistas de sensores (temperatura, humedad, fertilidad del suelo).

> **Output:** topic Kafka `sensor-telemetry` con mensajes serializados en Avro.

**¿Cómo se generan los datos?**

Datagen utiliza un schema Avro que incluye algunas anotaciones especiales en `arg.properties`. Estas anotaciones le indican al conector cómo debe generar el valor de cada campo:
- `options`: elige aleatoriamente entre una lista de valores definidos
- `range`: genera un número aleatorio dentro de un rango (`min` y `max`)
- `iteration`: genera valores incrementales a partir de un `start` y un `step`

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

**4. `soil_fertility`**

No se definen reglas de anomalía para este campo.

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
| `connector.class` | `DatagenConnector` | Clase Java del conector. Kafka Connect la utiliza para cargar el conector desde el plugin correspondiente. |
| `kafka.topic` | `sensor-telemetry` | Topic destino donde se publican los eventos generados. |
| `schema.filename` | `/home/appuser/sensor-telemetry.avsc` | Ruta al schema Avro dentro del contenedor. Este archivo se copia ahí durante la ejecución del script de setup. |
| `schema.keyfield` | `sensor_id` | Campo del schema que se usa como clave del mensaje. Esto permite que los eventos del mismo sensor vayan a la misma partición (manteniendo el orden por sensor). |
| `max.interval` | `1000` | Intervalo máximo, en milisegundos, entre mensajes. Con un valor de 1000, se genera aproximadamente 1 mensaje por segundo. |
| `iterations` | `10000000` | Número total de mensajes (eventos) que se generarán. |
| `tasks.max` | `1` | Número máximo de tareas del conector. |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | Define cómo se serializa el valor del mensaje. En este caso, se utiliza Avro antes de enviarlo a Kafka. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL interna del Schema Registry dentro de la red de Docker, donde se registran y consultan los schemas Avro. |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | Define cómo se serializa la clave del mensaje. Aquí se utiliza un string plano (el `sensor_id`). |


### Tarea 2: Integracion MySQL (MySQL → sales-transactions)

**Objetivo:** Las transacciones se almacenan en una base de datos MySQL. El objetivo es llevar esos datos a Kafka para poder procesarlos en streaming (en la Tarea 4).

> **Input:** tabla `sales_transactions` en MySQL con columnas `transaction_id`, `product_id`, `category`, `quantity`, `price`, `timestamp`. \
> **Output:** topic Kafka `sales-transactions` con los registros serializados en Avro.

### Cómo se puebla la tabla MySQL

La tabla `sales_transactions` no tiene datos estáticos, sino que se va llenando automáticamente mediante dos conectores:

1. **`source-datagen-_transactions`**: genera transacciones sintéticas a partir del schema `transactions.avsc` y las publica en el topic `_transactions`.
2. **`sink-mysql-_transactions`**: consume esos datos del topic `_transactions` y los inserta en la tabla `sales_transactions` en MySQL.

En conjunto, este flujo (Datagen → `_transactions` → MySQL) simula un sistema de ventas que está generando datos continuamente, lo que permite tener información actualizada para que el JDBC Source pueda capturarla.

#### El topic `_transactions`

El topic `_transactions` no se crea en el script `create-topics.sh` ni se menciona explícitamente en la descripción de la tarea. Aun así, es una pieza clave para que todo el pipeline funcione correctamente.

**¿Quién lo crea?** Se crea automáticamente cuando el conector Datagen (`source-datagen-_transactions`) empieza a producir mensajes. Esto es posible porque Kafka tiene activada por defecto la opción `auto.create.topics.enable=true`. Es decir, si un producer escribe en un topic que aún no existe, Kafka lo crea en ese momento.

Al crearse de esta forma, utiliza la configuración por defecto del broker (1 partición y replication factor 1).

Este topic actúa simplemente como puente entre Datagen y el conector JDBC Sink que inserta los datos en MySQL. No se utiliza en ksqlDB ni forma parte de ningún otro procesamiento dentro del pipeline.

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

El connector Datagen `source-datagen-_transactions` lo referencia en su configuración:

```json
"schema.filename": "/home/appuser/transactions.avsc",
"schema.keyfield": "transaction_id"
```

El fichero `.avsc` se copia al contenedor `connect` durante el `setup.sh`:

```bash
docker cp ../0.tarea/datagen/transactions.avsc connect:/home/appuser/
```

#### ¿Por qué el schema no tiene el campo `timestamp`?

El schema Avro define **5 campos**, mientras que la tabla en MySQL tiene **6 columnas** (incluyendo `timestamp`). Esto se debe a que el campo `timestamp` no lo genera Datagen, sino que lo añade automáticamente MySQL al insertar cada fila, usando `DEFAULT CURRENT_TIMESTAMP`.

De esta forma, cada registro guarda el momento exacto en el que se escribió en la base de datos.

Este campo es el que luego utiliza el JDBC Source Connector en modo `timestamp` para identificar y capturar las nuevas filas.

### Diseño de la Tabla MySQL

### Aspectos a destacar de la tabla `sales_transactions`

- **`timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP`**: MySQL asigna automáticamente la fecha y hora en el momento de la inserción. Esta columna es la que utiliza el conector JDBC en modo incremental para detectar nuevos registros.
- **PRIMARY KEY compuesta** (`transaction_id`, `timestamp`): permite que un mismo transaction_id aparezca varias veces, siempre que tenga distintos timestamps.

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

#### Desglose de propiedades:

| Propiedad | Valor | Explicación |
|---|---|---|
| `connection.url` | `jdbc:mysql://mysql:3306/db?...` | URL JDBC al container MySQL. `mysql` es el hostname en la red Docker. |
| `table.whitelist` | `sales_transactions` | Lista de tablas a leer. |
| `mode` | `timestamp` | Modo incremental que detecta filas nuevas comparando el valor de la columna `timestamp` con el último valor procesado. |
| `timestamp.column.name` | `timestamp` | Columna `TIMESTAMP` de MySQL usada para detectar nuevos registros (tracking incremental). |
| `topic.prefix` | `""` | Prefijo vacío, el nombre del topic se controla mediante la SMT `RegexRouter`. |
| `poll.interval.ms` | `5000` | Cada 5 segundos el connector consulta MySQL buscando filas nuevas. |
| `value.converter` | `io.confluent.connect.avro.AvroConverter` | Serializa en Avro antes de enviarse a Kafka. El schema se genera automáticamente a partir de la estructura de la tabla MySQL. |
| `key.converter` | `org.apache.kafka.connect.storage.StringConverter` | La key se serializa como string plano. |

### SMTs (Single Message Transforms)

Las SMTs son pequeñas transformaciones que se aplican a cada mensaje dentro del conector, justo antes de enviarlo a Kafka. No hace falta escribir código: se configuran directamente en el JSON del connector.

En este caso, utilizamos 3 SMTs encadenadas, que se ejecutan en el orden en el que aparecen en la propiedad `transforms`:

```
MySQL Row → [createKey] → [extractString] → [routeTopic] → Kafka
```

**SMT 1: `createKey` (ValueToKey)**

```json
"transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
"transforms.createKey.fields": "transaction_id"
```

Por defecto, el JDBC Source Connector envía los mensajes sin clave (key = null). Esta SMT copia el campo `transaction_id` del value al key del mensaje. Tener una clave es importante porque:

- Permite particionar por `transaction_id` (los mensajes con el mismo ID van siempre a la misma partición)
- ksqlDB necesita una key para poder definir streams con columnas `KEY`

**SMT 2: `extractString` (ExtractField$Key)**

```json
"transforms.extractString.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
"transforms.extractString.field": "transaction_id"
```

Después de aplicar `ValueToKey`, la clave queda en formato struct, algo así como: `{"transaction_id": "tx12345"}`. Esta SMT extrae únicamente el valor del campo para dejar una key simple: `"tx12345"`. Esto es necesario porque el `key.converter` está configurado como `StringConverter`, que espera un string plano, no un struct.

**SMT 3: `routeTopic` (RegexRouter)**

```json
"transforms.routeTopic.type": "org.apache.kafka.connect.transforms.RegexRouter",
"transforms.routeTopic.regex": "sales_transactions",
"transforms.routeTopic.replacement": "sales-transactions"
```

El JDBC Source Connector genera el nombre del topic combinando `topic.prefix + table_name`. Con `topic.prefix = ""` y tabla `sales_transactions`, el resultado sería `sales_transactions` (con guion bajo). Con la tabla `sales_transactions` y cualquier prefijo, no se obtiene `sales-transactions` directamente. Esta SMT aplica una regex para renombrar el topic.

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

### Tarea 3: Procesamiento de Sensores con ksqlDB

**Objetivo:** Los sensores IoT de FarmIA envían datos de forma continua al topic `sensor-telemetry` (Tarea 1). A partir de ahí, necesitamos procesar esa información en tiempo real y detectar posibles anomalías que puedan afectar a los cultivos. 

**Reglas de anomalía:**
- **HIGH_TEMPERATURE:** temperatura > 35 °C
- **LOW_HUMIDITY:** humedad < 20 %

> **Input:** topic `sensor-telemetry` (Avro) \
> **Output:** topic `sensor-alerts` (Avro)

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

Para este caso, donde básicamente necesitamos aplicar filtros (`WHERE`) y algunas agregaciones (`GROUP BY`), ksqlDB es una opción muy práctica. Permite trabajar directamente con SQL, sin tener que compilar código, generar JARs ni desplegar aplicaciones adicionales.

### Queries de ksqlDB

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

**¿Qué hace?** Define un stream sobre el topic `sensor-telemetry`. No mueve datos ni crea nada nuevo; simplemente le indica a ksqlDB cómo debe interpretar los mensajes que llegan a ese topic. 

**Nota:**

- **STREAM** vs **TABLE**
  - **STREAM  (El flujo de eventos):** Representa el historial completo de lo que ha sucedido. Es inmutable y cada dato es un evento nuevo.
  - **TABLE (El estado actual):** Representa el estado actual o una "foto" de los datos. Es mutable (los valores se actualizan según su clave).
  - **En nuestro contexto:** Un STREAM es una secuencia inmutable de eventos (append-only). Cada lectura de sensor es un evento nuevo, no una actualización de uno anterior. Por eso usamos STREAM y no TABLE.
- **`` `timestamp` ``** (con backticks): `timestamp` es una palabra reservada en ksqlDB, ya que se utiliza para referirse al `ROWTIME` del mensaje. Al escribirlo entre backticks, evitamos ese conflicto y dejamos claro que nos estamos refiriendo a nuestro propio campo dentro del schema, y no al `ROWTIME`. 

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

**¿Qué hace?** Crea una *query persistente*, es decir, una transformación que se ejecuta continuamente en background. Cada vez que llega un nuevo mensaje a `sensor_telemetry_stream` que cumple la condición (`temperature > 35` o `humidity < 20`), se genera una alerta y se escribe en el topic `sensor-alerts`.

**Nota:**

- **CSAS (CREATE STREAM AS SELECT)**: Es la forma que tiene ksqlDB de definir pipelines de procesamiento continuo. A diferencia de un `SELECT` normal (que devuelve resultados y termina), un CSAS:
  - Crea un nuevo topic en Kafka (`sensor-alerts`)
  - Lanza una query persistente que se ejecuta indefinidamente
  - Genera un nuevo mensaje en el topic de destino por cada evento que cumple la condición
- **`EMIT CHANGES`**: Es obligatorio en queries sobre streams en ksqlDB. Indica que los resultados se emiten en tiempo real conforme llegan nuevos eventos.

### Tarea 4: Procesamiento de Ventas con ksqlDB

**Objetivo:** Las transacciones de ventas de FarmIA se envían al topic `sales-transactions` desde MySQL (Tarea 2). A partir de estos datos, el negocio necesita tener una visión en tiempo real de los ingresos por categoría de producto. 

Para conseguirlo, se agrupan las ventas en ventanas de 1 minuto, se calculan los totales por categoría y publican estos resúmenes en tiempo real.

> **Input:** topic `sales-transactions` (Avro) \
> **Output:** topic `sales-summary` (Avro)

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

#### 1. Tumbling Window

Una Tumbling Window (ventana de salto o fija) es una técnica de procesamiento de datos en tiempo real que divide un flujo continuo en intervalos de tiempo fijos, contiguos y sin superposición. Cada evento pertenece exclusivamente a una sola ventana, lo que permite agrupar datos de forma ordenada, como sumar ventas cada 5 minutos.

#### 2. STREAM vs TABLE en contexto de agregación

Cuando haces un `GROUP BY` en ksqlDB, el resultado siempre es una **TABLE**, no un STREAM. Esto se debe a que una agregación necesita mantener estado: por ejemplo, el total de ventas de "fertilizers" entre las 12:00 y las 12:01 se va actualizando a medida que llegan nuevas ventas en ese intervalo.

### Queries de ksqlDB:

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

- **`transaction_id VARCHAR KEY`**: es la clave del mensaje, y la establecen las SMTs del conector JDBC (Tarea 2).

- **`VALUE_FORMAT = 'AVRO'`**: los datos llegan desde el conector JDBC, que los serializa en formato Avro usando Schema Registry.

- **`` `timestamp` ``** (con backticks): igual que en la Tarea 3, se escapa porque es una palabra reservada.

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

**¿Qué hace?** Crea una query persistente que:
1. Lee los datos del stream `sales_transactions_stream`
2. Agrupa los eventos por `category` en ventanas de 1 minuto
3. Calcula, para cada grupo, la cantidad total y el revenue acumulado
4. Publica el resultado en el topic `sales-summary`

**Conceptos clave:**

- **`WINDOW TUMBLING (SIZE 1 MINUTE)`**: define ventanas fijas de 1 minuto que no se solapan. Cada evento se asigna a su ventana en función del ROWTIME.

- **`SUM(quantity * price) AS total_revenue`**: calcula el ingreso total sumando (cantidad × precio unitario) dentro de cada ventana y categoría.

- **`WINDOWSTART` / `WINDOWEND`**: son columnas que genera automáticamente ksqlDB y que indican el inicio y fin de cada ventana en epoch millis. No hace falta declararlas.

- **`GROUP BY category`**: agrupa los datos por categoría de producto. Las posibles categorías son: fertilizers, seeds, pesticides, equipment, supplies y soil (definidas en el schema `transactions.avsc`).

### Tarea 5: Integracion de MongoDB (sensor-alerts → MongoDB)

**Objetivo:** Las alertas de anomalías que genera ksqlDB (Tarea 3) se envían al topic `sensor-alerts`. A partir de ahí, necesitamos almacenarlas en una base de datos para poder consultarlas, analizarlas con el tiempo y utilizarlas en dashboards.

MongoDB es una buena opción en este caso, ya que permite guardar los datos como documentos sin necesidad de definir un esquema rígido desde el principio.

> **Input:** topic `sensor-alerts` (Avro, producido por ksqlDB en la Tarea 3) \
> **Output:** colección `sensor_alerts` en MongoDB (base de datos `farmia`)

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
    "database": "farmia",
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
| `connector.class` | `MongoSinkConnector` | Connector oficial de MongoDB para Kafka. Instalado durante el `setup.sh`. |
| `connection.uri` | `mongodb://admin:secret123@mongodb:27017` | URI de conexión a MongoDB. |
| `database` | `farmia` | Base de datos destino. Se crea automáticamente si no existe. |
| `collection` | `sensor_alerts` | Colección destino. También se crea automáticamente. |
| `topics` | `sensor-alerts` | Topic de Kafka a consumir. |
| `key.converter` | `StringConverter` | La key del mensaje es un string (el `sensor_id`). |
| `value.converter` | `AvroConverter` | Las alertas fueron escritas en Avro por ksqlDB (Tarea 3), así que usamos AvroConverter para deserializarlas. |
| `value.converter.schema.registry.url` | `http://schema-registry:8081` | URL del Schema Registry para resolver el schema Avro de las alertas. |

---

## Problemas Detectados

Durante las pruebas del pipeline apareció un problema importante relacionado con la visualización de los datos. Esto obligó a ajustar la configuración del conector JDBC Source. A continuación se describe qué pasaba, por qué ocurría y cómo se solucionó.

### Problema: campo `price` ilegible en el topic `sales-transactions`

**Síntoma:** Al revisar los mensajes del topic `sales-transactions` en Confluent Control Center, el campo `price` mostraba caracteres extraños en lugar de valores numéricos:

```
{"transaction_id":"tx99122", ..., "price":"\u0018♦", ...}
{"transaction_id":"tx41116", ..., "price":"\u0013♦", ...}
{"transaction_id":"tx72133", ..., "price":"@>", ...}
```

El **origen del problema**, es la incompatibilidad de tipos entre MySQL y el mapeo automático de Avro.

La clave está en que el JDBC Source Connector genera su propio esquema Avro a partir de la tabla en MySQL. Es decir, no reutiliza el esquema del Datagen (`transactions.avsc`). Por eso, aunque en Datagen el campo `price` se define como `float`, el conector JDBC lee un `DECIMAL(10,2)` desde MySQL y lo serializa como `bytes`.


**Solución aplicada: SMT `Cast$Value`**

Para solucionarlo, se añadió una nueva SMT al inicio de la cadena de transformaciones del conector:

```json
"transforms.castPrice.type": "org.apache.kafka.connect.transforms.Cast$Value",
"transforms.castPrice.spec": "price:float64"
```

Esta transformación convierte el campo `price` de tipo `DECIMAL` (representado como bytes) a `float64` (equivalente a double en Avro) antes de que se serialice. De esta forma, los valores pasan a ser numéricos y se pueden leer correctamente.

---

## Comandos Útiles

```bash
# ────── Docker ──────
cd 1.environment
docker compose up -d                              # Levantar todo
docker compose down --remove-orphans              # Parar todo
docker compose down -v                            # Reset completo (borra datos)
docker compose logs connect -f                    # Logs de Connect en tiempo real

# ────── Topics ──────
docker exec broker-1 kafka-topics --list --bootstrap-server broker-1:29092
docker exec broker-1 kafka-topics --describe --topic sensor-telemetry --bootstrap-server broker-1:29092

# ────── Consumir mensajes ──────
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

# ────── Schema Registry ──────
curl -s http://localhost:8081/subjects | jq
curl -s http://localhost:8081/subjects/sensor-telemetry-value/versions/latest | jq

# ────── Kafka Connect ──────
curl -s http://localhost:8083/connectors | jq
curl -s http://localhost:8083/connectors/source-datagen-sensor-telemetry/status | jq
curl -s http://localhost:8083/connectors/source-mysql-sales_transactions/status | jq
curl -s http://localhost:8083/connectors/sink-mongodb-sensor_alerts/status | jq

# ────── ksqlDB ──────
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088

# ────── MySQL ──────
docker exec -it mysql mysql --user=root --password=password --database=db

# ────── MongoDB ──────
docker exec -it mongodb mongosh --username admin --password secret123 --authenticationDatabase admin

# ────── URLs de servicios ──────
# Control Center:   http://localhost:9021
# Schema Registry:  http://localhost:8081
# Kafka Connect:    http://localhost:8083
# ksqlDB:           http://localhost:8088
```




