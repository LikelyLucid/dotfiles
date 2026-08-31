import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STATUS = {
    "address": "AA:BB:CC:DD:EE:FF",
    "battery": {"percent": 70},
    "noise_control": {"mode": "transparency"},
    "eq": {"value": "balanced"},
    "spatial_audio": {"mode": "off"},
    "bass_boost": {"enabled": False, "level": 0},
    "features": {"values": {"wear_detection": True}},
    "low_latency": {"value": "off"},
    "dual_connection": {"value": "on"},
}


class BrokerScriptTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.temp = Path(self.temporary.name)
        self.bin = self.temp / "bin"
        self.bin.mkdir()
        self.log = self.temp / "nothing-cli.log"
        self._write_command(
            "nothing-cli",
            f"""#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CLI_LOG"
if [[ ${{BROKER_EXIT:-0}} != 0 && "$*" == *broker* ]]; then
  exit "$BROKER_EXIT"
fi
case "$*" in
  "--json broker status"|"--json status") printf '%s\n' '{json.dumps(STATUS, separators=(",", ":"))}' ;;
  "--json broker ping") printf '%s\n' '{{"revision":1,"connected":true}}' ;;
  "broker ping") printf '%s\n' 'connected: true' ;;
  *) ;;
esac
""",
        )
        self._write_command(
            "bluetoothctl",
            """#!/usr/bin/env bash
if [[ "$*" == "devices Connected" ]]; then
  printf '%s\n' 'Device AA:BB:CC:DD:EE:FF Nothing Headphone (1)'
fi
""",
        )
        self._write_command(
            "wpctl",
            """#!/usr/bin/env bash
case "$*" in
  "status -n") printf '%s\n' ' 103. bluez_output.AA_BB_CC_DD_EE_FF' ;;
  get-volume*) printf '%s\n' 'Volume: 0.25' ;;
  inspect*) printf '%s\n' 'node.description = "Nothing Headphone (1)"' ;;
esac
""",
        )
        self._write_command("eww", "#!/usr/bin/env bash\nexit 0\n")
        self._write_command("pkill", "#!/usr/bin/env bash\nexit 0\n")
        self.environment = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "CLI_LOG": str(self.log),
            "XDG_RUNTIME_DIR": str(self.temp / "runtime"),
            "XDG_CONFIG_HOME": str(ROOT),
        }
        Path(self.environment["XDG_RUNTIME_DIR"]).mkdir()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _write_command(self, name: str, content: str) -> None:
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def _commands(self) -> list[str]:
        return self.log.read_text().splitlines()

    def test_eww_audio_provider_reads_status_from_broker(self) -> None:
        result = subprocess.run(
            [str(ROOT / "eww/scripts/system-state.py"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertEqual(json.loads(result.stdout)["battery"], "70%")
        self.assertIn("--json broker status", self._commands())
        self.assertNotIn("--json status", self._commands())

    def test_eww_cache_read_does_not_refresh_the_cache_age(self) -> None:
        cache_path = Path(self.environment["XDG_RUNTIME_DIR"]) / "nothing-headphones-status.json"
        cache_path.write_text(json.dumps(STATUS))
        original_mtime_ns = time.time_ns() - 1_000_000_000
        os.utime(cache_path, ns=(original_mtime_ns, original_mtime_ns))
        environment = {**self.environment, "BROKER_EXIT": "2"}

        subprocess.run(
            [str(ROOT / "eww/scripts/system-state.py"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertEqual(cache_path.stat().st_mtime_ns, original_mtime_ns)

    def test_eww_headphone_action_sets_mode_through_broker(self) -> None:
        subprocess.run(
            [str(ROOT / "eww/scripts/system-action.sh"), "audio", "anc", "transparency"],
            check=True,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertIn("broker set anc transparency", self._commands())
        self.assertNotIn("anc transparency", self._commands())

    def test_eww_action_falls_back_only_when_the_broker_transport_is_unavailable(self) -> None:
        environment = {**self.environment, "BROKER_EXIT": "2"}

        subprocess.run(
            [str(ROOT / "eww/scripts/system-action.sh"), "audio", "anc", "transparency"],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertIn("broker set anc transparency", self._commands())
        self.assertIn("anc transparency", self._commands())
        self.assertNotIn("broker ping", self._commands())

    def test_waybar_audio_reads_status_from_broker(self) -> None:
        result = subprocess.run(
            [str(ROOT / "waybar/scripts/nothing-headphones.sh"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertEqual(json.loads(result.stdout)["alt"], "transparency")
        self.assertIn("--json broker status", self._commands())
        self.assertNotIn("--json status", self._commands())

    def test_waybar_falls_back_when_the_broker_transport_is_unavailable(self) -> None:
        environment = {**self.environment, "BROKER_EXIT": "2"}

        result = subprocess.run(
            [str(ROOT / "waybar/scripts/nothing-headphones.sh"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertEqual(json.loads(result.stdout)["alt"], "transparency")
        self.assertIn("--json broker status", self._commands())
        self.assertIn("--json status", self._commands())
        self.assertNotIn("--json broker ping", self._commands())

    def test_waybar_does_not_compete_when_the_running_broker_rejects_status(self) -> None:
        environment = {**self.environment, "BROKER_EXIT": "1"}

        result = subprocess.run(
            [str(ROOT / "waybar/scripts/nothing-headphones.sh"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertIn("status unavailable", json.loads(result.stdout)["tooltip"])
        self.assertIn("--json broker status", self._commands())
        self.assertNotIn("--json status", self._commands())

    def test_waybar_prefers_live_broker_state_over_a_fresh_cache(self) -> None:
        cached = {**STATUS, "noise_control": {"mode": "off"}}
        cache_path = Path(self.environment["XDG_RUNTIME_DIR"]) / "nothing-headphones-status.json"
        cache_path.write_text(json.dumps(cached))

        result = subprocess.run(
            [str(ROOT / "waybar/scripts/nothing-headphones.sh"), "audio"],
            check=True,
            capture_output=True,
            text=True,
            env=self.environment,
        )

        self.assertEqual(json.loads(result.stdout)["alt"], "transparency")
        self.assertIn("--json broker status", self._commands())


if __name__ == "__main__":
    unittest.main()
