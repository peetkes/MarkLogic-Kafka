#!/bin/bash
#
curl -d @./config/connect-mqtt-source.json -H "Content-Type: application/json" -X POST http://localhost:8083/connectors