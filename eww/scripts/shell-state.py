#!/usr/bin/env python3
"""State adapter for the unified desktop-shell control center."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

HOME = Path.home()
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))


def run(*args: str, timeout: float = 2) -> str:
    try:
        return subprocess.run(args, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=timeout, check=False).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def json_run(*args: str, timeout: float = 2, fallback: Any = None) -> Any:
    try:
        return json.loads(run(*args, timeout=timeout))
    except json.JSONDecodeError:
        return fallback


def system_domain(name: str) -> dict[str, Any]:
    script = Path(__file__).with_name("system-state.py")
    try:
        return json.loads(run(str(script), name, timeout=6))
    except json.JSONDecodeError:
        return {}


def file_rows(paths: list[Path], limit: int = 6) -> list[dict[str, Any]]:
    rows = []
    seen: set[Path] = set()
    files: list[Path] = []
    for root in paths:
        if root.is_dir():
            try:
                files.extend(item for item in root.iterdir() if item.is_file())
            except OSError:
                pass
    for item in sorted(files, key=lambda path: path.stat().st_mtime if path.exists() else 0, reverse=True):
        if item in seen:
            continue
        seen.add(item)
        try:
            rows.append({"name": item.name, "path_token": str(item).encode().hex(), "age": max(0, int(time.time() - item.stat().st_mtime)), "size": item.stat().st_size})
        except OSError:
            continue
        if len(rows) >= limit:
            break
    return rows


def focus_state() -> dict[str, Any]:
    path = RUNTIME / "eww-focus-session.json"
    try:
        state = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        state = {}
    ends = int(state.get("ends", 0))
    remaining = max(0, ends - int(time.time()))
    return {"active": remaining > 0, "remaining": remaining, "minutes": (remaining + 59) // 60}


def health() -> dict[str, Any]:
    memory = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, value = line.split(":", 1)
            memory[key] = int(value.strip().split()[0])
    except (OSError, ValueError):
        pass
    total = memory.get("MemTotal", 0)
    available = memory.get("MemAvailable", 0)
    memory_percent = round((total - available) * 100 / total) if total else 0
    load = Path("/proc/loadavg").read_text().split()[0] if Path("/proc/loadavg").exists() else "0"
    root = shutil.disk_usage("/")
    temperatures = []
    for temp in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        try:
            value = int(temp.read_text()) / 1000
            if 10 <= value <= 120:
                temperatures.append(value)
        except (OSError, ValueError):
            pass
    failed = run("systemctl", "--failed", "--no-legend", "--plain").splitlines()
    processes = []
    for line in run("ps", "-eo", "comm=,pcpu=,pmem=", "--sort=-pcpu").splitlines()[:5]:
        parts = line.split()
        if len(parts) >= 3:
            processes.append({"name": " ".join(parts[:-2]), "cpu": parts[-2], "memory": parts[-1]})
    return {"load": load, "memory": memory_percent, "disk": round(root.used * 100 / root.total), "temperature": round(max(temperatures)) if temperatures else 0, "failed_services": len(failed), "processes": processes}


def network_details() -> dict[str, Any]:
    addresses = json_run("ip", "-j", "address", fallback=[]) or []
    ips = []
    for iface in addresses:
        if iface.get("ifname") == "lo":
            continue
        for info in iface.get("addr_info", []):
            if info.get("scope") == "global":
                ips.append({"interface": iface.get("ifname", ""), "address": info.get("local", ""), "family": info.get("family", "")})
    route = run("ip", "route", "show", "default").splitlines()
    gateway_match = re.search(r"default via (\S+)", route[0] if route else "")
    vpn = [line.split(":", 1)[0] for line in run("nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active").splitlines() if line.endswith(":vpn") or line.endswith(":wireguard")]
    tailscale = json_run("tailscale", "status", "--json", timeout=3, fallback={}) if shutil.which("tailscale") else {}
    dns = []
    try:
        for line in Path("/etc/resolv.conf").read_text().splitlines():
            if line.startswith("nameserver "):
                dns.append(line.split()[1])
    except OSError:
        pass
    rx = tx = 0
    try:
        for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
            name, values = line.split(":", 1)
            if name.strip() != "lo":
                fields = values.split()
                rx += int(fields[0]); tx += int(fields[8])
    except (OSError, ValueError, IndexError):
        pass
    rates = {"time": time.time(), "rx": rx, "tx": tx}
    rate_cache = RUNTIME / "eww-network-counters.json"
    rx_rate = tx_rate = 0
    try:
        previous = json.loads(rate_cache.read_text())
        elapsed = max(0.1, rates["time"] - float(previous["time"]))
        rx_rate = max(0, round((rx - int(previous["rx"])) / elapsed))
        tx_rate = max(0, round((tx - int(previous["tx"])) / elapsed))
    except (OSError, ValueError, KeyError, json.JSONDecodeError):
        pass
    try:
        rate_cache.write_text(json.dumps(rates))
    except OSError:
        pass
    return {"ips": ips[:6], "gateway": gateway_match.group(1) if gateway_match else "Unavailable", "dns": dns[:3], "rx_rate": rx_rate, "tx_rate": tx_rate, "vpn": vpn, "tailscale": bool(tailscale.get("Self")), "tailscale_name": tailscale.get("Self", {}).get("DNSName", "").rstrip(".")}


def displays() -> dict[str, Any]:
    monitors = json_run("hyprctl", "monitors", "-j", fallback=[]) or []
    rows = [{"name": item.get("name", ""), "resolution": f"{item.get('width', 0)}×{item.get('height', 0)}", "refresh": round(item.get("refreshRate", 0)), "scale": item.get("scale", 1), "focused": item.get("focused", False)} for item in monitors]
    return {"monitors": rows, "night_light": bool(run("pgrep", "-x", "hyprsunset")), "wallpaper": "Wallust managed" if (HOME / "dotfiles/wallust").exists() else "System default"}


def media() -> dict[str, Any]:
    players = [line for line in run("playerctl", "-l").splitlines() if line] if shutil.which("playerctl") else []
    rows = []
    for player in players[:6]:
        title = run("playerctl", "-p", player, "metadata", "--format", "{{title}}", timeout=1) or "Nothing playing"
        artist = run("playerctl", "-p", player, "metadata", "--format", "{{artist}}", timeout=1)
        status = run("playerctl", "-p", player, "status", timeout=1) or "Stopped"
        rows.append({"name": player, "token": player.encode().hex(), "title": title, "artist": artist, "status": status})
    return {"players": rows, "available": bool(shutil.which("playerctl"))}


def windows() -> list[dict[str, Any]]:
    clients = json_run("hyprctl", "clients", "-j", fallback=[]) or []
    rows = []
    for client in clients:
        title = client.get("title") or client.get("class") or "Window"
        rows.append({"title": title, "class": client.get("class", ""), "workspace": client.get("workspace", {}).get("name", ""), "address": str(client.get("address", "")).encode().hex(), "focused": bool(client.get("focusHistoryID") == 0)})
    return rows[:12]


def mounts() -> list[dict[str, Any]]:
    data = json_run("lsblk", "-J", "-o", "NAME,LABEL,SIZE,FSTYPE,MOUNTPOINTS,RM", fallback={}) or {}
    rows = []
    def visit(device: dict[str, Any]) -> None:
        mountpoints = [point for point in (device.get("mountpoints") or []) if point]
        if device.get("fstype") or mountpoints:
            rows.append({"name": device.get("label") or device.get("name", ""), "device": f"/dev/{device.get('name', '')}", "size": device.get("size", ""), "filesystem": device.get("fstype") or "", "mounted": bool(mountpoints), "mountpoint": mountpoints[0] if mountpoints else "", "removable": bool(device.get("rm"))})
        for child in device.get("children") or []:
            visit(child)
    for device in data.get("blockdevices", []):
        visit(device)
    seen_mountpoints = {row["mountpoint"] for row in rows if row["mountpoint"]}
    mount_data = json_run("findmnt", "-J", "-o", "SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL", fallback={}) or {}
    def visit_mount(item: dict[str, Any]) -> None:
        target = str(item.get("target") or "")
        if target.startswith("/mnt/") and target not in seen_mountpoints:
            rows.append({"name": str(item.get("source") or target), "device": "", "size": str(item.get("size") or ""), "filesystem": str(item.get("fstype") or ""), "mounted": True, "mountpoint": target, "removable": False})
            seen_mountpoints.add(target)
        for child in item.get("children") or []:
            visit_mount(child)
    for item in mount_data.get("filesystems", []):
        visit_mount(item)
    return rows[:10]


def privacy() -> dict[str, Any]:
    nodes = json_run("pw-dump", fallback=[]) or []
    recording = any(
        node.get("type") == "PipeWire:Interface:Node"
        and node.get("info", {}).get("state") == "running"
        and node.get("info", {}).get("props", {}).get("media.class") == "Stream/Input/Audio"
        for node in nodes
    )
    cameras = sorted(Path("/dev").glob("video*"))
    camera = bool(run("lsof", "-t", *(str(device) for device in cameras), timeout=0.2)) if cameras else False
    return {"microphone_in_use": recording, "camera_in_use": camera, "camera_available": bool(cameras)}


def development() -> dict[str, Any]:
    kubectl = shutil.which("kubectl")
    context = run("kubectl", "config", "current-context", timeout=2) if kubectl else ""
    ports = []
    for line in run("ss", "-H", "-ltn").splitlines()[:12]:
        parts = line.split()
        if len(parts) >= 4:
            ports.append(parts[3])
    return {"kubectl": bool(kubectl), "context": context or "Not configured", "ports": ports[:8], "docker": bool(shutil.which("docker")), "podman": bool(shutil.which("podman"))}


def clipboard() -> dict[str, Any]:
    if not shutil.which("cliphist"):
        return {"available": False, "items": []}
    items = []
    for line in run("cliphist", "list").splitlines()[:12]:
        identifier, separator, text = line.partition("\t")
        if separator and not text.startswith("[[ binary data"):
            items.append({"id": identifier, "text": text.replace("\n", " ")[:80]})
    return {"available": True, "items": items}


def nixos() -> dict[str, Any]:
    generation = Path("/nix/var/nix/profiles/system").resolve().name if Path("/nix/var/nix/profiles/system").exists() else "Unavailable"
    repo = HOME / "nixos"
    dirty = bool(run("git", "status", "--porcelain", timeout=2)) if (repo / ".git").exists() else False
    revision = run("git", "rev-parse", "--short", "HEAD", timeout=2) if (repo / ".git").exists() else ""
    generations = len(list(Path("/nix/var/nix/profiles").glob("system-*-link")))
    closure_size = run("nix", "path-info", "-Sh", "/run/current-system", timeout=4).split()
    return {"generation": generation, "dirty": dirty, "revision": revision, "generations": generations, "closure_size": closure_size[-1] if closure_size else "Unavailable", "controls_enabled": False}


def weather() -> dict[str, Any]:
    location = os.environ.get("EWW_WEATHER_LOCATION", "").strip()
    if not location:
        return {"available": False, "summary": "Set EWW_WEATHER_LOCATION to enable weather", "location": "Not configured"}
    cache = RUNTIME / "eww-weather.json"
    try:
        if time.time() - cache.stat().st_mtime < 1800:
            return json.loads(cache.read_text())
    except (OSError, json.JSONDecodeError):
        pass
    try:
        request = urllib.request.Request(f"https://wttr.in/{urllib.parse.quote(location)}?format=j1", headers={"User-Agent": "eww-control-center"})
        with urllib.request.urlopen(request, timeout=3) as response:
            payload = json.loads(response.read().decode())
        current = payload.get("current_condition", [{}])[0]
        description = current.get("weatherDesc", [{}])[0].get("value", "Weather")
        result = {"available": True, "summary": f"{current.get('temp_C', '?')}° · {description}", "location": location}
        cache.write_text(json.dumps(result))
        return result
    except (OSError, ValueError, KeyError, json.JSONDecodeError):
        return {"available": False, "summary": "Weather provider unavailable", "location": location}


def main() -> dict[str, Any]:
    providers = {
        "audio": lambda: system_domain("audio"),
        "bluetooth": lambda: system_domain("bluetooth"),
        "network": lambda: system_domain("network"),
        "power": lambda: system_domain("power"),
        "notifications": lambda: system_domain("notifications"),
        "health": health,
        "network_details": network_details,
        "display": displays,
        "media": media,
        "focus": focus_state,
        "clipboard": clipboard,
        "downloads": lambda: file_rows([HOME / "Downloads"]),
        "screenshots": lambda: file_rows([HOME / "Pictures/Screenshots", HOME / "Screenshots"]),
        "windows": windows,
        "mounts": mounts,
        "privacy": privacy,
        "development": development,
        "nixos": nixos,
        "weather": weather,
    }
    with ThreadPoolExecutor(max_workers=10) as pool:
        futures = {name: pool.submit(provider) for name, provider in providers.items()}
        state = {name: future.result() for name, future in futures.items()}
    state.update({
        "smart_home": {"available": bool(shutil.which("openhue")), "summary": "OpenHue ready" if shutil.which("openhue") else "Install and configure OpenHue"},
        "timestamp": int(time.time()),
    })
    return state


print(json.dumps(main(), ensure_ascii=False, separators=(",", ":")))
