#!/bin/bash

# Publishes Home Assistant MQTT device-based auto-discovery for every Seplos
# pack listed in config.ini PACKS=. One retained device config payload per
# pack at homeassistant/device/<topic>_<pack_ID>/config. Run once at startup.

CONFIG_DIR="${CONFIG_DIR:-$(dirname "$(readlink -f "$0")")}"
CONFIG_FILE="$CONFIG_DIR/config.ini"

MQTTHOST=$(grep "^MQTTHOST=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
TOPIC=$(grep "^TOPIC=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTUSER=$(grep "^MQTTUSER=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTPASWD=$(grep "^MQTTPASWD=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
PACKS=$(grep "^PACKS=" "$CONFIG_FILE" | awk -F "=" '{print $2}')

MQTT_AUTH=""
if [ -n "$MQTTUSER" ]; then
    MQTT_AUTH="-u $MQTTUSER -P $MQTTPASWD"
fi

CMPS=""

# add_sensor <key> <name> <unit> <device_class> <icon> <unique_suffix>
# Pass "" for any field to omit it. unique_suffix defaults to <key>.
# Uses $pack_id (caller-set) for unique_id generation.
add_sensor() {
    local key="$1"
    local name="$2"
    local unit="$3"
    local dev_class="$4"
    local icon="$5"
    local uniq_suffix="${6:-$key}"

    local entry='"'"$key"'":{"p":"sensor"'
    entry+=',"name":"'"$name"'"'
    entry+=',"value_template":"{{ value_json.'"$key"' }}"'
    entry+=',"unique_id":"seplos_'"$uniq_suffix"'_'"$pack_id"'"'
    [ -n "$unit" ]      && entry+=',"unit_of_measurement":"'"$unit"'"'
    [ -n "$dev_class" ] && entry+=',"device_class":"'"$dev_class"'"'
    [ -n "$icon" ]      && entry+=',"icon":"'"$icon"'"'
    entry+='}'

    if [ -z "$CMPS" ]; then
        CMPS="$entry"
    else
        CMPS+=",$entry"
    fi
}

build_cmps() {
    CMPS=""
    local i
    for i in $(seq -w 1 16); do
        add_sensor "cell${i}" "Cell ${i}" "mV" "voltage" "mdi:car-battery"
    done

    add_sensor "lowest_cell_v"  "Lowest Cell V"  "mV" ""        "mdi:car-battery"       "lowest_cell_V"
    add_sensor "lowest_cell_n"  "Lowest Cell N"  ""   ""        "mdi:battery-outline"   "lowest_cell_N"
    add_sensor "highest_cell_v" "Highest Cell V" "mV" ""        "mdi:car-battery"       "highest_cell_V"
    add_sensor "highest_cell_n" "Highest Cell N" ""   ""        "mdi:battery-outline"   "highest_cell_N"
    add_sensor "difference"     "Difference"     "mV" "voltage" "mdi:vector-difference"

    for i in 1 2 3 4; do
        add_sensor "cell_temp${i}" "Cell Temp ${i}" "°C" "temperature" ""
    done

    add_sensor "env_temp"     "Env Temp"     "°C" "temperature" ""
    add_sensor "power_temp"   "Power Temp"   "°C" "temperature" ""
    add_sensor "port_voltage" "Port Voltage" "V"  "voltage"     ""
    add_sensor "cycles"       "Cycles"       ""   ""            "mdi:counter"

    add_sensor "charge_discharge"      "Charge Discharge"      "A"   "current" ""
    add_sensor "total_voltage"         "Total Voltage"         "V"   "voltage" ""
    add_sensor "residual_capacity"     "Residual Capacity"     "Ah"  ""        "mdi:alpha-a-box"
    add_sensor "residual_capacity_kwh" "Residual Capacity Kwh" "kWh" "energy"  ""
    add_sensor "soc"                   "SOC"                   "%"   "battery" ""
    add_sensor "soh"                   "SOH"                   "%"   ""        "mdi:percent-box"
    add_sensor "battery_status"        "Battery Status"        ""    ""        "mdi:information-outline"
}

publish_pack() {
    local pack="$1"
    pack_id=$(grep "^${pack}_ID=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
    local pack_name
    pack_name=$(grep "^${pack}_NAME=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
    pack_name="${pack_name:-$pack}"

    local node_id="${TOPIC}_${pack_id}"
    local state_topic="homeassistant/sensor/${node_id}"
    local config_topic="homeassistant/device/${node_id}/config"

    build_cmps

    local device='"dev":{"ids":"'"${node_id}"'","name":"SEPLOS BMS '"${pack_name}"'","mf":"SEPLOS","mdl":"BMS"}'
    local origin='"o":{"name":"SEPLOS_MQTT","sw":"1.2","url":"https://github.com/byte4geek/SEPLOS_MQTT"}'
    local payload='{'"${device}"','"${origin}"',"state_topic":"'"${state_topic}"'","qos":0,"cmps":{'"${CMPS}"'}}'

    mosquitto_pub -h "$MQTTHOST" $MQTT_AUTH -r -t "$config_topic" -m "$payload"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - HA discovery published for ${node_id} (${pack_name})"
}

for pack in $(echo "$PACKS" | tr ',' ' '); do
    publish_pack "$pack"
done
