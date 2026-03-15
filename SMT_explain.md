# Single Message Transforms (SMT)

## Explicacion tecnica

Las SMTs son funciones de transformacion ligeras que Kafka Connect aplica a **cada mensaje individual** dentro del pipeline del connector, antes de que el mensaje llegue a su destino. Se configuran declarativamente en el JSON del connector (no requieren codigo) y se ejecutan en orden secuencial formando una cadena.

```
Source Connector:
  Sistema externo → [datos crudos] → SMT1 → SMT2 → SMT3 → [datos transformados] → Topic Kafka

Sink Connector:
  Topic Kafka → [datos crudos] → SMT1 → SMT2 → [datos transformados] → Sistema externo
```

Las SMTs operan sobre el **record completo** de Kafka Connect (key + value + headers + metadata) y pueden modificar cualquiera de estas partes. Son stateless: cada mensaje se transforma de forma independiente, sin memoria de mensajes anteriores.

Kafka Connect incluye un conjunto de SMTs built-in (`org.apache.kafka.connect.transforms.*`) y existen plugins de terceros (como `jcustenborder/kafka-connect-transform-common`, que instalamos en nuestro `setup.sh`).

---

## Explicacion sencilla (for dummies)

Imagina que las SMTs son **filtros de Instagram para datos**.

Cuando sacas una foto (el dato crudo), puedes aplicarle filtros antes de publicarla: uno que ajusta el brillo, otro que recorta, otro que añade un marco. Cada filtro hace una sola cosa sencilla, pero encadenados transforman la foto original en algo diferente.

Las SMTs funcionan igual: cada mensaje que pasa por el connector puede pasar por una cadena de "filtros" que lo modifican antes de llegar a su destino. Puedes renombrar campos, quitar campos que no necesitas, cambiar el nombre del topic, extraer la key... todo sin escribir una sola linea de codigo Java.

---

## Como se utilizan en este proyecto

En nuestro proyecto usamos SMTs en el connector JDBC Source (`source-mysql-sales_transactions`). El problema que resuelven es triple:

**Problema 1: MySQL no produce message keys**

El JDBC Source Connector por defecto envia mensajes con key = null. Pero ksqlDB necesita una key para crear streams correctamente, y Kafka necesita una key para particionar los mensajes de forma determinista.

**Problema 2: la key debe ser un string plano**

Nuestro `key.converter` es `StringConverter`, que espera un string simple como `"tx12345"`, no un struct como `{"transaction_id": "tx12345"}`.

**Problema 3: el nombre del topic no coincide con lo que pide el enunciado**

El JDBC connector genera el topic como `topic.prefix + table_name`. Con nuestra tabla `sales_transactions` y cualquier prefijo, no obtenemos `sales-transactions` directamente.

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

En el JSON del connector, esto se configura asi:

```json
{
  "transforms": "createKey,extractString,routeTopic",

  "transforms.createKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
  "transforms.createKey.fields": "transaction_id",

  "transforms.extractString.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
  "transforms.extractString.field": "transaction_id",

  "transforms.routeTopic.type": "org.apache.kafka.connect.transforms.RegexRouter",
  "transforms.routeTopic.regex": "sales_transactions",
  "transforms.routeTopic.replacement": "sales-transactions"
}
```

La propiedad `transforms` define el orden de ejecucion (separados por comas). Luego cada SMT se configura con `transforms.<nombre>.type` y sus propiedades especificas.

---

## Casos de uso mas comunes

| SMT | Que hace | Ejemplo tipico |
|---|---|---|
| **ValueToKey** | Copia campo(s) del value al key | JDBC Source no produce keys → necesitas particionar por un campo de negocio |
| **ExtractField$Key** | Extrae un campo de un struct key | Despues de ValueToKey, convertir `{"id": "123"}` → `"123"` |
| **RegexRouter** | Renombra el topic con regex | Tabla `user_events` → topic `users-events` |
| **ReplaceField$Value** | Incluye/excluye campos | Eliminar columnas tecnicas (`id`, `updated_at`) del mensaje |
| **Cast$Value** | Cambia tipos de datos | Asegurar que un campo `timestamp` sea `int64` (long) |
| **InsertField$Value** | Añade campos con metadata | Inyectar `_kafka_topic` o `_kafka_partition` para trazabilidad |
| **TimestampConverter** | Convierte formatos de fecha | `"2026-01-15T10:30:00Z"` → epoch millis `1768471800000` |
| **MaskField** | Enmascara campos sensibles | Ofuscar un campo `email` o `credit_card` antes de publicar |
| **Flatten** | Aplana structs anidados | `{"address": {"city": "Madrid"}}` → `{"address_city": "Madrid"}` |
| **HeaderFrom** | Mueve campos a headers Kafka | Mover metadata al header para no contaminar el payload |

**Regla practica:** si la transformacion que necesitas es sencilla (renombrar, filtrar campos, cambiar tipos, routing), usa una SMT. Si necesitas logica compleja (joins, lookups, agregaciones, logica condicional avanzada), usa ksqlDB o Kafka Streams.
