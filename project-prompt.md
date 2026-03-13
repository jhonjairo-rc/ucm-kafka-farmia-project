Estás ayudándome a completar un proyecto de Apache Kafka que forma parte de un máster que estoy cursando.

Tu objetivo es generar todos los archivos, la estructura del proyecto y la documentación necesaria para completar la tarea de forma end-to-end.

Debes seguir cuidadosamente las instrucciones y respetar todas las restricciones.

--------------------------------------------------
CONTEXTO DEL PROYECTO
--------------------------------------------------

El objetivo del proyecto es familiarizar al alumno con tecnologías del ecosistema Kafka aplicadas a un caso de uso real.

Primero debes leer el fichero:

kafka-procesamiento-en-tiempo-real-tarea

y seguir las instrucciones que se describen en él.

Para tener más contexto, también puedes leer los ficheros README.md que se encuentran en:

- 0.tarea
- 1.environment

Estos directorios contienen información complementaria que te ayudará a entender el entorno y los objetivos de la tarea.

--------------------------------------------------
TOPICS QUE SE DEBEN CREAR
--------------------------------------------------

Debes crear los siguientes topics Kafka:

sensor-telemetry  
sales-transactions  
sensor-alerts  
sales-summary  

Estos topics deben configurarse como si fueran para un entorno productivo:

- definir particiones
- definir factor de replicación
- definir configuraciones relevantes

IMPORTANTE:
En el documento de la tarea no se menciona explícitamente la creación de topics, pero deben crearse para que el proyecto sea completamente ejecutable.

--------------------------------------------------
RESTRICCIÓN IMPORTANTE DE TECNOLOGÍA
--------------------------------------------------

Debes usar siempre:

KSQLDB

No debes usar:

Kafka Streams  
Apache Flink  

Aunque el documento mencione estas tecnologías, la implementación debe hacerse con KSQLDB.

--------------------------------------------------
DIRECTORIO A IGNORAR
--------------------------------------------------

Ignora completamente el directorio:

0.tarea/src

Contiene código Java que no se debe utilizar.

--------------------------------------------------
ENTORNO DOCKER
--------------------------------------------------

El entorno del proyecto ya incluye un docker-compose ubicado en:

1.environment/docker-compose.yaml

Este docker-compose levanta:

- múltiples brokers Kafka
- controladores
- Kafka Connect
- ksqlDB
- otros servicios

Debes tener en cuenta esta configuración al definir:

- factor de replicación
- particiones
- configuración de topics

--------------------------------------------------
DÓNDE COLOCAR LOS ARCHIVOS GENERADOS
--------------------------------------------------

Todos los archivos que generes deben colocarse dentro de:

0.tarea/

Puedes crear subdirectorios organizados como por ejemplo:

- topics
- config
- ksqldb
- mysql
- scripts
- python
- validation
- docs

--------------------------------------------------
ARCHIVOS EXISTENTES
--------------------------------------------------

Existen archivos ya creados en el proyecto (.yaml, .sh, etc.) que deben reutilizarse.

Si detectas problemas en estos archivos puedes modificarlos, pero debes explicar:

- qué has cambiado
- por qué lo has cambiado

--------------------------------------------------
VALIDACIÓN
--------------------------------------------------

Debes incluir comandos para validar que todo funciona correctamente:

- creación de topics
- estado de Kafka Connect
- mensajes producidos
- consultas en KSQLDB
- datos escritos en MongoDB

--------------------------------------------------
README OBLIGATORIO
--------------------------------------------------

Debes generar un archivo:

README.md

en la raíz del proyecto.

El README debe incluir:

- explicación del proyecto
- arquitectura
- pasos para levantar el entorno
- pasos para crear topics
- pasos para ejecutar conectores
- pasos para ejecutar queries KSQLDB
- orden de ejecución
- comandos de validación

También debes incluir diagramas Mermaid que expliquen:

- arquitectura Kafka
- flujo de datos
- interacción entre servicios

--------------------------------------------------
OBJETIVO FINAL
--------------------------------------------------

El resultado final debe ser un proyecto completo Kafka + Kafka Connect + KSQLDB + MongoDB que pueda ejecutarse end-to-end y que pueda entregarse como trabajo del máster.