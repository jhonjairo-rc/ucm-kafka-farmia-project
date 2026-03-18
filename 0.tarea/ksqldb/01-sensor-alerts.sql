-- ============================================================
-- Tarea 3: Procesamiento en Tiempo Real de sensores
-- ============================================================

-- 1. Crear STREAM sobre el topic sensor-telemetry
CREATE STREAM IF NOT EXISTS sensor_telemetry_stream (
  sensor_id VARCHAR KEY,
  `timestamp` BIGINT,
  temperature DOUBLE,
  humidity DOUBLE,
  soil_fertility DOUBLE
) WITH (
  KAFKA_TOPIC = 'sensor-telemetry',
  VALUE_FORMAT = 'AVRO'
);

-- 2. Crear STREAM de alertas que filtra condiciones anomalas
CREATE STREAM IF NOT EXISTS sensor_alerts_stream
WITH (
  KAFKA_TOPIC = 'sensor-alerts',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 3,
  REPLICAS = 3
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
