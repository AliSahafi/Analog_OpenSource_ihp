# Analog, Digital, and RF Open-Source IHP Toolchain Setup

<p align="center">
  <img src="./inductor_mesh.png" alt="Inductor Mesh Preview" width="600"/>
</p>

This repository provides an enhanced Dockerfile and post-processing scripts for working with the **IHP SG13G2 open-source 130nm PDK** inside the `iic-osic-tools` environment.

## Overview

Built on top of [IIC-OSIC-TOOLS](https://github.com/iic-jku/iic-osic-tools) (`hpretl/iic-osic-tools:latest`), which already bundles 100+ analog/digital EDA tools (KLayout, OpenROAD, Yosys, Magic, Netgen, LibreLane, and more).

This repo extends the base image with:

| Addition | Purpose |
|----------|---------|
| **EMStudio** (compiled from source) | IHP's Qt5-based EM structure editor — supports openEMS and Palace |
| **setupEM + gds2palace** | Guided GUI for Palace EM simulations; GDS-to-Palace geometry converter |
| **gmsh 4.15.0** (arm64 source build) | 3D mesh generator with OpenCASCADE; pre-installed by base on x86_64 |
| **plot_inductor.py** | S-parameter post-processing and inductor characterisation |
| **verilog2gds** | One-command Verilog → GDS via LibreLane + IHP SG13G2 |
| **vhdl2gds** | One-command VHDL → GDS via LibreLane + IHP SG13G2 |
| **IHP PDK patches** | Corner name fixes, PDN variables, and Tcl script patches for LibreLane 2.x |
| **Shell aliases** | `emstudio`, `inductor`, `pdk-ihp` shortcuts in every terminal |
| **XFCE desktop shortcut** | EMStudio launcher in the Applications menu |

---

## 🚀 Quick Start

### 1. Requirements

- **Docker** (Desktop or Engine) installed and running
- **Docker Compose** (included in Docker Desktop; or `docker compose` plugin)

### 2. Clone & Launch

```bash
git clone https://github.com/AliSahafi/Analog_OpenSource_ihp.git
cd Analog_OpenSource_ihp

# (Optional) copy and edit the configuration file
cp .env.example .env

# Create the local designs folder
mkdir -p designs

# Build the image and start the container
docker compose up -d --build
```

The first build takes ~10–20 min (compiles EMStudio from source).

### 3. Open the Desktop

Navigate to **`http://localhost:8080/vnc.html`** in your browser for the full noVNC desktop.

> VNC client: connect to `localhost:5902`
> Default VNC password: `abc123`

### 4. Your Design Files

Your local `./designs/` folder is mounted inside the container at `/foss/designs` (the default working directory). Anything saved there persists on your host after the container stops.

### 5. Configuration (Optional)

Edit `.env` (copied from `.env.example`) to override defaults:

```ini
NOVNC_PORT=8080      # browser desktop port
VNC_PORT=5902        # VNC client port
DESIGNS=./designs    # host path for design files
PALACE_NP=4          # MPI cores for Palace (default: all cores)
```

### Useful Commands

```bash
docker compose up -d          # start container (uses cached image)
docker compose up -d --build  # rebuild image and start
docker compose down           # stop and remove container
docker compose logs -f        # follow container logs
```

---

## 🧲 RF/EM Flow — EMStudio & Palace

From the XFCE desktop terminal inside the browser:

```bash
EMStudio     # or type: emstudio
setupEM
KLayout.sh   # KLayout with EMStudio driver integrated
```

**First-time EMStudio setup** — open **Setup → Preferences** and set:

| Setting | Value |
|---------|-------|
| EMStudio → `MODEL_TEMPLATES_DIR` | `/opt/emstudio/scripts` |
| OpenEMS → `Python Path` | `/usr/bin/python3` |
| Palace → `PALACE_RUN_MODE` | `Script` |
| Palace → `PALACE_RUN_SCRIPT` | `/opt/emstudio/scripts/run_palace` |

Palace runs with all available CPU cores by default. Override with `PALACE_NP=4` in `.env`.

---

## 📈 Post-Processing S-Parameters

`plot_inductor.py` is available directly inside the container (and in this repo for local use).

```bash
# Inside the container:
inductor <path_to_s2p_file> <path_to_deembedded_s2p_file>

# Example for the 500pH Inductor:
inductor ./inductor_500pH_with_ports.s2p ./inductor_500pH_with_ports_deembedded.s2p
```

Outputs two PNG figures to your working directory:
- `inductor_plot_diff.png` — Differential parameters (L, Q, R)
- `inductor_plot_pi.png` — Pi-model parameters

<p align="center">
  <img src="./Figure_1.png" alt="Plot Result" width="600"/>
</p>

---

## 🔲 Digital Flow — Verilog/VHDL to GDS (IHP SG13G2)

`verilog2gds` and `vhdl2gds` are available globally inside the container. They generate a LibreLane `config.json` for IHP SG13G2 and run the complete RTL-to-GDS flow.

> **⚠️ VHDL Note:** `vhdl2gds` uses Yosys + GHDL plugin. It is intended for **educational use** on simple designs. For production flows, use Verilog.

**Basic usage:**

```bash
verilog2gds counter.v
vhdl2gds spi_master.vhd
```

**Full argument reference:**

```
usage: verilog2gds [-h] [-m MODULE] [-c CLOCK_PORT] [-p CLOCK_PERIOD]
                   [-u UTILIZATION] [-a ASPECT_RATIO]
                   [--die-width DIE_WIDTH] [--die-height DIE_HEIGHT]
                   [--pin-config PIN_CONFIG] [--pdk PDK] [--full-timing]
                   [--extra-libs [...]] [--extra-lefs [...]]
                   [--output-load OUTPUT_LOAD] [--max-fanout MAX_FANOUT]
                   verilog_file

positional arguments:
  verilog_file                    Path to the Verilog source file

optional arguments:
  -h, --help                      Show this help message and exit
  -m, --module MODULE             Top module name (default: filename stem)
  -c, --clock-port CLOCK_PORT     Clock port name (default: clk)
  -p, --clock-period CLOCK_PERIOD Clock period in ns (default: 20 ns = 50 MHz)
  -u, --utilization UTILIZATION   Core utilization % (default: 30)
  -a, --aspect-ratio ASPECT_RATIO Aspect ratio H/W (default: 1.0 = square)
  --die-width DIE_WIDTH           Exact die width in µm — overrides utilization/aspect-ratio
  --die-height DIE_HEIGHT         Exact die height in µm — must pair with --die-width
  --pin-config PIN_CONFIG         Pin order/placement config file (FP_PIN_ORDER_CFG)
  --pdk PDK                       PDK name (default: ihp-sg13g2)
  --full-timing                   Run all 3 timing corners (typ/fast/slow) — slower
  --extra-libs [...]              Extra .lib files to include
  --extra-lefs [...]              Extra .lef files to include
  --output-load OUTPUT_LOAD       Output capacitive load in fF (OUTPUT_CAP_LOAD)
  --max-fanout MAX_FANOUT         Maximum fanout constraint for synthesis
```

> `vhdl2gds` has the same options; use `--entity` instead of `--module`.

**Examples:**

```bash
# Simple run — 50 MHz clock, 30% utilization
verilog2gds counter.v

# 200 MHz clock, compact 50% utilization
verilog2gds my_design.v --utilization 50 --clock-period 5

# Exact die size
verilog2gds my_design.v --die-width 300 --die-height 200

# Full 3-corner timing signoff
verilog2gds my_design.v --utilization 40 --full-timing

# VHDL
vhdl2gds spi_master.vhd --entity spi_master --clock-port clk
```

**Output:** GDS files are written to `./<module>_run/runs/<RUN_DATE>/`

### Example: SPI Master

```bash
verilog2gds spi_master.v --utilization 40 --clock-period 10
```

Results: **227 cells**, Antenna ✅, DRC ✅, LVS ✅, IR drop 0.17%

<p align="center">
  <img src="./spi.png" alt="SPI Master GDS Layout" width="600"/>
</p>

---

## 🙌 Acknowledgments

- **SetupEM & gds2palace**: Developed and maintained by **Volker Muehlhaus** ([GitHub](https://github.com/volkermuehlhaus/setupEM))
- **plot_inductor.py**: Originally authored by **Volker Muehlhaus**
- **Base Docker Image**: **IIC-OSIC-TOOLS** project ([GitHub](https://github.com/iic-jku/iic-osic-tools) | [Docker Hub](https://hub.docker.com/r/hpretl/iic-osic-tools))
