#!/bin/bash
#
# Call : ./es_test.bash <mode>
# single : Stan-alone Jmeter
# master : Master instance (set JM_REMOTES in vars.bash)
# slave : Slave instance
# Calls a Jmeter test that Sends Queries And/Or bulk index requests to ES
#
# This script requires input files in ./input if you are planning to test ingestion
# each input file should be a proper BULK request :
# ex :
# { "index" : { "_index" : "apachelogs-2015.08.22", "_type" : "logs" } }
# {"message":"83.149.9.216 - - [22/Aug/2015:23:13:42 +0000] \"GET "patch":"1700"}}
# ...
#
#

# Load Global Vars
. vars.bash

# Enable/disable JMeter threads
# Ingest files in ./input
INGESTION_ENABLED=true
# use -1 in order to loop files in ./input forever (default)
INGEST_FILES_LOOPS=-1
# send queries
QUERY_ENABLED=false
# send Scroll queries
SCROLL_ENABLED=false

# Througput in requests per minute
QUERY_THROUGHPUT=60.0
SCROLL_THROUGHPUT=20.0
# ingestion Througput in raw MB/s
INGEST_THROUGHPUT=0.25
# Tag this test
TEST_TAG=T0602


# Query and Scroll files in ./queries 
QUERY_CSV=input1K1h.csv
SCROLL_CSV=inputScroll.csv




if [ "$INGESTION_ENABLED" == "true" ] 
then
  if ! [[ "$(ls -A ./input)" ]]
  then
    echo "You need some data to ingest in ./input .."
    exit
  fi
fi


if [ "$INGESTION_ENABLED" == "true" ] 
then
  # how many files in ./input ?
  BULK_FILES=$(ls -l ./input/* | wc -l)

  ONE_FILE=$(ls ./input | head -1)

  # Take  ONE_FILE  as sample for document size
  SIZEDOCS=$(awk 'NR % 2 == 0' ./input/$ONE_FILE | wc -c)

  TOTAL_SIZE=$(echo "$SIZEDOCS/$DOCS_PER_BULK" | bc -l)
  INDEX_THROUGHPUT=$(echo "$INGEST_THROUGHPUT*60*1048576/($DOCS_PER_BULK*$TOTAL_SIZE)" | bc -l)
fi


# Create apachelogs-* template
curl -u "$USER:$PASS" -XPUT "http://$HOST:$PORT/_template/template1" -d "@./templates/$TEMPLATE.json"


# launch test slave or master
if [ "$1" == "single" ] || [ -z $1 ]
then
  "$JMETER_PATH/bin/jmeter" -n -t ./tests/elk_stress.jmx \
    -JtestScroll="$SCROLL_ENABLED"  \
    -JtestIngest="$INGESTION_ENABLED"  \
    -JtestQuery="$QUERY_ENABLED" \
    -Jhost="$HOST"  \
    -Jport="$PORT" \
    -Juser="$USER" \
    -Jpass="$PASS" \
    -JinputFiles="$BULK_FILES" \
    -JloopFiles="$INGEST_FILES_LOOPS" \
    -JindexName="$INDEX" \
    -JtypeName=logs \
    -JqueryThroughPut="$QUERY_THROUGHPUT" \
    -JindexThroughPut="$INDEX_THROUGHPUT" \
    -JscrollThroughPut="$SCROLL_THROUGHPUT" \
    -JqueryCSVFile="$QUERY_CSV" \
    -JscrollCSVFile="$SCROLL_CSV" \
    -JtestRunId="$TEST_TAG" -l ./results/results.csv
fi



# launch test slave or master
if [ "$1" == "master" ]
then
  "$JMETER_PATH/bin/jmeter" -n -t ./tests/elk_stress.jmx \
    -GtestScroll="$SCROLL_ENABLED"  \
    -GtestIngest="$INGESTION_ENABLED"  \
    -GtestQuery="$QUERY_ENABLED" \
    -Ghost="$HOST"  \
    -Gport="$PORT" \
    -Guser="$USER" \
    -Gpass="$PASS" \
    -GinputFiles="$BULK_FILES" \
    -GloopFiles="$INGEST_FILES_LOOPS" \
    -GindexName="$INDEX" \
    -GtypeName=logs \
    -GqueryThroughPut="$QUERY_THROUGHPUT" \
    -GindexThroughPut="$INDEX_THROUGHPUT" \
    -GscrollThroughPut="$SCROLL_THROUGHPUT" \
    -GqueryCSVFile="$QUERY_CSV" \
    -GscrollCSVFile="$SCROLL_CSV" \
    -GtestRunId="$TEST_TAG" -R "$JM_REMOTES" -l ./results/results.csv
fi


if [ "$1" == "slave" ]
then
  "$JMETER_PATH/bin/jmeter" -s
fi

