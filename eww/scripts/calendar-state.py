#!/usr/bin/env python3
"""Emit the Google Calendar events used by the eww calendar popup."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


MAX_EVENTS = 8


def gws_path() -> Path | None:
    candidates = [Path.home() / ".local/bin/gws"]
    resolved = shutil.which("gws")
    if resolved:
        candidates.append(Path(resolved))
    return next((path for path in candidates if path.is_file()), None)


def gws_is_authenticated(gws: Path) -> bool:
    env = {**os.environ, "GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND": "file"}
    try:
        result = subprocess.run(
            [str(gws), "auth", "status"],
            check=False,
            capture_output=True,
            text=True,
            timeout=4,
            env=env,
        )
        payload = json.loads(result.stdout)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return False

    return bool(
        payload.get("token_cache_exists")
        or payload.get("encrypted_credentials_exists")
        or payload.get("plain_credentials_exists")
        or payload.get("credential_source") not in (None, "none")
    )


def google_api_path() -> Path | None:
    candidates = []
    hermes_home = os.environ.get("HERMES_HOME")
    if hermes_home:
        candidates.append(Path(hermes_home) / "skills/productivity/google-workspace/scripts/google_api.py")
    candidates.extend(
        [
            Path.home() / ".hermes/skills/productivity/google-workspace/scripts/google_api.py",
            Path("/var/lib/hermes/.hermes/skills/productivity/google-workspace/scripts/google_api.py"),
        ]
    )
    return next((path for path in candidates if path.is_file()), None)


def google_token_exists() -> bool:
    hermes_home = os.environ.get("HERMES_HOME")
    candidates = []
    if hermes_home:
        candidates.append(Path(hermes_home) / "google_token.json")
    candidates.append(Path.home() / ".hermes/google_token.json")
    return any(path.is_file() for path in candidates)


def month_bounds(now: datetime) -> tuple[datetime, datetime]:
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if start.month == 12:
        end = start.replace(year=start.year + 1, month=1)
    else:
        end = start.replace(month=start.month + 1)
    return start, end


def parse_event_time(value: Any) -> tuple[datetime | None, bool]:
    if isinstance(value, dict):
        value = value.get("dateTime") or value.get("date")
    if not value:
        return None, False

    value = str(value)
    if "T" not in value:
        try:
            local_tz = datetime.now().astimezone().tzinfo
            return datetime.strptime(value[:10], "%Y-%m-%d").replace(tzinfo=local_tz), True
        except ValueError:
            return None, True

    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None, False
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone()
    return parsed, False


def event_date(event: dict[str, Any]) -> datetime | None:
    parsed, _ = parse_event_time(event.get("start"))
    return parsed


def format_event(event: dict[str, Any]) -> dict[str, Any]:
    parsed, all_day = parse_event_time(event.get("start"))
    if parsed is None:
        parsed = datetime.now().astimezone()

    title = str(event.get("summary") or "Untitled event").strip()
    location = str(event.get("location") or "").strip()
    end, _ = parse_event_time(event.get("end"))
    if all_day:
        time_label = "ALL DAY"
        meta = parsed.strftime("%a %d %b")
    else:
        time_label = parsed.strftime("%a %d %b · %H:%M")
        if end is not None:
            time_label += f"–{end.strftime('%H:%M')}"
        meta = ""

    if location:
        meta = f"{meta} · {location}" if meta else location

    link = str(event.get("hangoutLink") or event.get("htmlLink") or "")
    calendar_name = str(event.get("organizer", {}).get("displayName") or event.get("organizer", {}).get("email") or "Primary")
    now = datetime.now().astimezone()
    progress = 0
    if not all_day and end is not None and parsed <= now <= end and end > parsed:
        progress = round((now - parsed).total_seconds() * 100 / (end - parsed).total_seconds())

    return {
        "time": time_label,
        "title": title,
        "meta": meta,
        "location": location,
        "has_link": link.startswith("https://"),
        "link_token": link.encode().hex() if link.startswith("https://") else "",
        "progress": progress,
        "calendar": calendar_name,
        "color": str(event.get("colorId") or "default"),
    }


def format_events(payload: Any) -> tuple[bool, str, list[dict[str, Any]]]:
    if isinstance(payload, dict):
        raw_events = payload.get("events", payload.get("items", []))
    else:
        raw_events = payload
    if not isinstance(raw_events, list):
        return False, "Google Calendar · invalid response", []

    valid_events = [event for event in raw_events if isinstance(event, dict) and event_date(event)]
    valid_events.sort(key=lambda event: event_date(event) or datetime.max)
    return True, "Google Calendar · synced", [format_event(event) for event in valid_events[:MAX_EVENTS]]


def fetch_gws_events(now: datetime, gws: Path) -> tuple[bool, str, list[dict[str, str]]]:
    _, end = month_bounds(now)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    params = json.dumps(
        {
            "calendarId": "primary",
            "timeMin": start.isoformat(),
            "timeMax": end.isoformat(),
            "singleEvents": True,
            "orderBy": "startTime",
            "maxResults": 50,
        },
        separators=(",", ":"),
    )
    command = [
        str(gws),
        "calendar",
        "events",
        "list",
        "--params",
        params,
    ]
    env = {**os.environ, "GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND": "file"}

    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
            env=env,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False, "Google Calendar · unavailable", []

    if result.returncode != 0:
        return False, "Google Calendar · reconnect required", []

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False, "Google Calendar · invalid response", []
    return format_events(payload)


def fetch_hermes_events(now: datetime) -> tuple[bool, str, list[dict[str, str]]] | None:
    api = google_api_path()
    if api is None or not google_token_exists():
        return None

    _, end = month_bounds(now)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    command = [
        sys.executable,
        str(api),
        "calendar",
        "list",
        "--start",
        start.isoformat(),
        "--end",
        end.isoformat(),
        "--max",
        "50",
    ]
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False, "Google Calendar · unavailable", []
    if result.returncode != 0:
        return False, "Google Calendar · reconnect required", []
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False, "Google Calendar · invalid response", []
    return format_events(payload)


def fetch_events(now: datetime) -> tuple[bool, str, list[dict[str, str]]]:
    gws = gws_path()
    if gws is not None:
        if gws_is_authenticated(gws):
            return fetch_gws_events(now, gws)
        hermes_result = fetch_hermes_events(now)
        if hermes_result is not None:
            return hermes_result
        return False, "Google Calendar · run gws auth login", []

    hermes_result = fetch_hermes_events(now)
    if hermes_result is not None:
        return hermes_result
    return False, "Google Calendar · not connected", []


def main() -> None:
    now = datetime.now().astimezone()
    connected, status, events = fetch_events(now)
    output = {
        "today": now.strftime("%A, %d %B %Y"),
        "month": now.strftime("%B %Y"),
        "connected": connected,
        "status": status,
        "events": events,
    }
    print(json.dumps(output, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
