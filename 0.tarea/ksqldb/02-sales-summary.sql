-- ============================================================
-- Tarea 4: Procesamiento en Tiempo Real de transacciones de ventas
-- ============================================================

-- 1. Crear STREAM sobre el topic sales-transactions
CREATE STREAM IF NOT EXISTS sales_transactions_stream (
  transaction_id VARCHAR KEY,
  product_id VARCHAR,
  category VARCHAR,
  quantity INT,
  price DOUBLE,
  `timestamp` BIGINT
) WITH (
  KAFKA_TOPIC = 'sales-transactions',
  VALUE_FORMAT = 'AVRO'
);

-- 2. Crear TABLE de resumen de ventas por categoria con ventana de 1 minuto
CREATE TABLE IF NOT EXISTS sales_summary_table
WITH (
  KAFKA_TOPIC = 'sales-summary',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 3,
  REPLICAS = 3
) AS
SELECT
  category,
  SUM(quantity) AS total_quantity,
  SUM(quantity * price) AS total_revenue,
  WINDOWSTART AS window_start,
  WINDOWEND AS window_end
FROM sales_transactions_stream
  WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY category
EMIT CHANGES;
