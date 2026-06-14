#!/bin/bash

CONFIG_FILE=/root/share/SEPLOS_MQTT/config.ini

# Load global config parameters
MQTTHOST=$(grep "^MQTTHOST=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
TOPIC=$(grep "^TOPIC=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTUSER=$(grep "^MQTTUSER=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MQTTPASWD=$(grep "^MQTTPASWD=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
LOGFILE=$(grep "^LOGFILE=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
MAXSIZE=$(grep "^MAXSIZE=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
CELL_MIN_VOLT=$(grep "^CELL_MIN_VOLT=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
CELL_MAX_VOLT=$(grep "^CELL_MAX_VOLT=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
PACKS=$(grep "^PACKS=" "$CONFIG_FILE" | awk -F "=" '{print $2}')

log() {
	echo "$@"
	[ -n "$LOGFILE" ] && echo "$@" >> "$LOGFILE"
}

checkcellsvoltage()
{
	STATUS=0
	counter=1
	for CELLVOLTAGE in "$CELL1" "$CELL2" "$CELL3" "$CELL4" "$CELL5" "$CELL6" "$CELL7" "$CELL8" "$CELL9" "$CELL10" "$CELL11" "$CELL12" "$CELL13" "$CELL14" "$CELL15" "$CELL16"; do
		if [ "$CELLVOLTAGE" -lt $CELL_MIN_VOLT ] || [ "$CELLVOLTAGE" -gt $CELL_MAX_VOLT ]; then
			log "$DATE - [$pack_name] Warning 0: The value $CELLVOLTAGE for cell $counter is not between $CELL_MIN_VOLT and $CELL_MAX_VOLT skip data"
			STATUS=1
			break
		fi
		((counter++))
	done
	return $STATUS
}

process_pack() {
	local pack="$1"
	local dev baud addr pack_id pack_name
	dev=$(grep "^${pack}_DEV=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
	baud=$(grep "^${pack}_BAUD=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
	addr=$(grep "^${pack}_ADDR=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
	pack_id=$(grep "^${pack}_ID=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
	pack_name=$(grep "^${pack}_NAME=" "$CONFIG_FILE" | awk -F "=" '{print $2}')
	pack_name="${pack_name:-$pack}"

	if [ -z "$pack_id" ]; then
		log "$DATE - [$pack] Warning: missing ${pack}_ID in config.ini, skipping"
		return
	fi

	local QUERY
	QUERY=$(DEV="$dev" BAUD="$baud" ADDR="$addr" /root/share/SEPLOS_MQTT/query_seplos_ha.sh 4201)

	local onlycells lowcell highcell DIFF lowcellnumb highcellnumb VAR
	local CELL1 CELL2 CELL3 CELL4 CELL5 CELL6 CELL7 CELL8 CELL9 CELL10 CELL11 CELL12 CELL13 CELL14 CELL15 CELL16
	local CHARGE_DISCHARGE TOTAL_VOLTAGE RESIDUAL_CAPACITY RESIDUAL_CAPACITY_KWH BATTERY_STATUS

	onlycells=$(echo $QUERY|awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16}')
	lowcell=$(echo ${onlycells[@]} | awk 'BEGIN{RS=" ";} {print $1}' | sort | sed -n 1p)
	highcell=$(echo ${onlycells[@]} | awk 'BEGIN{RS=" ";} {print $1}' | sort | sed -n 16p)
	DIFF=$(($highcell - $lowcell))
	lowcellnumb=$(echo ${onlycells[@]} | awk 'BEGIN{RS=" ";} {print $1}' | awk '{print $0, FNR}' | sort | sed -n 1p | awk '{print $2}')
	highcellnumb=$(echo ${onlycells[@]} | awk 'BEGIN{RS=" ";} {print $1}' | awk '{print $0, FNR}' | sort | sed -n 16p | awk '{print $2}')

	VAR="$(echo $QUERY|awk '{print $27}')"
	CELL1=$(echo $QUERY|awk '{print $1}')
	CELL2=$(echo $QUERY|awk '{print $2}')
	CELL3=$(echo $QUERY|awk '{print $3}')
	CELL4=$(echo $QUERY|awk '{print $4}')
	CELL5=$(echo $QUERY|awk '{print $5}')
	CELL6=$(echo $QUERY|awk '{print $6}')
	CELL7=$(echo $QUERY|awk '{print $7}')
	CELL8=$(echo $QUERY|awk '{print $8}')
	CELL9=$(echo $QUERY|awk '{print $9}')
	CELL10=$(echo $QUERY|awk '{print $10}')
	CELL11=$(echo $QUERY|awk '{print $11}')
	CELL12=$(echo $QUERY|awk '{print $12}')
	CELL13=$(echo $QUERY|awk '{print $13}')
	CELL14=$(echo $QUERY|awk '{print $14}')
	CELL15=$(echo $QUERY|awk '{print $15}')
	CELL16=$(echo $QUERY|awk '{print $16}')

	if [[ "$onlycells" =~ "rror" ]]; then
		log "$DATE - [$pack_name] Warning 1: Data from BMS contain 'Error' skip data"
		return
	elif [[ "$onlycells" =~ "Failed" ]]; then
		log "$DATE - [$pack_name] Warning 2: Data from BMS contain 'Failed' skip data"
		return
	elif (( $(echo "$VAR"'>'100 |bc -l) )); then
		log "$DATE - [$pack_name] Warning 3: SOC value over 100 value=$VAR skip data"
		return
	elif (( $(echo "$VAR"'<'1 |bc -l) )); then
		log "$DATE - [$pack_name] Warning 4: SOC Value below 1 SOC=$VAR skip data"
		return
	elif [[ "$onlycells" =~ "~" ]]; then
		log "$DATE - [$pack_name] Warning 5: Data from BMS contain '~' skip data"
		return
	elif [ "${VAR+x}" = x ] && [ -z "$VAR" ]; then
		log "$DATE - [$pack_name] Warning 6: SOC value is null skip data"
		return
	fi

	checkcellsvoltage || return

	CHARGE_DISCHARGE=$(echo $QUERY|awk '{print $23}')
	TOTAL_VOLTAGE=$(echo $QUERY|awk '{print $24}')
	RESIDUAL_CAPACITY=$(echo $QUERY|awk '{print $25}')
	RESIDUAL_CAPACITY_KWH=$(bc -l <<< "scale=3; $RESIDUAL_CAPACITY * $TOTAL_VOLTAGE / 1000")
	if (( $(echo "$CHARGE_DISCHARGE > 0" | bc -l) )); then
		BATTERY_STATUS="Charging"
	elif (( $(echo "$CHARGE_DISCHARGE < 0" | bc -l) )); then
		BATTERY_STATUS="Discharge"
	else
		BATTERY_STATUS="Standby"
	fi

	local mqtt_argument
	mqtt_argument=$(printf "{\
\"lowest_cell\":\"Cell $lowcellnumb - $lowcell mV\",\
\"lowest_cell_v\":\"$lowcell\",\
\"lowest_cell_n\":\"$lowcellnumb\",\
\"highest_cell\":\"Cell $highcellnumb - $highcell mV\",\
\"highest_cell_v\":\"$highcell\",\
\"highest_cell_n\":\"$highcellnumb\",\
\"difference\":\"$DIFF\",\
\"cell01\":\"$CELL1\",\
\"cell02\":\"$CELL2\",\
\"cell03\":\"$CELL3\",\
\"cell04\":\"$CELL4\",\
\"cell05\":\"$CELL5\",\
\"cell06\":\"$CELL6\",\
\"cell07\":\"$CELL7\",\
\"cell08\":\"$CELL8\",\
\"cell09\":\"$CELL9\",\
\"cell10\":\"$CELL10\",\
\"cell11\":\"$CELL11\",\
\"cell12\":\"$CELL12\",\
\"cell13\":\"$CELL13\",\
\"cell14\":\"$CELL14\",\
\"cell15\":\"$CELL15\",\
\"cell16\":\"$CELL16\",\
\"cell_temp1\":\"$(echo $QUERY|awk '{print $17}')\",\
\"cell_temp2\":\"$(echo $QUERY|awk '{print $18}')\",\
\"cell_temp3\":\"$(echo $QUERY|awk '{print $19}')\",\
\"cell_temp4\":\"$(echo $QUERY|awk '{print $20}')\",\
\"env_temp\":\"$(echo $QUERY|awk '{print $21}')\",\
\"power_temp\":\"$(echo $QUERY|awk '{print $22}')\",\
\"charge_discharge\":\"$(echo $QUERY|awk '{print $23}')\",\
\"total_voltage\":\"$(echo $QUERY|awk '{print $24}')\",\
\"residual_capacity\":\"$(echo $QUERY|awk '{print $25}')\",\
\"soc\":\"$(echo $QUERY|awk '{print $27}')\",\
\"cycles\":\"$(echo $QUERY|awk '{print $29}')\",\
\"soh\":\"$(echo $QUERY|awk '{print $30}')\",\
\"port_voltage\":\"$(echo $QUERY|awk '{print $31}')\",\
\"residual_capacity_kwh\":\"$RESIDUAL_CAPACITY_KWH\",\
\"battery_status\":\"$BATTERY_STATUS\"\
}")

	mosquitto_pub -h "$MQTTHOST" -u "$MQTTUSER" -P "$MQTTPASWD" -t "homeassistant/sensor/${TOPIC}_${pack_id}" -m "$mqtt_argument"
	log "$DATE - [$pack_name] SOC=${VAR}% V=${TOTAL_VOLTAGE}V I=${CHARGE_DISCHARGE}A ${BATTERY_STATUS} cells ${lowcell}-${highcell}mV Δ=${DIFF}mV"
}

# Main script — single invocation, no loop (HA automation drives cadence)
NOUPFILE=/root/share/SEPLOS_MQTT/nohup.out
if [ -n "$LOGFILE" ] && [ ! -f "$LOGFILE" ]; then
	touch "$LOGFILE"
fi

if [ ! -f "$NOUPFILE" ]; then
	touch "$NOUPFILE"
fi

# Publish Home Assistant MQTT auto-discovery configs (retained). Cheap; safe to run every cycle.
log "$(/root/share/SEPLOS_MQTT/publish_ha_discovery.sh)"

if [ -n "$LOGFILE" ] && [ -f "$LOGFILE" ]; then
	LOGFILE_SIZE=$(ls -l "$LOGFILE" | awk '{print $5}')
	if [ "$LOGFILE_SIZE" -ge "$MAXSIZE" ]; then
		mv "$LOGFILE" "$LOGFILE".old
	fi
fi

NOUPFILE_SIZE=$(ls -l "$NOUPFILE" | awk '{print $5}')
if [ "$NOUPFILE_SIZE" -ge "$MAXSIZE" ]; then
	cp "$NOUPFILE" "$NOUPFILE".old
	cat /dev/null > "$NOUPFILE"
fi

DATE=$(date '+%Y-%m-%d %H:%M:%S')
for pack in $(echo "$PACKS" | tr ',' ' '); do
	process_pack "$pack"
done
