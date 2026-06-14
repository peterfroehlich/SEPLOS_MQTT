#!/bin/bash

# Publishes Home Assistant MQTT device-based auto-discovery for all SEPLOS BMS sensors.
# One retained config payload at homeassistant/device/<node_id>/config describes
# every sensor as a component under a single device.
# Run once at startup. Configs are retained so HA recreates entities on reconnect.

CONFIG_DIR="${CONFIG_DIR:-$(dirname "$(readlink -f "$0")")}"
CONFIG_FILE="$CONFIG_DIR/config.ini"

MQTTHOST=$(grep "MQTTHOST" "$CONFIG_FILE" | awk -F "=" '{print $2}')
TOPIC=$(grep "TOPIC" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTUSER=$(grep "MQTTUSER" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTPASWD=$(grep "MQTTPASWD" "$CONFIG_FILE" | awk -F "=" '{print $2}')
id_prefix=$(grep "id_prefix" "$CONFIG_FILE" | awk -F "=" '{print $2}')

NODE_ID="${TOPIC}_${id_prefix}"
STATE_TOPIC="homeassistant/sensor/${NODE_ID}"
CONFIG_TOPIC="homeassistant/device/${NODE_ID}/config"

MQTT_AUTH=""
if [ -n "$MQTTUSER" ]; then
    MQTT_AUTH="-u $MQTTUSER -P $MQTTPASWD"
fi

# Component accumulator (entries joined into cmps object).
CMPS=""

# add_sensor <key> <name> <unit> <device_class> <icon> <unique_suffix>
# Pass "" for any field to omit it. unique_suffix defaults to <key>.
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
    entry+=',"unique_id":"seplos_'"$uniq_suffix"'_'"$id_prefix"'"'
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

# Cells 1-16
for i in $(seq -w 1 16); do
    add_sensor "cell${i}" "Cell ${i}" "mV" "voltage" "mdi:car-battery"
done

# Lowest / highest cell
add_sensor "lowest_cell_v"  "Lowest Cell V"  "mV" ""        "mdi:car-battery"       "lowest_cell_V"
add_sensor "lowest_cell_n"  "Lowest Cell N"  ""   ""        "mdi:battery-outline"   "lowest_cell_N"
add_sensor "highest_cell_v" "Highest Cell V" "mV" ""        "mdi:car-battery"       "highest_cell_V"
add_sensor "highest_cell_n" "Highest Cell N" ""   ""        "mdi:battery-outline"   "highest_cell_N"
add_sensor "difference"     "Difference"     "mV" "voltage" "mdi:vector-difference"

# Cell temps
for i in 1 2 3 4; do
    add_sensor "cell_temp${i}" "Cell Temp ${i}" "°C" "temperature" ""
done

# Env / power / port / cycles
add_sensor "env_temp"     "Env Temp"     "°C" "temperature" ""
add_sensor "power_temp"   "Power Temp"   "°C" "temperature" ""
add_sensor "port_voltage" "Port Voltage" "V"  "voltage"     ""
add_sensor "cycles"       "Cycles"       ""   ""            "mdi:counter"

# Pack-level
add_sensor "charge_discharge"      "Charge Discharge"      "A"   "current" ""
add_sensor "total_voltage"         "Total Voltage"         "V"   "voltage" ""
add_sensor "residual_capacity"     "Residual Capacity"     "Ah"  ""        "mdi:alpha-a-box"
add_sensor "residual_capacity_kwh" "Residual Capacity Kwh" "kWh" "energy"  ""
add_sensor "soc"                   "SOC"                   "%"   "battery" ""
add_sensor "soh"                   "SOH"                   "%"   ""        "mdi:percent-box"
add_sensor "battery_status"        "Battery Status"        ""    ""        "mdi:information-outline"

DEVICE='"dev":{"ids":"'"$NODE_ID"'","name":"SEPLOS BMS","mf":"SEPLOS","mdl":"BMS"}'
ORIGIN='"o":{"name":"SEPLOS_MQTT","sw":"1.1","url":"https://github.com/byte4geek/SEPLOS_MQTT"}'

PAYLOAD='{'"$DEVICE"','"$ORIGIN"',"state_topic":"'"$STATE_TOPIC"'","qos":0,"cmps":{'"$CMPS"'}}'

mosquitto_pub -h "$MQTTHOST" $MQTT_AUTH -r -t "$CONFIG_TOPIC" -m "$PAYLOAD"

echo "$(date '+%Y-%m-%d %H:%M:%S') - HA device-based discovery published for ${NODE_ID}"
