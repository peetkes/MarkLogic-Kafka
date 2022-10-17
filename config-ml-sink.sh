#!/bin/bash
#

curl -d @./config/connect-marklogic-sink.json -H "Content-Type: application/json" -X POST http://localhost:8083/connectors