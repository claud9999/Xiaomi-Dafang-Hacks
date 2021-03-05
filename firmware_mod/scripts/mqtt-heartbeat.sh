#!/bin/sh

. /system/sdcard/config/mqtt.conf
. /system/sdcard/scripts/common_functions.sh
. /system/sdcard/config/motion.conf

heartbeat_time=30
timeout=60
declare -A last_heartbeat

last_heartbeat[scripts/mqtt_detection/heartbeat]=0
last_heartbeat[scripts/mqtt_snap/heartbeat]=0
last_heartbeat[rtsp/heartbeat]=0

function watch() {
    m=''
    while [ true ]; do
        now=$(date "+%s")
        for k in ${!last_heartbeat[@]}; do
            delta=$(( $now - $last_heartbeat[$k] ))
            if [ $delta -gt $timeout ]; then
                m="$m $k=$delta"
            fi
        done
        mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}/heartbeat" -m "$m"
        sleep $heartbeat_time
    done
}

watch &

while [ true ]; do
    echo "MQTT sub"
    mosquitto_sub.bin -t "#" -F "%t" | while read -r msg; do
        if [ ! -z "${last_heartbeat[$msg]}" ]; then
            $last_heartbeat[$msg]=$(date '+%s')
        fi
    done
done
