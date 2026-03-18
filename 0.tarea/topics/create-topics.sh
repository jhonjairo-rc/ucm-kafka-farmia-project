#!/bin/bash

# Script para crear los topics de Kafka
# Debe ejecutarse una vez que el entorno Docker esté levantado

BROKER="broker-1:29092"

echo "Creando topics de Kafka..."

# sensor-telemetry: datos IoT de sensores agricolas
docker exec broker-1 kafka-topics --create \
  --bootstrap-server $BROKER \
  --topic sensor-telemetry \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete \
  --config max.message.bytes=64000 \
  --if-not-exists

# sales-transactions: datos de transacciones de ventas desde MySQL
docker exec broker-1 kafka-topics --create \
  --bootstrap-server $BROKER \
  --topic sales-transactions \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete \
  --config max.message.bytes=64000 \
  --if-not-exists

# sensor-alerts: alertas generadas por ksqlDB al detectar anomalias
docker exec broker-1 kafka-topics --create \
  --bootstrap-server $BROKER \
  --topic sensor-alerts \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete \
  --config max.message.bytes=64000 \
  --if-not-exists

# sales-summary: resumen de ventas agregadas por categoria cada minuto
docker exec broker-1 kafka-topics --create \
  --bootstrap-server $BROKER \
  --topic sales-summary \
  --partitions 3 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete \
  --config max.message.bytes=64000 \
  --if-not-exists

echo ""
echo "Detalle de los topics:"
for topic in sensor-telemetry sales-transactions sensor-alerts sales-summary; do
  echo "--- $topic ---"
  docker exec broker-1 kafka-topics --describe --bootstrap-server $BROKER --topic $topic
  echo ""
done

echo ""
echo "Verificando topics creados..."
docker exec broker-1 kafka-topics --list --bootstrap-server $BROKER

echo "OK"
