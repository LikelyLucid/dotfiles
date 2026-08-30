#!/usr/bin/env python3
"""Emit deterministic JSON state for previewable system widgets."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def run(*args: str, timeout: float = 3) -> str:
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip()


def audio() -> dict[str, Any]:
    connected_line = next((line for line in run("bluetoothctl", "devices", "Connected").splitlines() if "nothing headphone" in line.lower()), "")
    connected = bool(connected_line)
    target = "@DEFAULT_AUDIO_SINK@"
    if connected:
        parts = connected_line.split(maxsplit=2)
        mac_fragment = parts[1].replace(":", "_") if len(parts) >= 2 else ""
        sink_match = re.search(rf"\b([0-9]+)\.\s+[^\n]*bluez_output\.{re.escape(mac_fragment)}", run("wpctl", "status", "-n"), re.IGNORECASE)
        if sink_match:
            target = sink_match.group(1)
    volume_text = run("wpctl", "get-volume", target)
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)", volume_text)
    volume = round(float(match.group(1)) * 100) if match else 0
    muted = "[MUTED]" in volume_text
    inspect = run("wpctl", "inspect", target)
    description_match = re.search(r'node\.description = "([^"]+)"', inspect)
    description = description_match.group(1) if description_match else ("Nothing Headphone (1)" if connected else "System output")
    result: dict[str, Any] = {
        "volume": volume,
        "muted": muted,
        "icon": "󰝟" if muted else ("󰕿" if volume < 34 else "󰖀" if volume < 67 else "󰕾"),
        "nothing_connected": connected,
        "device": description,
        "mode": "Speaker",
        "noise_mode": "off",
        "battery": "",
        "eq": "",
        "spatial": "",
    }
    if not connected:
        return result

    cli = shutil.which("nothing-cli")
    local_cli = Path.home() / "Projects/Nothing-cli/.release-venv/bin/nothing-cli"
    if cli is None and local_cli.is_file():
        cli = str(local_cli)
    if cli:
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
        cache = runtime / "nothing-headphones-status.json"
        lock = runtime / "nothing-headphones-cli.lock"
        raw = ""
        try:
            if time.time() - cache.stat().st_mtime <= 10:
                raw = cache.read_text()
        except OSError:
            pass
        if not raw:
            raw = run("flock", "-w", "4", str(lock), cli, "--json", "status", timeout=5)
            if raw:
                try:
                    cache.write_text(raw)
                except OSError:
                    pass
        try:
            state = json.loads(raw)
        except json.JSONDecodeError:
            state = {}
        mode = state.get("noise_control", {}).get("mode", "Connected")
        noise_mode = mode if mode in {"off", "transparency"} else "anc"
        result.update(
            mode="ANC" if mode == "smart-1" else str(mode).replace("-", " ").title(),
            noise_mode=noise_mode,
            battery=(f"{state.get('battery', {}).get('percent')}%" if state.get("battery", {}).get("percent") is not None else ""),
            eq=str(state.get("eq", {}).get("value", "")).replace("-", " ").title(),
            spatial=str(state.get("spatial_audio", {}).get("mode", "")).replace("-", " ").title(),
        )
    return result


def bluetooth() -> dict[str, Any]:
    show = run("bluetoothctl", "show")
    powered = "Powered: yes" in show
    discovering = "Discovering: yes" in show
    connected_macs = {parts[1] for line in run("bluetoothctl", "devices", "Connected").splitlines() if len(parts := line.split(maxsplit=2)) >= 2}
    devices = []
    for line in run("bluetoothctl", "devices", "Paired").splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) == 3:
            mac = parts[1]
            connected = mac in connected_macs
            battery_percent = -1
            if connected:
                battery_match = re.search(r"Battery Percentage:\s+0x[0-9a-f]+\s+\(([0-9]+)\)", run("bluetoothctl", "info", mac), re.IGNORECASE)
                if battery_match:
                    battery_percent = int(battery_match.group(1))
            devices.append({"mac": mac, "name": parts[2], "connected": connected, "battery_percent": battery_percent})
    devices.sort(key=lambda device: (not device["connected"], device["name"].lower()))
    return {"powered": powered, "discovering": discovering, "connected_count": len(connected_macs), "devices": devices}


def network() -> dict[str, Any]:
    wifi_enabled = run("nmcli", "-t", "-f", "WIFI", "g") == "enabled"
    active = run("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active")
    active_wifi = ""
    for line in active.splitlines():
        fields = line.rsplit(":", 2)
        if len(fields) == 3 and fields[1] == "802-11-wireless":
            active_wifi = fields[0].replace("\\:", ":")
            break
    known = set()
    for line in run("nmcli", "-t", "-f", "NAME,TYPE", "connection", "show").splitlines():
        name, _, kind = line.rpartition(":")
        if kind == "802-11-wireless":
            known.add(name.replace("\\:", ":"))
    networks: dict[str, dict[str, Any]] = {}
    for line in run("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no", timeout=5).splitlines():
        fields = line.split(":")
        if len(fields) < 4:
            continue
        in_use, ssid, signal, security = fields[0], fields[1], fields[2], ":".join(fields[3:])
        if not ssid:
            continue
        candidate = {"ssid": ssid, "token": ssid.encode().hex(), "signal": int(signal or 0), "security": security or "Open", "active": in_use == "*", "known": ssid in known}
        if ssid not in networks or candidate["signal"] > networks[ssid]["signal"]:
            networks[ssid] = candidate
    items = sorted(networks.values(), key=lambda item: (not item["active"], -item["signal"], item["ssid"].lower()))[:10]
    return {"enabled": wifi_enabled, "active": active_wifi, "networks": items}


def workspaces() -> dict[str, Any]:
    try:
        items = json.loads(run("hyprctl", "workspaces", "-j"))
        active = json.loads(run("hyprctl", "activeworkspace", "-j"))
    except json.JSONDecodeError:
        items, active = [], {}
    rows = [{"id": item.get("id", 0), "name": item.get("name", ""), "monitor": item.get("monitor", ""), "windows": item.get("windows", 0), "active": item.get("id") == active.get("id"), "title": item.get("lastwindowtitle", "") or "Empty"} for item in items]
    rows.sort(key=lambda item: item["id"])
    return {"active": active.get("name", ""), "monitor": active.get("monitor", ""), "workspaces": rows}


def power() -> dict[str, Any]:
    battery = next(iter(sorted(Path("/sys/class/power_supply").glob("BAT*"))), None)
    def read(name: str, default: str = "") -> str:
        try:
            return (battery / name).read_text().strip() if battery else default
        except OSError:
            return default
    capacity = int(read("capacity", "0"))
    status = read("status", "Unavailable")
    brightness = 0
    brightness_raw = run("brightnessctl", "-m")
    match = re.search(r",([0-9]+)%,", brightness_raw)
    if match:
        brightness = int(match.group(1))
    profile = run("tlpctl", "get") or "balanced"
    idle_active = run("systemctl", "--user", "is-active", "hypridle") == "active"
    return {"capacity": capacity, "status": status, "brightness": brightness, "profile": profile, "idle_active": idle_active, "icon": "󰁹" if capacity > 75 else "󰂀" if capacity > 40 else "󰁻"}


def notifications() -> dict[str, Any]:
    count_text = run("swaync-client", "-c")
    dnd_text = run("swaync-client", "-D")
    count_match = re.search(r"[0-9]+", count_text)
    count = int(count_match.group()) if count_match else 0
    return {"count": count, "dnd": dnd_text == "true", "tooltip": f"{count} Notifications"}


PROVIDERS = {"audio": audio, "bluetooth": bluetooth, "network": network, "workspaces": workspaces, "power": power, "notifications": notifications}
if len(sys.argv) != 2 or sys.argv[1] not in PROVIDERS:
    raise SystemExit(f"usage: {Path(sys.argv[0]).name} {'|'.join(PROVIDERS)}")
print(json.dumps(PROVIDERS[sys.argv[1]](), ensure_ascii=False, separators=(",", ":")))
