#!/bin/sh

. /system/sdcard/config/mqtt.conf
. /system/sdcard/scripts/common_functions.sh
. /system/sdcard/config/motion.conf

heartbeat_time=30

function detection_on {
    # Turn on the amber led
    if [ "$motion_trigger_led" = true ] ; then
        yellow_led on
    fi

    if [ "$publish_mqtt_message" = true ] ; then
        . /system/sdcard/config/mqtt.conf
	echo publishing mqtt message to $HOST:$PORT
	mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "ON"
    fi

    # Send emails ...
    if [ "$sendemail" = true ] ; then
	echo sending e-mail
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
        mosquitto_pub.bin -h "$HOST" -p "$PORT" -u "$USER" -P "$PASS" -t "${TOPIC}"/motion ${MOSQUITTOOPTS} ${MOSQUITTOPUBOPTS} -m "OFF"
    fi

    # Run any user scripts.
    for i in /system/sdcard/config/userscripts/motiondetection/*; do
        if [ -x $i ]; then
            echo "Running: $i off"
            $i off
        fi
    done
}

while [ true ]; do
    (
        mosquitto_sub.bin -v -t "rtsp/motion/detect" -W ${heartbeat_time} | while read -r line ; do
            echo "---$line---"
            case $line in
                "rtsp/motion/detect ON")
                    echo "--DETECT ON START--"
                    detection_on
                    echo "--DETECT ON DONE--"
                ;;
                "rtsp/motion/detect OFF")
                    echo "--DETECT OFF START--"
                    detection_off
                    echo "--DETECT OFF DONE--"
                ;;
            esac
        done
    )
    errcode=$?
    if [ 0${errcode} -gt 0 ]; then
        echo "error ${errcode}, sleeping 60s"
        sleep 60
    else
        mosquitto_pub.bin -t 'scripts/mqtt_detection/heartbeat' -m 'ON'
    fi
done
