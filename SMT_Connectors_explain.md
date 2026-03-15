# Por que cada connector tiene atributos diferentes y el papel de las SMTs

## Por que cada connector tiene atributos diferentes

Cada connector es un **plugin independiente** desarrollado por un equipo distinto (Datagen por Confluent, JDBC tambien por Confluent pero con otra API, MongoDB por MongoDB Inc.). Cada uno define sus propias propiedades de configuracion segun su logica interna.

No existe un "estandar universal" de propiedades — solo las que define Kafka Connect como framework (`connector.class`, `tasks.max`, `key.converter`, `value.converter`). El resto son especificas de cada plugin.

### Datagen: `kafka.topic` y `schema.keyfield`

Datagen **genera datos de la nada**, asi que necesita que le digas explicitamente:
- **A donde** enviar los mensajes → `kafka.topic`
- **Que campo** usar como key → `schema.keyfield`

No tiene otra forma de saberlo — no hay un sistema externo del que inferir esta informacion.

### JDBC Source: no tiene esas propiedades

El JDBC Source **lee de una tabla MySQL**, asi que:
- **El topic** se deriva automaticamente: `topic.prefix` + nombre de la tabla. No tiene una propiedad `kafka.topic` porque puede leer multiples tablas y genera un topic por tabla.
- **La key** por defecto es null, porque el connector no sabe que campo de tu tabla deberia ser la key del mensaje Kafka. Una tabla puede tener primary keys compuestas, campos tecnicos, etc. — la decision de que campo usar como key es de negocio, no del connector.

### Comparacion directa

```
                        Datagen              JDBC Source
                        ───────              ───────────
¿De donde vienen        Se inventan          Se leen de MySQL
los datos?

¿Como sabe el           kafka.topic          topic.prefix + table_name
topic destino?          (explicito)          (derivado automaticamente)

¿Como sabe              schema.keyfield      No lo sabe → key = null
la key?                 (explicito)          (necesitas SMTs para crearla)

¿Necesita SMTs          No                   Si, para:
para key/topic?                              - crear la key (ValueToKey)
                                             - renombrar el topic (RegexRouter)
```

---

## Por que necesitamos definir topics y keys

### Topics: el "buzon" del mensaje

El topic es la **direccion de destino**. Sin topic, Kafka no sabe donde almacenar el mensaje. Es como enviar una carta sin direccion — se pierde.

Cada connector debe saber a que topic escribir. La diferencia es *como* lo averigua:
- Datagen: se lo dices tu directamente (`kafka.topic`)
- JDBC: lo calcula automaticamente (`topic.prefix` + nombre de tabla)
- Ambos llegan al mismo resultado: un mensaje publicado en un topic concreto

### Keys: por que importan

La key del mensaje determina **dos cosas criticas**:

**1. Particionamiento**

```
Mensajes sin key (null):
  → Kafka los reparte por round-robin entre las 3 particiones
  → Mensajes del mismo sensor pueden acabar en particiones distintas
  → No hay garantia de orden

Mensajes con key (sensor_id):
  → Kafka aplica hash(key) % num_particiones
  → sensor_001 siempre va a particion 1
  → sensor_003 siempre va a particion 0
  → Orden garantizado dentro de cada sensor
```

**2. ksqlDB necesita la key**

Cuando en ksqlDB declaramos:

```sql
CREATE STREAM sensor_telemetry_stream (
    sensor_id VARCHAR KEY,    -- ← esto referencia la key del mensaje
    ...
```

Si la key fuera null, ksqlDB no podria asociar el campo `sensor_id` como key del stream. Las operaciones de `GROUP BY`, joins y reparticionado dependen de que los mensajes tengan key.

---

## Es correcta la interpretacion sobre las SMTs

Si, es correcta. Las SMTs en el JDBC connector compensan lo que Datagen hace nativamente:

```
Lo que necesitamos          Datagen lo resuelve con     JDBC lo resuelve con
──────────────────          ───────────────────────     ────────────────────
Topic correcto              kafka.topic                 RegexRouter (SMT)
Key del mensaje             schema.keyfield             ValueToKey + ExtractField (SMTs)
```

Las SMTs no son la unica forma — el JDBC connector tiene un modo `incrementing` que puede usar una columna como key de forma nativa. Pero para nuestro caso (key = `transaction_id` como string plano + topic renombrado), las SMTs son la solucion mas limpia y flexible.

**En resumen:** las SMTs existen precisamente para estos casos — cuando el connector no ofrece una propiedad directa para lo que necesitas, las SMTs te permiten transformar el mensaje "en vuelo" sin escribir codigo.
