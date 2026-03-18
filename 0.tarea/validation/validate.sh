#!/bin/bash

# Script de validacion del proyecto FarmIA

echo "========================================"
echo "  VALIDACION DEL PROYECTO FARMIA"
echo "========================================"

echo ""
echo "1. Verificando topics de Kafka..."
echo "----------------------------------------"
docker exec broker-1 kafka-topics --list --bootstrap-server broker-1:29092

echo ""
echo "2. Detalle de los topics del proyecto..."
echo "----------------------------------------"
for topic in sensor-telemetry sales-transactions sensor-alerts sales-summary _transactions; do
  echo "--- $topic ---"
  docker exec broker-1 kafka-topics --describe --bootstrap-server broker-1:29092 --topic $topic 2>/dev/null
  echo ""
done

echo ""
echo "3. Estado de los conectores de Kafka Connect..."
echo "----------------------------------------"
echo "Conectores activos:"
curl -s http://localhost:8083/connectors | jq .
echo ""

for connector in source-datagen-_transactions sink-mysql-_transactions source-datagen-sensor-telemetry source-mysql-sales_transactions sink-mongodb-sensor_alerts; do
  echo "--- $connector ---"
  curl -s http://localhost:8083/connectors/$connector/status 2>/dev/null | jq .
  echo ""
done

echo ""
echo "4. Verificando mensajes en sensor-telemetry (ultimos 3)..."
echo "----------------------------------------"
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-telemetry \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 10000 2>/dev/null || echo "No se pudieron leer mensajes"

echo ""
echo "5. Verificando mensajes en sales-transactions (ultimos 3)..."
echo "----------------------------------------"
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sales-transactions \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 10000 2>/dev/null || echo "No se pudieron leer mensajes"

echo ""
echo "6. Verificando mensajes en sensor-alerts (ultimos 3)..."
echo "----------------------------------------"
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sensor-alerts \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 10000 2>/dev/null || echo "No se pudieron leer mensajes"

echo ""
echo "7. Verificando mensajes en sales-summary (ultimos 3)..."
echo "----------------------------------------"
docker exec broker-1 kafka-console-consumer \
  --bootstrap-server broker-1:29092 \
  --topic sales-summary \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 10000 2>/dev/null || echo "No se pudieron leer mensajes"

echo ""
echo "8. Verificando queries ksqlDB..."
echo "----------------------------------------"
docker exec -i ksqldb-cli ksql http://ksqldb-server:8088 <<'EOF'
SHOW STREAMS;
SHOW TABLES;
SHOW QUERIES;
EOF

echo ""
echo "9. Verificando datos en MongoDB (sensor_alerts)..."
echo "----------------------------------------"
docker exec mongodb mongosh \
  --username admin \
  --password secret123 \
  --authenticationDatabase admin \
  --quiet \
  --eval "db = db.getSiblingDB('farmia'); print('Documentos en sensor_alerts: ' + db.sensor_alerts.countDocuments()); printjson(db.sensor_alerts.find().sort({_id:-1}).limit(3).toArray());"

echo ""
echo "========================================"
echo "  VALIDACION COMPLETADA"
echo "========================================"
