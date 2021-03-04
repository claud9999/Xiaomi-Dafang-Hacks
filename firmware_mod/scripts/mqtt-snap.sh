#!/bin/sh

. /system/sdcard/config/mqtt.conf
. /system/sdcard/scripts/common_functions.sh
. /system/sdcard/config/motion.conf

heartbeat_time=30

if [ ! -d "$save_snapshot_dir" ]; then
    mkdir -p $save_snapshot_dir
fi

next_heartbeat=0

while [ true ]; do
    echo "waiting for snapshots..."
    mosquitto_sub.bin -t "rtsp/motion/detect/snap" -C 1 -W 30 > /tmp/current.jpg
    if [ -r /tmp/current.jpg ]; then
        filename=$save_snapshot_dir/$(date +%d-%m-%Y_%H.%M.%S).jpg
        mv /tmp/current.jpg $filename

        if [ "$publish_mqtt_snapshot" = true ] ; then
            mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "$TOPIC"/motion/snapshot/image $MOSQUITTOOPTS $MOSQUITTOPUBOPTS -f "$filename"
        fi
    fi
    t=$(date '+%s')
    if [ $t -gt $next_heartbeat ]; then
        mosquitto_pub.bin -t 'scripts/mqtt_snap/heartbeat' -m 'ON'
        next_heartbeat=$(( $(date '+%s') + 30 ))
    fi
done
