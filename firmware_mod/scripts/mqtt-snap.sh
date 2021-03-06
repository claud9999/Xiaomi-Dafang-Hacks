#!/bin/sh

. /system/sdcard/config/mqtt.conf
. /system/sdcard/scripts/common_functions.sh
. /system/sdcard/config/motion.conf

heartbeat_time=30
snap_topic='rtsp/motion/detect/snap'
heartbeat_topic='scripts/mqtt_snap/heartbeat'
mqtt_id=$0

snapnum=0

if [ ! -d "$save_snapshot_dir" ]; then
    mkdir -p $save_snapshot_dir
fi

next_heartbeat=0

while [ true ]; do
    echo "waiting for snapshots..."
    snapfile="/tmp/pic-${snapnum}.jpg"
    mosquitto_sub.bin --topic "${snap_topic}" --disable-clean-session --id "$mqtt_id" -C 1 -W 30 > $snapfile
    if [ $? -eq 0 ]; then
        if [ "$publish_mqtt_snapshot" = true ] ; then
            mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" --topic "${TOPIC}/motion/snapshot/image" $MOSQUITTOOPTS $MOSQUITTOPUBOPTS -f "${snapfile}"
        fi

        mv ${snapfile} ${save_snapshot_dir}/$(date '+%d-%m-%Y_%H.%M.%S').jpg

        snapnum=$(( $snapnum + 1 ))
    fi
    t=$(date '+%s')
    if [ $t -gt $next_heartbeat ]; then
        mosquitto_pub.bin --topic "${heartbeat_topic}" --message 'ON'
        next_heartbeat=$(( $(date '+%s') + 30 ))
    fi
done
