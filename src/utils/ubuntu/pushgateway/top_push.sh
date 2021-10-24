#!/bin/bash

# @author Sean Hinds
#   these functions push process-level memory and CPU data to a push gateway to be
#   scraped by Prometheus

top_cpu() {
    z=$(ps aux)
    while read -r z
    do
        var=$var$(awk -v process=11 '{print "cpu_usage{process="substr($process,length($process)-40,40)", pid=\""$2"\"}", $3z}');
    done <<< "$z"

    echo $var

    curl -X POST -H "Content-Type: text/plain" --data "$var
        " http://localhost:9091/metrics/job/top/instance/machine
}

top_mem() {
    z=$(ps aux)
    while read -r z
    do
        var=$var$(awk -v process=11 '{print "memory_usage{process="substr($process,length($process)-40,40)", pid=\""$2"\"}", $4z}');
    done <<< "$z"

    echo $var

    curl -X POST -H "Content-Type: text/plain" --data "$var
        " http://localhost:9091/metrics/job/top/instance/machine
}

$1