#!/bin/bash
#
docker run -it --rm --name mqtt-publisher --network kafka_default efrecon/mqtt-client \
pub -h $MQTTHost  -t "mqtt.marklogic" -m "{\"id\":1234,\"message\":\"This is a test\"}"