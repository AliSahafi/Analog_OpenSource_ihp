#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="Run Verilog to GDS using LibreLane via Docker.")
    parser.add_argument("verilog_file", help="Path to the Verilog source file")
    parser.add_argument("--module", "-m", help="Top module name (defaults to verilog filename without extension)")
    parser.add_argument("--clock-port", "-c", default="clk", help="Name of the clock port (default: clk)")
    parser.add_argument("--clock-period", "-p", type=float, default=10.0, help="Clock period in ns (default: 10.0)")
    parser.add_argument("--utilization", "-u", type=float, default=10, help="Core utilization percentage (default: 10)")
    parser.add_argument("--pdk", default="sky130A", help="PDK to use (default: sky130A)")
    parser.add_argument("--container", default="ihp_mixed_signal", help="Docker container name (default: ihp_mixed_signal)")
    
    args = parser.parse_args()

    verilog_path = Path(args.verilog_file).resolve()
    if not verilog_path.exists():
        print(f"Error: Verilog file '{verilog_path}' not found.")
        sys.exit(1)

    top_module = args.module if args.module else verilog_path.stem
    project_dir = verilog_path.parent.resolve()
    run_dir = project_dir / f"{top_module}_run"
    
    # 1. Prepare local run directory
    print(f"[*] Preparing local workspace: {run_dir}")
    os.makedirs(run_dir / "src", exist_ok=True)
    subprocess.run(["cp", str(verilog_path), str(run_dir / "src/")], check=True)

    # 2. Generate config.json
    config = {
        "DESIGN_NAME": top_module,
        "VERILOG_FILES": f"dir::src/{verilog_path.name}",
        "CLOCK_PORT": args.clock_port,
        "CLOCK_PERIOD": args.clock_period,
        "FP_SIZING": "relative",
        "FP_CORE_UTIL": args.utilization,
        "PDK": args.pdk
    }

    config_path = run_dir / "config.json"
    with open(config_path, "w") as f:
        json.dump(config, f, indent=4)
        
    print(f"[*] Generated config.json for {top_module} using {args.pdk} PDK.")

    # 3. Mount/Copy to Docker and Run LibreLane
    container_run_path = f"/tmp/{top_module}_run"
    print(f"[*] Dispatching run to container '{args.container}'...")
    
    try:
        # Create remote dir and copy files
        subprocess.run(["docker", "exec", args.container, "bash", "-c", f"mkdir -p {container_run_path}"], check=True)
        subprocess.run(["docker", "cp", str(run_dir / "src"), f"{args.container}:{container_run_path}/src"], check=True)
        subprocess.run(["docker", "cp", str(config_path), f"{args.container}:{container_run_path}/config.json"], check=True)
        
        # Change permissions to the designer user (UID 1000)
        subprocess.run(["docker", "exec", "-u", "root", args.container, "bash", "-c", f"chown -R 1000:1000 {container_run_path}"], check=True)
        
        # Execute LibreLane as UID 1000
        print("[*] Starting LibreLane synthesis. This will take a few minutes...")
        cmd = f"cd {container_run_path} && rm -rf runs && librelane config.json"
        
        # Stream the output directly to the terminal
        subprocess.run(["docker", "exec", "-u", "1000", args.container, "bash", "-c", cmd], check=True)
        
        # 4. Extract Results
        print("\n[*] LibreLane run completed successfully. Extracting GDS results...")
        subprocess.run(["docker", "cp", f"{args.container}:{container_run_path}/runs", str(run_dir / "runs")], check=True)
        
        print(f"\n[+] Success! Your GDS outputs are available in:\n    {run_dir}/runs/")
        
    except subprocess.CalledProcessError as e:
        print(f"\n[-] Error: Docker execution failed (exit code {e.returncode}). See output above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
