#!/bin/sh

. /system/sdcard/config/mqtt.conf
. /system/sdcard/scripts/common_functions.sh
. /system/sdcard/config/motion.conf

function detection_on {
    # Turn on the amber led
    if [ "$motion_trigger_led" = true ] ; then
        yellow_led on
    fi

#    # Save a snapshot
#    if [ "$save_snapshot" = true ] ; then
#	filename=$(date +%d-%m-%Y_%H.%M.%S).jpg
#	if [ ! -d "$save_snapshot_dir" ]; then
#		mkdir -p $save_snapshot_dir
#	fi
#	# Limit the number of snapshots
#	if [[ $(ls $save_snapshot_dir | wc -l) -ge $max_snapshots ]]; then
#		rm -f "$save_snapshot_dir/$(ls -l $save_snapshot_dir | awk 'NR==2{print $9}')"
#	fi
#	/system/sdcard/bin/getimage > $save_snapshot_dir/$filename &
#    fi

    # Publish a mqtt message
    if [ "$publish_mqtt_message" = true ] ; then
        . /system/sdcard/config/mqtt.conf
	/system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "ON"
	if [ "$save_snapshot" = true ] ; then
            /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion/snapshot ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -f $save_snapshot_dir/$filename
	fi
    fi

    # Send emails ...
    if [ "$sendemail" = true ] ; then
        /system/sdcard/scripts/sendPictureMail.sh &
    fi

    # Run any user scripts.
    for i in /system/sdcard/config/userscripts/motiondetection/*; do
        if [ -x $i ]; then
            echo "Running: $i on"
            $i on
        fi
    done
}

function detection_off {
    # Turn off the amber LED
    if [ "$motion_trigger_led" = true ] ; then
        yellow_led off
    fi

    # Publish a mqtt message
    if [ "$publish_mqtt_message" = true ] ; then
        . /system/sdcard/config/mqtt.conf
        /system/sdcard/bin/mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "OFF"
    fi

    # Run any user scripts.
    for i in /system/sdcard/config/userscripts/motiondetection/*; do
        if [ -x $i ]; then
            echo "Running: $i off"
            $i off
        fi
    done
}

function snap_thread() {
    if [ ! -d "$save_snapshot_dir" ]; then
        mkdir -p $save_snapshot_dir
    fi

    while [ true ]; do
        echo "waiting for snapshots..."
        /system/sdcard/bin/mosquitto_sub.bin -t "rtsp/motion/detect/snap" -C 1 > /tmp/current.jpg
	filename=$(date +%d-%m-%Y_%H.%M.%S).jpg
	# Limit the number of snapshots
	if [[ $(ls $save_snapshot_dir | wc -l) -ge $max_snapshots ]]; then
		rm -f "$save_snapshot_dir/$(ls -l $save_snapshot_dir | awk 'NR==2{print $9}')"
	fi
        mv /tmp/current.jpg $save_snapshot_dir/$filename
    done
}

snap_thread &

while [ true ]; do
    echo "starting mosquitto_sub.bin"
    /system/sdcard/bin/mosquitto_sub.bin -v -t "rtsp/motion/detect" | while read -r line ; do
        echo "---$line---"
        case $line in
            "rtsp/motion/detect ON")
                echo "--DETECT ON--"
                detection_on
            ;;
            "rtsp/motion/detect OFF")
                echo "--DETECT OFF--"
                detection_off
            ;;
        esac
    done
    sleep 60 # if mosquitto_sub fails, wait around in case mosquitto broker starts
done
