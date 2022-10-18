#!/bin/bash
#
source docker/.env
docker run --rm --network kafka_default confluentinc/cp-kafka:5.1.0 \
kafka-console-consumer --bootstrap-server $Kafka:$KafkaPortTrg --topic kafka.marklogic --from-beginning