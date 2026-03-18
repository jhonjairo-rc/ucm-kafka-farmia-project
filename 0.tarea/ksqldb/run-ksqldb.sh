#!/bin/bash

# Script para ejecutar las queries ksqlDB

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KSQL_URL="http://ksqldb-server:8088"

echo "Ejecutando queries ksqlDB..."

echo ""
echo "1. Creando stream de sensor-telemetry y alertas (01-sensor-alerts.sql)..."
{ echo "SET 'auto.offset.reset' = 'earliest';"; cat "$SCRIPT_DIR/01-sensor-alerts.sql"; } \
  | docker exec -i ksqldb-cli ksql $KSQL_URL

echo ""
echo "2. Creando stream de sales-transactions y tabla de resumen (02-sales-summary.sql)..."
{ echo "SET 'auto.offset.reset' = 'earliest';"; cat "$SCRIPT_DIR/02-sales-summary.sql"; } \
  | docker exec -i ksqldb-cli ksql $KSQL_URL

echo ""
echo "Queries ksqlDB ejecutadas correctamente."
echo "Verificar con: docker exec -it ksqldb-cli ksql $KSQL_URL"
