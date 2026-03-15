# El topic `_transactions`: por que no se crea manualmente

## No hace falta crearlo manualmente

El topic `_transactions` se **autocrea** cuando el connector Datagen (`source-datagen-_transactions`) empieza a producir mensajes. Kafka tiene habilitado por defecto `auto.create.topics.enable=true`, asi que cuando un producer escribe a un topic que no existe, Kafka lo crea sobre la marcha.

**El problema** es que al autocrearse, usa la configuracion por defecto del broker:
- 1 particion (en vez de 3)
- Replication factor 1 (en vez de 3)

Para el topic `_transactions` esto es aceptable porque es un **topic interno/auxiliar** que solo sirve de puente entre el Datagen y el JDBC Sink que escribe en MySQL. No se consume directamente ni se procesa en ksqlDB. Es "fontaneria" del proyecto, no un topic de negocio.

## Donde aparece `_transactions` en el proyecto

Solo en **3 sitios funcionales**:

| Fichero | Rol |
|---|---|
| `source-datagen-_transactions.json` | Produce al topic `_transactions` |
| `sink-mysql-_transactions.json` | Consume de `_transactions` y escribe en MySQL |
| `validation/validate.sh` | Lo lista al validar (junto con los demas topics) |

El resto de apariciones son documentacion (README, CLAUDE.md, etc.).

## El flujo completo

```
source-datagen-_transactions     sink-mysql-_transactions       source-mysql-sales_transactions
        │                                │                                │
        ▼                                ▼                                ▼
   Genera datos ──→ _transactions ──→ MySQL(sales_transactions) ──→ sales-transactions
   (topic auxiliar)                   (tabla real)                  (topic de negocio)
```

El topic `_transactions` es un intermediario: alimenta MySQL para que el JDBC Source tenga datos frescos que leer. No aparece en el enunciado porque es infraestructura proporcionada por el profesor, no parte de las tareas del alumno.

## Schema del topic `_transactions`

El topic usa el schema Avro definido en `0.tarea/datagen/transactions.avsc`:

```json
{
  "namespace": "com.farmia.sales",
  "name": "SalesTransaction",
  "type": "record",
  "fields": [...]
}
```

| Campo | Tipo | Generacion |
|---|---|---|
| `transaction_id` | string | Regex `tx[1-9]{5}` → ej: `tx34521` |
| `product_id` | string | Regex `prod_[1-9]{3}` → ej: `prod_472` |
| `category` | string | Aleatorio entre: fertilizers, seeds, pesticides, equipment, supplies, soil |
| `quantity` | int | Rango 1-10 |
| `price` | float | Rango 10.00-200.00 |

El connector Datagen lo referencia en su configuracion:

```json
"schema.filename": "/home/appuser/transactions.avsc",
"schema.keyfield": "transaction_id"
```

Este fichero `.avsc` se copia al container `connect` durante el `setup.sh` (igual que el de sensor-telemetry):

```bash
docker cp ../0.tarea/datagen/transactions.avsc connect:/home/appuser/
```

**Dato importante:** este schema no incluye campo `timestamp`. El timestamp lo añade MySQL automaticamente con `DEFAULT CURRENT_TIMESTAMP` cuando el JDBC Sink inserta la fila. Por eso en la tabla MySQL hay 6 columnas pero el schema Avro solo tiene 5 campos.

## Conclusion

No necesitas crearlo. Se autocrea y funciona correctamente. Si quisieras crearlo explicitamente con 3 particiones y RF=3 (para ser consistente), podrias añadirlo al `create-topics.sh`, pero no es necesario para que el pipeline funcione.
