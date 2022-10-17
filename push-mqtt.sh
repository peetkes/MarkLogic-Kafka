#!/bin/bash
#
docker run -it --rm --name mqtt-publisher --network kafka_default efrecon/mqtt-client \
pub -h mosquitto  -t "marklogic" -m "{\"id\":1234,\"message\":\"This is a test\"}"