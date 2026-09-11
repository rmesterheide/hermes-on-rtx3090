---
name: home-assistant
description: Query and control a local Home Assistant instance via its REST API (states, lights, switches, climate, sensors). Use when the user asks about devices, rooms, sensors, or wants to turn something on/off.
version: 1.0.0
author: rmesterheide
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [smart-home, home-assistant, iot]
    requires_toolsets: [terminal]
required_environment_variables:
  - name: HA_URL
    prompt: "Home Assistant base URL, e.g. http://192.168.0.50:8123"
  - name: HA_TOKEN
    prompt: "Home Assistant long-lived access token (Profile -> Security -> Create token)"
---
# Home Assistant

Talk to Home Assistant through its REST API using `curl` in the terminal tool.
`$HA_URL` and `$HA_TOKEN` are already present in the shell environment - never print the token.

## Common calls

Health check:
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/" 
```

All entity states (large - always filter with jq):
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states" \
  | jq -r '.[] | "\(.entity_id)\t\(.state)\t\(.attributes.friendly_name // "")"'
```

Lights that are currently on:
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states" \
  | jq -r '.[] | select(.entity_id|startswith("light.")) | select(.state=="on") | .attributes.friendly_name'
```

Single entity:
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states/sensor.living_room_temperature"
```

Call a service (turn a light off):
```bash
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id": "light.kitchen"}' "$HA_URL/api/services/light/turn_off"
```

## Rules

1. Read before you write: fetch states first, then act.
2. Only call services the user explicitly asked for. Never toggle locks, alarms, covers or climate without confirmation.
3. Resolve friendly names to entity_ids via /api/states; if several match, ask the user which one.
4. Keep answers short: list the relevant entities and their states, no raw JSON dumps.
