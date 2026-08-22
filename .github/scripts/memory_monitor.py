#!/usr/bin/env python3
"""Cross-platform memory monitor and OOM watchdog for CI builds.

Monitors memory usage (RAM, Swap, Commit charge) in real-time, logs top
memory-consuming processes with their command lines, and terminates the
monitored build process tree if available memory drops below a safe threshold
to prevent unrecoverable runner agent crashes (OOM kills without logs).

Usage:
  # Mode 1: Run and monitor a build command directly
  python memory_monitor.py run --log-file build-monitor.log --min-avail-mb 250 -- cmd args...

  # Mode 2: Start/Stop in background around multiple steps
  python memory_monitor.py start --log-file build-monitor.log --min-avail-mb 250
  python memory_monitor.py stop
  python memory_monitor.py summarize --log-file build-monitor.log --summary-file $GITHUB_STEP_SUMMARY
"""

from __future__ import annotations

import argparse
import ctypes
import datetime
import os
import platform
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path


class MemoryStats:
    def __init__(
        self,
        total_phys_mb: float = 0.0,
        avail_phys_mb: float = 0.0,
        total_swap_mb: float = 0.0,
        avail_swap_mb: float = 0.0,
        total_commit_mb: float = 0.0,
        avail_commit_mb: float = 0.0,
        percent_used: float = 0.0,
    ):
        self.total_phys_mb = total_phys_mb
        self.avail_phys_mb = avail_phys_mb
        self.total_swap_mb = total_swap_mb
        self.avail_swap_mb = avail_swap_mb
        self.total_commit_mb = total_commit_mb
        self.avail_commit_mb = avail_commit_mb
        self.percent_used = percent_used

    def __str__(self) -> str:
        s = f"RAM: {self.avail_phys_mb:.0f}MB free / {self.total_phys_mb:.0f}MB total ({self.percent_used:.1f}% used)"
        if self.total_commit_mb > 0:
            s += f" | Commit: {self.avail_commit_mb:.0f}MB free / {self.total_commit_mb:.0f}MB total"
        elif self.total_swap_mb > 0:
            s += f" | Swap: {self.avail_swap_mb:.0f}MB free / {self.total_swap_mb:.0f}MB total"
        return s


def get_memory_stats() -> MemoryStats:
    system = platform.system()
    if system == "Windows":
        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            mb = 1024.0 * 1024.0
            return MemoryStats(
                total_phys_mb=stat.ullTotalPhys / mb,
                avail_phys_mb=stat.ullAvailPhys / mb,
                total_commit_mb=stat.ullTotalPageFile / mb,
                avail_commit_mb=stat.ullAvailPageFile / mb,
                percent_used=float(stat.dwMemoryLoad),
            )
    elif system == "Linux":
        mem_info = {}
        try:
            with open("/proc/meminfo", "r", encoding="utf-8") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        k = parts[0].strip()
                        v = parts[1].strip().split()[0]
                        mem_info[k] = float(v) / 1024.0  # kB to MB
            total_phys = mem_info.get("MemTotal", 0.0)
            avail_phys = mem_info.get("MemAvailable", mem_info.get("MemFree", 0.0))
            total_swap = mem_info.get("SwapTotal", 0.0)
            free_swap = mem_info.get("SwapFree", 0.0)
            pct = 100.0 * (1.0 - (avail_phys / total_phys)) if total_phys > 0 else 0.0
            return MemoryStats(
                total_phys_mb=total_phys,
                avail_phys_mb=avail_phys,
                total_swap_mb=total_swap,
                avail_swap_mb=free_swap,
                percent_used=pct,
            )
        except Exception:
            pass
    elif system == "Darwin":
        try:
            total_bytes = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).strip())
            total_phys = total_bytes / (1024.0 * 1024.0)
            vm = subprocess.check_output(["vm_stat"]).decode("utf-8")
            free_pages = 0
            page_size = 4096
            for line in vm.splitlines():
                if "page size of" in line:
                    page_size = int(line.split()[-2])
                if "Pages free:" in line or "Pages speculative:" in line or "Pages inactive:" in line:
                    free_pages += int(line.split()[-1].strip("."))
            avail_phys = (free_pages * page_size) / (1024.0 * 1024.0)
            pct = 100.0 * (1.0 - (avail_phys / total_phys)) if total_phys > 0 else 0.0
            return MemoryStats(
                total_phys_mb=total_phys,
                avail_phys_mb=avail_phys,
                percent_used=pct,
            )
        except Exception:
            pass

    return MemoryStats()


class ProcessInfo:
    def __init__(self, pid: int, name: str, rss_mb: float, cmdline: str = ""):
        self.pid = pid
        self.name = name
        self.rss_mb = rss_mb
        self.cmdline = cmdline


def get_top_processes(limit: int = 10) -> list[ProcessInfo]:
    system = platform.system()
    procs: list[ProcessInfo] = []

    try:
        import psutil
        for p in psutil.process_iter(["pid", "name", "memory_info", "cmdline"]):
            try:
                info = p.info
                rss_mb = (info["memory_info"].rss if info["memory_info"] else 0) / (1024.0 * 1024.0)
                cmd = " ".join(info["cmdline"]) if info["cmdline"] else (info["name"] or "")
                procs.append(ProcessInfo(pid=info["pid"], name=info["name"] or "unknown", rss_mb=rss_mb, cmdline=cmd))
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        procs.sort(key=lambda p: p.rss_mb, reverse=True)
        return procs[:limit]
    except ImportError:
        pass

    if system == "Windows":
        try:
            ps_cmd = (
                "Get-CimInstance Win32_Process | "
                "Select-Object ProcessId, Name, WorkingSetSize, CommandLine | "
                "ConvertTo-Json -Compress"
            )
            out = subprocess.check_output(
                ["powershell", "-NoProfile", "-Command", ps_cmd],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=5,
            )
            import json
            data = json.loads(out)
            if isinstance(data, dict):
                data = [data]
            for item in data:
                pid = item.get("ProcessId") or 0
                name = item.get("Name") or "unknown"
                ws = (item.get("WorkingSetSize") or 0) / (1024.0 * 1024.0)
                cmd = item.get("CommandLine") or ""
                procs.append(ProcessInfo(pid=pid, name=name, rss_mb=ws, cmdline=cmd))
        except Exception:
            pass
    elif system in ("Linux", "Darwin"):
        try:
            out = subprocess.check_output(
                ["ps", "-eo", "pid,rss,comm,args"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=5,
            )
            for line in out.splitlines()[1:]:
                parts = line.strip().split(None, 3)
                if len(parts) >= 3:
                    try:
                        pid = int(parts[0])
                        rss_kb = float(parts[1])
                        comm = parts[2]
                        args = parts[3] if len(parts) > 3 else comm
                        procs.append(ProcessInfo(pid=pid, name=comm, rss_mb=rss_kb / 1024.0, cmdline=args))
                    except ValueError:
                        continue
        except Exception:
            pass

    procs.sort(key=lambda p: p.rss_mb, reverse=True)
    return procs[:limit]


def kill_target_build_processes(monitored_pid: int | None = None) -> None:
    system = platform.system()
    if monitored_pid:
        if system == "Windows":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(monitored_pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            try:
                os.killpg(os.getpgid(monitored_pid), signal.SIGKILL)
            except Exception:
                try:
                    os.kill(monitored_pid, signal.SIGKILL)
                except Exception:
                    pass

    # Also kill notorious heavy build subprocesses if still alive
    if system == "Windows":
        for exe_name in ("cl.exe", "link.exe", "mspdbsrv.exe", "ninja.exe", "vcpkg.exe", "cmake.exe", "cvtres.exe"):
            subprocess.run(["taskkill", "/F", "/IM", exe_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    target_names = {
        "cl.exe", "link.exe", "ninja.exe", "vcpkg.exe", "cmake.exe",
        "ninja", "vcpkg", "cmake", "gcc", "g++", "clang", "clang++", "ld", "ld.lld", "lld",
        "mspdbsrv.exe", "mspdbsrv", "c1.exe", "c2.exe", "cvtres.exe",
    }
    top_procs = get_top_processes(30)
    for p in top_procs:
        p_name = p.name.lower()
        if p_name in target_names or any(p_name.startswith(t) for t in ("cl", "link", "ninja", "vcpkg")):
            if system == "Windows":
                subprocess.run(["taskkill", "/F", "/PID", str(p.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                try:
                    os.kill(p.pid, signal.SIGKILL)
                except Exception:
                    pass


class Monitor:
    def __init__(
        self,
        log_file: Path,
        min_avail_mb: float = 750.0,
        check_interval_sec: float = 0.25,
        monitored_pid: int | None = None,
        report_file: Path | None = None,
    ):
        self.log_file = log_file
        self.min_avail_mb = min_avail_mb
        self.check_interval_sec = check_interval_sec
        self.monitored_pid = monitored_pid
        self.report_file = report_file
        self.stop_event = threading.Event()
        self.oom_triggered = False
        self.peak_mem_percent = 0.0
        self.min_avail_phys_seen = float("inf")
        self.min_avail_commit_seen = float("inf")
        self.peak_procs: dict[str, float] = {}

    def log(self, msg: str, console: bool = False) -> None:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {msg}"
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(line + "\n")
            f.flush()
        if console:
            if "CRITICAL" in msg:
                print(f"::error::[Memory Monitor] {msg}", flush=True)
            else:
                print(f"[Memory Monitor] {line}", flush=True)

    def run_loop(self) -> None:
        self.log(f"Monitor active. Safe threshold: >= {self.min_avail_mb:.0f}MB free. Monitored PID: {self.monitored_pid}", console=True)
        last_console_time = 0.0

        while not self.stop_event.is_set():
            stats = get_memory_stats()
            self.peak_mem_percent = max(self.peak_mem_percent, stats.percent_used)
            if stats.avail_phys_mb > 0:
                self.min_avail_phys_seen = min(self.min_avail_phys_seen, stats.avail_phys_mb)
            if stats.avail_commit_mb > 0:
                self.min_avail_commit_seen = min(self.min_avail_commit_seen, stats.avail_commit_mb)

            # Check danger condition: swap / commit charge is the last resort
            is_critical = False
            reasons = []
            if stats.total_commit_mb > 0:
                if stats.avail_commit_mb < self.min_avail_mb:
                    is_critical = True
                    reasons.append(f"Available Commit Charge is critically low: {stats.avail_commit_mb:.1f}MB < {self.min_avail_mb:.0f}MB")
            elif stats.total_swap_mb > 0:
                if stats.avail_swap_mb < self.min_avail_mb:
                    is_critical = True
                    reasons.append(f"Available Swap Memory is critically low: {stats.avail_swap_mb:.1f}MB < {self.min_avail_mb:.0f}MB (swap exhaustion causes runner lockup)")
            else:
                # No swap configured: fall back to physical RAM threshold
                if stats.avail_phys_mb > 0 and stats.avail_phys_mb < self.min_avail_mb:
                    is_critical = True
                    reasons.append(f"Available Physical RAM is critically low (no swap configured): {stats.avail_phys_mb:.1f}MB < {self.min_avail_mb:.0f}MB")

            top_procs = get_top_processes(10)
            for p in top_procs:
                self.peak_procs[p.name] = max(self.peak_procs.get(p.name, 0.0), p.rss_mb)

            now = time.time()
            if is_critical:
                self.oom_triggered = True
                alert = (
                    "\n" + "=" * 80 + "\n"
                    "CRITICAL: OUT-OF-MEMORY SAFEGUARD TRIGGERED!\n"
                    f"Reasons: {'; '.join(reasons)}\n"
                    f"System stats: {stats}\n"
                    "Top 10 memory-consuming processes at trigger:\n"
                )
                for p in top_procs:
                    cmd_preview = (p.cmdline[:120] + "...") if len(p.cmdline) > 120 else p.cmdline
                    alert += f"  - PID {p.pid:6d} | {p.name:25s} | {p.rss_mb:8.1f} MB | {cmd_preview}\n"
                alert += "=" * 80 + "\n"

                self.log(alert, console=True)

                if self.report_file:
                    with open(self.report_file, "w", encoding="utf-8") as rf:
                        rf.write("# ⚠️ Build Terminated: Low Memory Safeguard\n\n")
                        rf.write(f"**Timestamp:** {datetime.datetime.now().isoformat()}\n\n")
                        rf.write(f"**Trigger Reason:** {'; '.join(reasons)}\n\n")
                        rf.write(f"**System State at Trigger:** {stats}\n\n")
                        rf.write("### Top Processes at OOM Trigger\n\n")
                        rf.write("| PID | Process | Memory (MB) | Command Line |\n")
                        rf.write("| --- | --- | --- | --- |\n")
                        for p in top_procs:
                            clean_cmd = p.cmdline.replace("|", "\\|").replace("\n", " ")
                            rf.write(f"| {p.pid} | `{p.name}` | {p.rss_mb:.1f} MB | `{clean_cmd}` |\n")

                self.log(f"Auto-killing build target processes to prevent runner system freeze/crash...", console=True)
                kill_target_build_processes(self.monitored_pid)
                break

            # Normal periodic logging
            self.log(f"Status: {stats}")
            # Print to console every 15 seconds or if usage > 60%
            if now - last_console_time > 15.0 or stats.percent_used > 60.0:
                top_summary = ", ".join(f"{p.name}({p.rss_mb:.0f}MB)" for p in top_procs[:3])
                self.log(f"Memory: {stats} | Top: {top_summary}", console=True)
                last_console_time = now

            self.stop_event.wait(self.check_interval_sec)

        self.log("Monitor stopped.")


def write_summary(log_file: Path, summary_file: Path | None, report_file: Path | None) -> None:
    if not summary_file:
        return
    with open(summary_file, "a", encoding="utf-8") as f:
        f.write("## 📊 Build Memory & Resource Monitor\n\n")
        if report_file and report_file.exists():
            f.write(report_file.read_text(encoding="utf-8") + "\n\n")
        else:
            f.write("Build completed without hitting low-memory threshold.\n\n")
        if log_file.exists():
            lines = log_file.read_text(encoding="utf-8").splitlines()
            recent = lines[-25:] if len(lines) > 25 else lines
            f.write("<details><summary>Recent Memory Monitor Logs (click to expand)</summary>\n\n```text\n")
            f.write("\n".join(recent) + "\n```\n</details>\n\n")


def daemon_process_entry(log_file: Path, report_file: Path | None, min_avail_mb: float, interval: float, pid_file: Path) -> None:
    monitor = Monitor(
        log_file=log_file,
        report_file=report_file,
        min_avail_mb=min_avail_mb,
        check_interval_sec=interval,
    )
    # Write daemon PID to pid_file
    pid_file.write_text(str(os.getpid()), encoding="utf-8")

    def handle_signal(sig, frame):
        monitor.stop_event.set()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    monitor.run_loop()
    if pid_file.exists():
        pid_file.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Memory monitor and OOM watchdog.")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # run command
    run_parser = subparsers.add_parser("run", help="Run a command under memory supervision.")
    run_parser.add_argument("--log-file", type=Path, default=Path("build-monitor.log"), help="Log file path")
    run_parser.add_argument("--report-file", type=Path, default=Path("build-oom-report.md"), help="OOM report path")
    run_parser.add_argument("--summary-file", type=Path, default=None, help="GitHub Step Summary path")
    run_parser.add_argument("--min-avail-mb", type=float, default=250.0, help="Minimum free memory (MB)")
    run_parser.add_argument("--interval", type=float, default=0.25, help="Check interval in seconds")
    run_parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to execute")

    # start command (background daemon)
    start_parser = subparsers.add_parser("start", help="Start background memory monitor daemon.")
    start_parser.add_argument("--log-file", type=Path, default=Path("build-monitor.log"), help="Log file path")
    start_parser.add_argument("--report-file", type=Path, default=Path("build-oom-report.md"), help="OOM report path")
    start_parser.add_argument("--pid-file", type=Path, default=Path("build-monitor.pid"), help="PID file path")
    start_parser.add_argument("--min-avail-mb", type=float, default=250.0, help="Minimum free memory (MB)")
    start_parser.add_argument("--interval", type=float, default=0.25, help="Check interval in seconds")

    # _daemon internal command
    daemon_parser = subparsers.add_parser("_daemon", help=argparse.SUPPRESS)
    daemon_parser.add_argument("--log-file", type=Path, required=True)
    daemon_parser.add_argument("--report-file", type=Path, required=True)
    daemon_parser.add_argument("--pid-file", type=Path, required=True)
    daemon_parser.add_argument("--min-avail-mb", type=float, default=250.0)
    daemon_parser.add_argument("--interval", type=float, default=0.25)

    # stop command
    stop_parser = subparsers.add_parser("stop", help="Stop background memory monitor daemon.")
    stop_parser.add_argument("--pid-file", type=Path, default=Path("build-monitor.pid"), help="PID file path")

    # summarize command
    sum_parser = subparsers.add_parser("summarize", help="Write summary markdown")
    sum_parser.add_argument("--log-file", type=Path, default=Path("build-monitor.log"))
    sum_parser.add_argument("--report-file", type=Path, default=Path("build-oom-report.md"))
    sum_parser.add_argument("--summary-file", type=Path, required=True)

    args = parser.parse_args()

    if args.subcommand == "summarize":
        write_summary(args.log_file, args.summary_file, args.report_file)
        return 0

    if args.subcommand == "stop":
        if args.pid_file.exists():
            try:
                pid = int(args.pid_file.read_text(encoding="utf-8").strip())
                if platform.system() == "Windows":
                    subprocess.run(["taskkill", "/F", "/PID", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    os.kill(pid, signal.SIGTERM)
                print(f"[Memory Monitor] Stopped daemon PID {pid}.")
            except Exception as e:
                print(f"[Memory Monitor] Error stopping daemon: {e}", file=sys.stderr)
            args.pid_file.unlink(missing_ok=True)
        return 0

    if args.subcommand == "start":
        is_windows = platform.system() == "Windows"
        # Spawn self as background process
        cmd = [
            sys.executable,
            str(Path(__file__).resolve()),
            "_daemon",
            "--log-file", str(args.log_file.resolve()),
            "--report-file", str(args.report_file.resolve()),
            "--pid-file", str(args.pid_file.resolve()),
            "--min-avail-mb", str(args.min_avail_mb),
            "--interval", str(args.interval),
        ]
        # On Windows, DETACHED_PROCESS (0x00000008) | CREATE_NO_WINDOW (0x08000000) | CREATE_NEW_PROCESS_GROUP (0x00000200)
        flags = (0x00000008 | 0x08000000 | 0x00000200) if is_windows else 0
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            creationflags=flags,
            start_new_session=True if not is_windows else False,
        )
        print(f"[Memory Monitor] Started background watchdog process PID {proc.pid}.")
        return 0

    if args.subcommand == "_daemon":
        # Internal entry point for background daemon
        daemon_process_entry(
            log_file=args.log_file,
            report_file=args.report_file,
            min_avail_mb=args.min_avail_mb,
            interval=args.interval,
            pid_file=args.pid_file,
        )
        return 0

    if args.subcommand == "run":
        cmd = args.command
        if cmd and cmd[0] == "--":
            cmd = cmd[1:]
        if not cmd:
            print("Error: No command specified to run.", file=sys.stderr)
            return 1

        monitor = Monitor(
            log_file=args.log_file,
            min_avail_mb=args.min_avail_mb,
            check_interval_sec=args.interval,
            report_file=args.report_file,
        )

        is_windows = platform.system() == "Windows"
        if len(cmd) == 1 and (" " in cmd[0] or ";" in cmd[0] or "&&" in cmd[0]):
            shell = True
            cmd_to_run = cmd[0]
        else:
            shell = False
            cmd_to_run = cmd

        proc = subprocess.Popen(
            cmd_to_run,
            shell=shell,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if is_windows else 0,
            preexec_fn=os.setsid if not is_windows else None,
        )

        monitor.monitored_pid = proc.pid
        monitor_thread = threading.Thread(target=monitor.run_loop, daemon=True)
        monitor_thread.start()

        rc = proc.wait()
        monitor.stop_event.set()
        monitor_thread.join(timeout=3.0)

        if monitor.oom_triggered:
            print(f"\n[Memory Monitor] Target command was aborted due to critical low memory!", file=sys.stderr)
            if args.summary_file:
                write_summary(args.log_file, args.summary_file, args.report_file)
            return 137

        if args.summary_file:
            write_summary(args.log_file, args.summary_file, args.report_file)

        return rc

    return 0


if __name__ == "__main__":
    sys.exit(main())
