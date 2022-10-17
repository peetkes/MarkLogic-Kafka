#!/bin/bash
#
docker run --rm --network kafka_default confluentinc/cp-kafka:5.1.0 \
kafka-console-consumer --bootstrap-server kafka:9092 --topic connect-custom --from-beginning