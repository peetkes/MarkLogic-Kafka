# MarkLogic-Kafka
Sample project for testing MarkLogic Kafka connector

## Overview

This project uses the MQTT connector to send events into Kafka and the MarkLogic Kafka connector to sink those events into MarkLogic.

## Setup Using Docker

Docker Compose is used to setup the infrastructure. That includes an MQTT broker as the source, Zookeeper, one Kafka Broker as well as Kafka Connect as middleware and a MarkLogic Instance as the sink.

## Connector Installation

The connectors required for this project, an [MQTT](https://www.confluent.io/hub/confluentinc/kafka-connect-mqtt) source and a [MarkLogic](https://www.confluent.io/hub/marklogic/kafka-marklogic-connector) sink connector, are not included in plain Kafka or the Confluent Platform and can be downloaded from the Confluent Hub.  Unpack the jars into a folder, which will be mounted into the Kafka Connect container as described in the following section.

Move the jars to folder /tmp/custom/jars before starting the compose stack in the following section, as Kafka Connect loads connectors online during startup.

## Docker Compose File

The infrastructure, which consists of six containers, is described in a docker compose file in the folder *docker*.

You can hardcode all hostnames and ports in the docker compose file but you can also put those names and ports into a .env file which have to be sourced before the docker compose command is executed.

See below for a sample .env file
```
DOCKERPROJECT=kafka

mlHost=marklogic-kafka
mlVersionTag=10.0-9.4-centos-1.0.0-ea4
mlSystemPortSrc=8000-8002
mlSystemPortTrg=8000-8002
mlApplicationPortSrc=8010-8020
mlApplicationPortTrg=8010-8020

MQTTHost=mosquitto
MQTTExposePort=1883
MQTTPortSrc=1883
MQTTPortTrg=1883

ZooKeeper=zookeeper
ZooKeeperPortSrc=2181
ZooKeeperPortTrg=2181

Kafka=kafka
KafkaPortSrc=9092
KafkaPortTrg=9092

KafkaConnect=kafka-connect
KafkaConnectPortSrc=8083
KafkaConnectPortTrg=8083
```

This is the docker compose fileused for the project, it defines 5 containers, the host and container names and port mappings are sourced from the above mentioned .env file.

```
version: '3.8'

services:
  marklogic:
    image: marklogicdb/marklogic-db:${mlVersionTag}
    hostname: ${mlHost}
    container_name: ${mlHost}
    ports:
      - ${mlSystemPortSrc}:${mlSystemPortTrg}
      - ${mlApplicationPortSrc}:${mlApplicationPortTrg}
    environment:
      - MARKLOGIC_INIT=true
      - MARKLOGIC_ADMIN_USERNAME_FILE=mldb_admin_user
      - MARKLOGIC_ADMIN_PASSWORD_FILE=mldb_admin_pwd
      - TZ=Europe/Amsterdam
    secrets:
      - mldb_admin_pwd
      - mldb_admin_user
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G

  mosquitto:
    image: eclipse-mosquitto:1.5.5
    hostname: ${MQTTHost}
    container_name: ${MQTTHost}
    expose:
      - ${MQTTExposePort}
    ports:
      - ${MQTTPortSrc}:${MQTTPortTrg}

  zookeeper:
    image: zookeeper:3.4.9
    restart: unless-stopped
    hostname: ${ZooKeeper}
    container_name: ${ZooKeeper}
    environment:
      ZOO_MY_ID: 1
      ZOO_PORT: ${ZooKeeperPortSrc}
      ZOO_SERVERS: server.1=zookeeper:2888:3888
    ports:
      - ${ZooKeeperPortSrc}:${ZooKeeperPortTrg}
    volumes:
      - ./zookeeper/data:/data
      - ./zookeeper/datalog:/datalog

  kafka:
    image: confluentinc/cp-kafka:latest
    hostname: ${Kafka}
    container_name: ${Kafka}
    ports:
      - ${KafkaPortSrc}:${KafkaPortTrg}
    environment:
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${Kafka}:${KafkaPortTrg},PLAINTEXT_HOST://localhost:29092
      KAFKA_ZOOKEEPER_CONNECT: "${ZooKeeper}:${ZooKeeperPortTrg}"
      KAFKA_BROKER_ID: 1
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    volumes:
      - ./kafka/data:/var/lib/kafka/data
    depends_on:
      - zookeeper

  kafka-connect:
    image: confluentinc/cp-kafka-connect:latest
    hostname: ${KafkaConnect}
    container_name: ${KafkaConnect}
    ports:
      - ${KafkaConnectPortSrc}:${KafkaConnectPortTrg}
    environment:
      CONNECT_BOOTSTRAP_SERVERS: "${Kafka}:${KafkaPortTrg}"
      CONNECT_REST_ADVERTISED_HOST_NAME: connect
      CONNECT_REST_PORT: ${KafkaPortTrg}
      CONNECT_GROUP_ID: compose-connect-group
      CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
      CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
      CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_INTERNAL_KEY_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      CONNECT_INTERNAL_VALUE_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_PLUGIN_PATH: '/usr/share/java,/etc/kafka-connect/jars'
      CONNECT_CONFLUENT_TOPIC_REPLICATION_FACTOR: 1
    volumes:
      - /tmp/kafka/custom/jars:/etc/kafka-connect/jars:ro
    depends_on:
      - zookeeper
      - kafka
      - mosquitto
secrets:
  mldb_admin_user:
    file: ./mldb_admin_user.txt
  mldb_admin_pwd:
    file: ./mldb_admin_pwd.txt
```

The *mosquitto* container provides a simple MQTT broker based on Eclipse Mosquitto.
The containers *zookeeper* and *kafka* define a single-node Kafka cluster.
*kafka-connect* defines the Connect application in distributed mode.
And finally, *marklogic* defines our sink database.

Make sure your cursor is in the root folder of the project.
Run the following command to start the stack

```
source docker/.env
docker compose -f docker/docker-compose.yml -p $DOCKERPROJECT up -d
```

This will start all 5 containers in detached mode and  also start a network *kafka_default* which will be used later on when testing the source connector.

## Connector Configuration

Kafka Connect will now be up and running, so the connectors can be configured.

### Configure Source Connector

The source connector can be configured using the REST API.

```
curl -d @./config/connect-mqtt-source.json -H "Content-Type: application/json" -X POST http://localhost:8083/connectors
```

The *connect-mqtt-source.json* file looks like this:

```
{
  "name": "mqtt-source",
  "config": {
    "connector.class": "io.confluent.connect.mqtt.MqttSourceConnector",
    "tasks.max": 1,
    "mqtt.server.uri": "tcp://mosquitto:1883",
    "mqtt.topics": "mqtt.marklogic",
    "kafka.topic": "kafka.marklogic",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "confluent.topic.bootstrap.servers": "kafka:9092",
    "confluent.topic.replication.factor": 1
  }
}
```


- mqtt.server.uri is the endpoint our connector will connect to
- mqtt.topics is the MQTT topic our connector will subscribe to
- kafka.topic defines the Kafka topic the connector will send the received data to
- value.converter defines a converter which will be applied to the received payload. This has to be set to ByteArrayConverter, as the MQTT Connector uses Base64 by default, because we want to use plain text
- confluent.topic.bootstrap.servers is required by the newest version of the connector
- confluent.topic.replication.factor defines the replication factor for a Confluent-internal topic – as there is only one node in the cluster, this has to be set to 1

Make sure the mqtt.server.uri and confluent.topic.bootstrap.servers reflect the same values as used in the docker compose file

### Test Source Connector

Execute the following command to test the source connector

```
source docker/.env
docker run -it --rm --name mqtt-publisher --network kafka_default efrecon/mqtt-client \
pub -h $MQTTHost  -t "mqtt.marklogic" -m "{\"id\":1234,\"message\":\"This is a test\"}"
```

This will put the message onto the mosquitto topic *mqtt.marklogic*.

Execute the following command to listen to the kafka topic *kafka.marklogic*

```
docker run --rm --network kafka_default confluentinc/cp-kafka:5.1.0 \
kafka-console-consumer --bootstrap-server $Kafka:$KafkaPortTrg --topic kafka.marklogic --from-beginning
```

This should produce the test message in the console.

### Configure Sink Connector

Next step is to setup the sink connector via the REST API.

```
curl -d @./config/marklogic-sink.yaml -H "Content-Type: application/json" -X POST http://localhost:8083/connectors
```

The *connect-marklogic-sink.json* file looks like this:

```
{
  "name": "marklogic-sink",
  "config": {
    "group.id":"marklogic-connector",
    "connector.class": "com.marklogic.kafka.connect.sink.MarkLogicSinkConnector",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
    "offset.storage.file.filename":"/tmp/connect.offsets",
    "offset.flush.interval.ms":10000,
    "tasks.max": 1,
    "topics": "kafka.marklogic",
    "ml.connection.host": "marklogic-kafka",
    "ml.connection.port": "8000",
    "ml.connection.securityContextType": "DIGEST",
    "ml.connection.username": "admin",
    "ml.connection.password": "admin",
    "ml.document.collections": "kafka.marklogic",
    "ml.document.format": "json",
    "ml.document.uriPrefix": "/kafka.marklogic/",
    "ml.document.uriSuffix": ".json",
    "confluent.topic.bootstrap.servers": "kafka:9092",
    "confluent.topic.replication.factor": 1
  }
}
```

The json file has the following MarkLogic specific properties:

- ml.connection.host, this will be the hostname of machine where the MarkLogic instance runs
- ml.connection.port, this will be the port on which the MarkLogic instance listens to, this determines in which database the documents are stored
- ml.connection.securityContextType, this will determine the authentication scheme used by MarkLogic
- ml.connection.username, obviously the username used for actions in the MarkLogic instance
- ml.connection.password, obviously the password for the user used for actions in the MarkLogic instance
- ml.document.collections, sequence of collections assigned to sinked documents
- ml.document.format, format for the document stored in MarkLogic
- ml.document.uriPrefix, uri prefix for the document stored in MarkLogic
- ml.document.uriSuffix, uri suffix for the document stored in MarkLogic

### Test Sink Connector

Since the kafka topic 'connect-custom' already contains messages from the MQTT connector test the MarkLogic Connector should already have fetched them directly after creation.

Execute te following command to see if the test document reached MarkLogic:

```
curl --anyauth -u admin:admin --request GET http://localhost:8000/v1/search?collection=kafka.marklogic
```

This should give back a search:response xml fragment. See below for an example:

```
<search:response snippet-format="snippet" total="1" start="1" page-length="10" xmlns:search="http://marklogic.com/appservices/search">
  <search:result index="1" uri="/purchases/900e1424-b2f0-4534-b2b2-b28d3d5c416b.json" path="fn:doc(&quot;/kafka.marklogic/900e1424-b2f0-4534-b2b2-b28d3d5c416b.json&quot;)" score="0" confidence="0" fitness="0" href="/v1/documents?uri=%2Fkafka.marklogic%2F900e1424-b2f0-4534-b2b2-b28d3d5c416b.json" mimetype="application/json" format="json">
    <search:snippet>
      <search:match path="fn:doc(&quot;/kafka.marklogic/900e1424-b2f0-4534-b2b2-b28d3d5c416b.json&quot;)/object-node()">This is a test</search:match>
    </search:snippet>
  </search:result>
  <search:metrics>
    <search:query-resolution-time>PT0.001496S</search:query-resolution-time>
    <search:snippet-resolution-time>PT0.000355S</search:snippet-resolution-time>
    <search:total-time>PT0.002825S</search:total-time>
  </search:metrics>
</search:response>
```


### End-to-end Test

Now that everything has been set up and tested you can send complete messages with the MQTT client.
This client can be installed for various OS-es. Find it [here](https://mqttx.app/).

### Cleanup

Once done, the two connectors can be removed and the complete stack can be deleted.

Remove connectors

```
curl -X DELETE http://localhost:8083/connectors/mqtt-source
curl -X DELETE http://localhost:8083/connectors/marklogic-sink
```

Stop the stack and remove temporary files

```
source docker/.env
docker compose -f docker/docker-compose.yml -p $DOCKERPROJECT down

rm -rf docker/kafka
rm -rf docker/zookeeper
```

For most of the commands there are shell scripts present to execute.