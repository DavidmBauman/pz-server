#!/bin/bash
killpid="$(pidof ProjectZomboid64)"
while true
do
	tail --pid=$killpid -f /dev/null
	kill "$(pidof tail)"
	exit 0
done