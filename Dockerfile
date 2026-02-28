FROM hpretl/iic-osic-tools:2026.02

# The base image (iic-osic-tools) runs as user 1000. Switch to root for system installations.
USER root

# Avoid interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive

# SetupEM UI Dependencies: Qt xcb platform plugins
# EMStudio Dependencies: Qt5 build tools and Git
# LibreLane Dependencies: Verilator
RUN apt-get update && apt-get install -y \
    libxcb-cursor0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-render0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xinput0 \
    libxcb-xv0 \
    libxcb-util1 \
    libxkbcommon-x11-0 \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    build-essential \
    cmake \
    libfltk1.3-dev \
    libgl-dev \
    libocct-data-exchange-dev \
    libocct-foundation-dev \
    libocct-modeling-algorithms-dev \
    libocct-modeling-data-dev \
    libocct-ocaf-dev \
    wget \
    git \
    verilator \
    && rm -rf /var/lib/apt/lists/*

# Clone and build EMStudio from source
RUN git clone https://github.com/IHP-GmbH/EMStudio.git /tmp/emstudio && \
    mkdir -p /tmp/emstudio/build && \
    cd /tmp/emstudio/build && \
    qmake ../EMStudio.pro && \
    make -j2 && \
    mkdir -p /opt/emstudio && \
    cp EMStudio /opt/emstudio/ && \
    cp -R ../scripts /opt/emstudio/ && \
    cp -R ../keywords /opt/emstudio/ && \
    cp -R ../icons /opt/emstudio/ && \
    ln -s /opt/emstudio/EMStudio /usr/local/bin/EMStudio && \
    ln -s /headless/.local/lib/python3.12/site-packages/gds2palace /opt/emstudio/scripts/gds2palace && \
    echo '#!/bin/bash\n/foss/tools/bin/palace -np 8 "$1"' > /opt/emstudio/scripts/run_palace && \
    chmod +x /opt/emstudio/scripts/run_palace && \
    echo '#!/bin/bash\npython3 /foss/pdks/ihp-sg13g2/libs.tech/palace/scripts/combine_extend_snp.py' > /opt/emstudio/scripts/combine_snp && \
    chmod +x /opt/emstudio/scripts/combine_snp && \
    chmod +x /opt/emstudio/scripts/KLayout.sh && \
    rm -rf /tmp/emstudio

# Compile and install gmsh 4.15.0 from source for arm64/aarch64 support
RUN wget https://gmsh.info/src/gmsh-4.15.0-source.tgz && \
    tar -xzf gmsh-4.15.0-source.tgz && \
    cd gmsh-4.15.0-source && \
    mkdir build && cd build && \
    cmake -DENABLE_BUILD_DYNAMIC=1 -DENABLE_OCC=1 .. && \
    make -j2 && \
    make install && \
    ln -s /usr/local/lib/gmsh.py /usr/local/lib/python3.12/dist-packages/gmsh.py && \
    ln -s /usr/local/lib/libgmsh.so /usr/local/lib/python3.12/dist-packages/libgmsh.so && \
    cd .. && \
    rm -rf gmsh-4.15.0-source*

# Patch IHP sg13g2 PDK config for LibreLane 2.x compatibility
# The wildcard LIB/TECH_LEFS dict keys in the PDK's config.tcl don't match
# LibreLane's exact corner-name lookup, so we patch them to use explicit names.
RUN sed -i 's/"nom_\*_typ_1p20V_25C"/"nom_typ_1p20V_25C"/g; s/"nom_\*_fast_1p32V_m40C"/"nom_fast_1p32V_m40C"/g; s/"nom_\*_slow_1p08V_125C"/"nom_slow_1p08V_125C"/g' \
    /foss/pdks/ihp-sg13g2/libs.tech/librelane/config.tcl 2>/dev/null || true && \
    echo "" >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo "# --- Added for LibreLane 2.x compatibility ---" >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_RAIL_OFFSET) 0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_VWIDTH) 2.2' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_VSPACING) 4.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_VPITCH) 75.6' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_VOFFSET) 13.6' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_HWIDTH) 2.2' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_HSPACING) 4.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_HPITCH) 75.6' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_HOFFSET) 13.6' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_VWIDTH) 5.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_HWIDTH) 5.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_VSPACING) 2.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_HSPACING) 2.0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_VOFFSET) 4.5' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_CORE_RING_HOFFSET) 4.5' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_RAIL_LAYER) "Metal1"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_RAIL_WIDTH) 0.44' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_HORIZONTAL_LAYER) "TopMetal2"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_PDN_VERTICAL_LAYER) "TopMetal1"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FILL_CELL) "sg13g2_fill_1 sg13g2_fill_2"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(DECAP_CELL) "sg13g2_decap_*"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(FP_TAPCELL_DIST) 0' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(WELLTAP_CELL) ""' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(ENDCAP_CELL) ""' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl

# Patch LibreLane's cut_rows.tcl and tapcell.tcl to handle empty WELLTAP/ENDCAP cells
# (IHP SG13G2 has no tapcells — scripts must skip gracefully when cells are empty)
RUN printf '%s\n' \
    'source $::env(SCRIPTS_DIR)/openroad/common/io.tcl' \
    'read_current_odb' \
    'if { [info exists ::env(ENDCAP_CELL)] && $::env(ENDCAP_CELL) ne "" } {' \
    '    cut_rows -endcap_master $::env(ENDCAP_CELL) -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)' \
    '} else {' \
    '    cut_rows -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)' \
    '}' \
    'write_views' \
    'report_design_area_metrics' \
    > /usr/local/lib/python3.12/dist-packages/librelane/scripts/openroad/cut_rows.tcl && \
    printf '%s\n' \
    'source $::env(SCRIPTS_DIR)/openroad/common/io.tcl' \
    'read_current_odb' \
    'set welltap [expr { [info exists ::env(WELLTAP_CELL)] ? $::env(WELLTAP_CELL) : "" }]' \
    'set endcap  [expr { [info exists ::env(ENDCAP_CELL)]  ? $::env(ENDCAP_CELL)  : "" }]' \
    'if { $welltap ne "" && $::env(FP_TAPCELL_DIST) != 0 } {' \
    '    set args [list -distance $::env(FP_TAPCELL_DIST) -tapcell_master "$welltap" -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)]' \
    '    if { $endcap ne "" } { lappend args -endcap_master "$endcap" }' \
    '    tapcell {*}$args' \
    '} else {' \
    '    puts "[INFO] Skipping tapcell insertion (WELLTAP_CELL empty or FP_TAPCELL_DIST=0)"' \
    '}' \
    'write_views' \
    'report_design_area_metrics' \
    > /usr/local/lib/python3.12/dist-packages/librelane/scripts/openroad/tapcell.tcl

# Make KLayout available to LibreLane's XOR signoff step
RUN ln -sf /foss/tools/klayout/klayout /usr/local/bin/klayout

# Install the verilog2gds wrapper script (inlined — no external file needed)
RUN cat > /usr/local/bin/verilog2gds << 'SCRIPT'
#!/usr/bin/env python3
import os, sys, json, argparse, subprocess
from pathlib import Path

def main():
parser = argparse.ArgumentParser(description="Run Verilog to GDS using LibreLane.")
parser.add_argument("verilog_file")
parser.add_argument("--module", "-m")
parser.add_argument("--clock-port", "-c", default="clk")
parser.add_argument("--clock-period", "-p", type=float, default=10.0)
parser.add_argument("--utilization", "-u", type=float, default=10)
parser.add_argument("--pdk", default="ihp-sg13g2")
parser.add_argument("--full-timing", action="store_true")
args = parser.parse_args()

verilog_path = Path(args.verilog_file).resolve()
if not verilog_path.exists():
print(f"Error: '{verilog_path}' not found."); sys.exit(1)

top_module = args.module or verilog_path.stem
run_dir = verilog_path.parent.resolve() / f"{top_module}_run"
print(f"[*] Preparing workspace: {run_dir}")
os.makedirs(run_dir / "src", exist_ok=True)
subprocess.run(["cp", str(verilog_path), str(run_dir / "src/")], check=True)

config = {
"DESIGN_NAME": top_module,
"VERILOG_FILES": f"dir::src/{verilog_path.name}",
"CLOCK_PORT": args.clock_port,
"CLOCK_PERIOD": args.clock_period,
"FP_SIZING": "relative",
"FP_CORE_UTIL": args.utilization,
"PDK": args.pdk
}

if args.pdk == "sky130A":
config["STD_CELL_LIBRARY"] = "sky130_fd_sc_hd"
elif args.pdk == "ihp-sg13g2":
config["STD_CELL_LIBRARY"] = "sg13g2_stdcell"
config["FILL_CELL"] = "sg13g2_fill_1 sg13g2_fill_2"
config["DECAP_CELL"] = "sg13g2_decap_*"
config["FP_TAPCELL_DIST"] = 0
config["WELLTAP_CELL"] = ""
config["ENDCAP_CELL"] = ""
config["FP_PDN_RAIL_OFFSET"] = 0
config["FP_PDN_VWIDTH"] = 2.2; config["FP_PDN_VSPACING"] = 4.0
config["FP_PDN_VPITCH"] = 75.6; config["FP_PDN_VOFFSET"] = 13.6
config["FP_PDN_HWIDTH"] = 2.2; config["FP_PDN_HSPACING"] = 4.0
config["FP_PDN_HPITCH"] = 75.6; config["FP_PDN_HOFFSET"] = 13.6
config["FP_PDN_CORE_RING_VWIDTH"] = 5.0; config["FP_PDN_CORE_RING_HWIDTH"] = 5.0
config["FP_PDN_CORE_RING_VSPACING"] = 2.0; config["FP_PDN_CORE_RING_HSPACING"] = 2.0
config["FP_PDN_CORE_RING_VOFFSET"] = 4.5; config["FP_PDN_CORE_RING_HOFFSET"] = 4.5
config["FP_PDN_RAIL_LAYER"] = "Metal1"; config["FP_PDN_RAIL_WIDTH"] = 0.44
config["FP_PDN_HORIZONTAL_LAYER"] = "TopMetal2"
config["FP_PDN_VERTICAL_LAYER"] = "TopMetal1"
if args.full_timing:
config["STA_CORNERS"] = ["nom_typ_1p20V_25C","nom_fast_1p32V_m40C","nom_slow_1p08V_125C"]
config["LIB"] = {
"nom_typ_1p20V_25C": ["/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"],
"nom_fast_1p32V_m40C": ["/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_fast_1p32V_m40C.lib"],
"nom_slow_1p08V_125C": ["/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_slow_1p08V_125C.lib"]
}
else:
config["STA_CORNERS"] = ["nom_typ_1p20V_25C"]
config["DEFAULT_CORNER"] = "nom_typ_1p20V_25C"
config["LIB"] = {"nom_typ_1p20V_25C": ["/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"]}
config["TECH_LEFS"] = {"nom_typ_1p20V_25C": "/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef"}
config["RCX_RULESETS"] = {"nom_typ_1p20V_25C": "/foss/pdks/ihp-sg13g2/libs.tech/librelane/openrcx/ihp-sg13g2.nom.magic.rules"}
if args.full_timing:
for c in ["nom_fast_1p32V_m40C","nom_slow_1p08V_125C"]:
config["TECH_LEFS"][c] = "/foss/pdks/ihp-sg13g2/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef"
config["RCX_RULESETS"][c] = "/foss/pdks/ihp-sg13g2/libs.tech/librelane/openrcx/ihp-sg13g2.nom.magic.rules"

with open(run_dir / "config.json", "w") as f:
json.dump(config, f, indent=4)
print(f"[*] Generated config.json for {top_module} using {args.pdk} PDK.")

env = os.environ.copy()
env.pop("STD_CELL_LIBRARY", None); env.pop("PDK", None)
print(f"[*] Starting LibreLane synthesis...")
try:
subprocess.run(f"cd {run_dir} && rm -rf runs && librelane config.json",
shell=True, check=True, env=env)
print(f"\n[+] Success! Your GDS outputs are available in:\n    {run_dir}/runs/")
except subprocess.CalledProcessError as e:
print(f"\n[-] Error: LibreLane failed (exit code {e.returncode})."); sys.exit(1)

if __name__ == "__main__":
main()
SCRIPT
RUN chmod +x /usr/local/bin/verilog2gds

# Switch back to the base container user id
USER 1000

# Install setupEM along with its python dependencies
# Since we manually built gmsh, we need to bypass pip's strict dependency check
RUN pip3 install --no-cache-dir PySide6 scipy requests gdspy==1.6.13 && \
    pip3 install --no-cache-dir --no-deps gds2palace==0.1.19 setupEM

# Ensure pip3 installs and emstudio scripts are in the system PATH
# Also ensure EDA tools / LibreLane are in PATH
ENV PATH="/opt/emstudio/scripts:/foss/pdks/ihp-sg13g2/libs.tech/palace/scripts:/foss/tools/bin:/foss/tools/klayout:/headless/.local/bin:${PATH}"

# Set default working directory
WORKDIR /design
