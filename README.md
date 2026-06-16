# Seplos MQTT
Read data From Seplos BMS and send them to the Home Assistant

This is a bash script that read data from Seplos BMS via RS485 port and send the data to the Home Assistan via MQTT.

## Hardware requirements:
1. Raspberry (i use an RPI4)
2. USB to RS485 adapter
3. [Seplos BMS](https://www.alibaba.com/product-detail/Seplos-50A-100A-150A-200A-24V_1600246972725.html?spm=a2700.galleryofferlist.normal_offer.d_title.41f63a936kcnil)
4. Home assitant with configured MQTT broker

## Installation and configuration

Prepare Raspberry with Raspberry PI OS
perform the apt-get update and the apt-get upgrade

move to the your user home and use git clone to download this script

```
git clone https://github.com/byte4geek/SEPLOS_MQTT.git

chmod 700 ~/SEPLOS_MQTT/query_seplos_ha.sh ~/SEPLOS_MQTT/run_bms_query.sh ~/SEPLOS_MQTT/publish_ha_discovery.sh
```

edit the file config.ini ```~/SEPLOS_MQTT/config.ini``` and set the serial device (`DEV`), baud rate (`BAUD`) and MQTT server information:

```
# insert the mqtt info below
# Global settings
MQTTHOST=192.168.1.2
TOPIC=seplos
MQTTUSER=mqttuser
MQTTPASWD=mqttpassword
TELEPERIOD=10
LOGFILE=
MAXSIZE=2000000
CELL_MIN_VOLT=2500
CELL_MAX_VOLT=3800

# Pack list — comma-separated. Each name needs a matching block below.
PACKS=pack1

# pack1 (master, single-pack default)
pack1_DEV=/dev/ttyUSB0
pack1_BAUD=19200          # 19200 for v16/v3, 9600 for older v2
pack1_ADDR=00             # protocol address, two hex chars
pack1_ID=364715398511     # unique per pack; appended to MQTT topic + HA unique_id
pack1_NAME=Master         # friendly name shown in Home Assistant

# Example second pack — uncomment + add "pack2" to PACKS to enable
#pack2_DEV=/dev/ttyUSB1
#pack2_BAUD=19200
#pack2_ADDR=01
#pack2_ID=364715398512
#pack2_NAME=Slave 1
```

then install the following pkg:

```
sudo apt-get install jq bc mosquitto-clients
```

edit the crontab to run the script at the boot

```crontab -e``` and add the line below:
```
@reboot cd ~/SEPLOS_MQTT/| nohup /home/pi/SEPLOS_MQTT/run_bms_query.sh &
```

## Manual execution
simply run 
```~/SEPLOS_MQTT/run_bms_query.sh```
or
```nohup ~/SEPLOS_MQTT/run_bms_query.sh &```

## Multiple packs (master + slaves)

Each entry in `PACKS=` is queried in turn every cycle and published as its own MQTT topic / HA device. Pack-specific serial settings are read from the matching `<name>_DEV`, `<name>_BAUD`, `<name>_ADDR` keys, so packs can sit on different USB-RS485 adapters with different baud rates (typical Seplos parallel setup: master 9600 on port A, slaves 19200 daisy-chained).

Use `probe_slaves.sh` to find which addresses respond on a given adapter:
```
./probe_slaves.sh                # probes 0x00..0x0F on the default DEV/BAUD
DEV=/dev/ttyUSB1 BAUD=19200 ./probe_slaves.sh
```
Set the responding address as `<packN>_ADDR` and add the pack name to `PACKS`.

## Manual test

Query a single pack with explicit overrides:
```
DEV=/dev/ttyUSB0 BAUD=9600 ADDR=00 ~/SEPLOS_MQTT/query_seplos_ha.sh 4201
```

you can see the output like this:
```
3334
3334
3334
3335
3334
3335
3334
3335
3335
3336
3335
3335
3335
3335
3335
3334
31.7
32.2
32.0
31.8
36.5
33.7
0
53.35
273.97
280.00
97.8
280.00
12
100.0
54.45
```

When the script run, it sends an MQTT message like this:

```
homeassistant/sensor/seplos_364715398511 {"lowest_cell":"Cell 8 - 3427 mV","highest_cell":"Cell 7 - 3435 mV","difference":"8","cell01":"3431","cell02":"3431","cell03":"3434","cell04":"3430","cell05":"3433","cell06":"3432","cell07":"3435","cell08":"3427","cell09":"3431","cell10":"3428","cell11":"3433","cell12":"3433","cell13":"3435","cell14":"3431","cell15":"3435","cell16":"3428","cell_temp1":"31.7","cell_temp2":"32.2","cell_temp3":"32.0","cell_temp4":"31.9","env_temp":"37.2","power_temp":"34.9","charge_discharge":"26.01","total_voltage":"54.90","residual_capacity":"271.24","soc":"96.8","cycles":"12","soh":"100.0","port_voltage":"54.93","residual_capacity_kwh":"14.892","battery_status":"Charging","battery_power":"1427.9"}
```

## Installation and configuration for Home Assistant only

This section describe the installation and configuration for people that have the rs485 directly connecte to the Home Assistant Raspberry.
Require Home Assistant Operating System

install the docker "SSH & Web Terminal" https://github.com/hassio-addons/addon-ssh and configure it

connect to the HA with ssh port 22

```
cd /share

git clone https://github.com/byte4geek/SEPLOS_MQTT.git

chmod 700 ./SEPLOS_MQTT/query_seplos_ha.sh ./SEPLOS_MQTT/run_bms_query_ha.sh ./SEPLOS_MQTT/publish_ha_discovery.sh

ssh-copy-id root@<YOUR HA IP>     ---> and choose yes
```

edit the file config.ini ```./SEPLOS_MQTT/config.ini``` and set the serial device (`DEV`), baud rate (`BAUD`) and MQTT server information:

```
# insert the mqtt info below
# Global settings
MQTTHOST=192.168.1.2
TOPIC=seplos
MQTTUSER=mqttuser
MQTTPASWD=mqttpassword
TELEPERIOD=10
LOGFILE=
MAXSIZE=2000000
CELL_MIN_VOLT=2500
CELL_MAX_VOLT=3800

# Pack list — comma-separated. Each name needs a matching block below.
PACKS=pack1

# pack1 (master, single-pack default)
pack1_DEV=/dev/ttyUSB0
pack1_BAUD=19200          # 19200 for v16/v3, 9600 for older v2
pack1_ADDR=00             # protocol address, two hex chars
pack1_ID=364715398511     # unique per pack; appended to MQTT topic + HA unique_id
pack1_NAME=Master         # friendly name shown in Home Assistant

# Example second pack — uncomment + add "pack2" to PACKS to enable
#pack2_DEV=/dev/ttyUSB1
#pack2_BAUD=19200
#pack2_ADDR=01
#pack2_ID=364715398512
#pack2_NAME=Slave 1
```

create a shell command in HA:
```
seplos_query: ssh -i /config/.ssh/id_rsa -o StrictHostKeyChecking=no root@<YOUR HA IP> "cd /share/SEPLOS_MQTT;nohup /share/SEPLOS_MQTT/run_bms_query_ha.sh &"
```

then create an automation to run the script every 10 seconds or what you prefer
```
- id: seplos_startup_automation
  alias: Seplos Startup Automation
  trigger:
    platform: time_pattern
    seconds: "/10"
  action:
    - service: shell_command.seplos_query
```

## Configuring Home Assistant

### Option A — MQTT auto-discovery (recommended)

`run_bms_query.sh` / `run_bms_query_ha.sh` call `publish_ha_discovery.sh` at startup. For each pack listed in `PACKS=` it publishes a retained **device-based** discovery payload at `homeassistant/device/<topic>_<pack_ID>/config` (HA 2024.11+ format) describing every sensor as a component under one device named `SEPLOS BMS <pack_NAME>`. Home Assistant's MQTT integration picks it up automatically and creates all entities pre-configured (units, device classes, icons), with `origin` metadata pointing back to this project.

Requirements:
- Home Assistant **2024.11 or newer** (device-based discovery support)
- MQTT integration enabled in Home Assistant
- MQTT discovery prefix left at the default `homeassistant`

Sensors published:
- `cell01`..`cell16` (mV)
- `lowest_cell_v`, `lowest_cell_n`, `highest_cell_v`, `highest_cell_n`, `difference`
- `cell_temp1`..`cell_temp4`, `env_temp`, `power_temp` (°C)
- `port_voltage`, `total_voltage` (V), `charge_discharge` (A)
- `residual_capacity` (Ah), `residual_capacity_kwh` (kWh), `soc` (%), `soh` (%), `cycles`
- `battery_power` (W, signed — positive = charging, negative = discharging — computed from `charge_discharge × total_voltage`)
- `battery_status` (Charging / Discharge / Standby — computed from `charge_discharge`)

### Energy dashboard setup

`battery_power` (W) is published with `device_class=power` + `state_class=measurement` so Home Assistant can integrate it. The Energy dashboard's *Home Battery Storage* section needs cumulative in/out kWh (`total_increasing`), which HA derives via two built-in helpers:

1. Settings → Devices & Services → Helpers → **Add Helper → Integration – Riemann sum integral sensor**
   - Source: `sensor.seplos_bms_master_battery_power` (per pack)
   - Method: `trapezoidal`
   - Unit prefix: `k` (kW → kWh integral)
   - Unit time: `Hours`
   - This produces a signed cumulative kWh sensor
2. Add two **Utility Meter** helpers from that integral, one for charging, one for discharging (each picks up only the positive / negative slope via a template if needed).
3. Energy dashboard → *Add battery* → pick the two utility-meter sensors.

Repeat per pack if you run multiple.

Manual publish (e.g. after editing `config.ini`):
```
~/SEPLOS_MQTT/publish_ha_discovery.sh
```

Unique IDs match the legacy `configuration.yaml` entries, so users migrating from Option B will not get duplicate entities (entity friendly names may change because all sensors now sit under the SEPLOS BMS device — rename in the HA UI if desired).

To clear an old retained discovery payload (e.g. after changing `id_prefix`):
```
mosquitto_pub -h <MQTTHOST> -u <user> -P <pass> -r -n -t homeassistant/device/<old_node_id>/config
```

Add sensors to your dashboard using `lovelace.yaml`.

### Option B — Manual configuration.yaml (legacy)

If you prefer not to use MQTT discovery, create all MQTT sensors and template sensors manually using `configuration.yaml`, then add them to the dashboard with `lovelace.yaml`. Not required when Option A is in use.

example:
![BMS dashboard](https://github.com/byte4geek/Seplos-BMS-vs-Home-Assistant/raw/main/bms_ha_panel.JPG)

# Donation
Buy me a coffee

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=VK4CSX9NVQAZU)
