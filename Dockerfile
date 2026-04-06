FROM hpretl/iic-osic-tools:latest

# ============================================================================
#  IHP SG13G2 Extended Toolset
#  Adds EMStudio, RF/EM scripts, LibreLane PDK patches, and Verilog/VHDL→GDS
#  wrappers on top of the upstream iic-osic-tools image.
# ============================================================================

USER root
ENV DEBIAN_FRONTEND=noninteractive

# ── 1. System packages ───────────────────────────────────────────────────────
# Qt xcb plugins   → needed by PySide6 / setupEM GUI on the VNC desktop
# Qt5 build tools  → needed to compile EMStudio (Qt5-based; Qt6 port pending)
# FLTK + OCC       → EMStudio build dependencies
# NOTE: verilator, wget, git, cmake, build-essential are already in the base.
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
    libfltk1.3-dev \
    libgl-dev \
    libocct-data-exchange-dev \
    libocct-foundation-dev \
    libocct-modeling-algorithms-dev \
    libocct-modeling-data-dev \
    libocct-ocaf-dev \
    && rm -rf /var/lib/apt/lists/*

# ── 2. EMStudio (IHP GUI for RF/EM structure editing) ────────────────────────
# Cloned and compiled from https://github.com/IHP-GmbH/EMStudio
# Helpers created:
#   run_palace  → wraps Palace 3D EM solver with -np 8
#   combine_snp → wraps IHP's S-parameter combine script
# NOTE: the gds2palace symlink is created in step 10 (after pip install)
#       so the package location is resolved correctly on both x86_64 and arm64.
RUN git clone https://github.com/IHP-GmbH/EMStudio.git /tmp/emstudio && \
    mkdir -p /tmp/emstudio/build && \
    cd /tmp/emstudio/build && \
    qmake ../EMStudio.pro && \
    make -j$(nproc) && \
    mkdir -p /opt/emstudio && \
    cp EMStudio /opt/emstudio/ && \
    cp -R ../scripts /opt/emstudio/ && \
    cp -R ../keywords /opt/emstudio/ && \
    cp -R ../icons /opt/emstudio/ && \
    ln -s /opt/emstudio/EMStudio /usr/local/bin/EMStudio && \
    printf '#!/bin/bash\n/foss/tools/bin/palace -np ${PALACE_NP:-$(nproc)} "$1"\n' \
        > /opt/emstudio/scripts/run_palace && \
    chmod +x /opt/emstudio/scripts/run_palace && \
    printf '#!/bin/bash\npython3 /foss/pdks/ihp-sg13g2/libs.tech/palace/scripts/combine_extend_snp.py\n' \
        > /opt/emstudio/scripts/combine_snp && \
    chmod +x /opt/emstudio/scripts/combine_snp && \
    chmod +x /opt/emstudio/scripts/KLayout.sh && \
    rm -rf /tmp/emstudio

# ── 3. Gmsh 4.15.0 from source (arm64 only) ──────────────────────────────────
# The base image installs gmsh==4.15.0 via pip for x86_64 only.
# On arm64, no pre-built wheel exists so we compile it from source.
RUN if [ "$(arch)" != "x86_64" ]; then \
        wget -q https://gmsh.info/src/gmsh-4.15.0-source.tgz && \
        tar -xzf gmsh-4.15.0-source.tgz && \
        cd gmsh-4.15.0-source && \
        mkdir build && cd build && \
        cmake -DENABLE_BUILD_DYNAMIC=1 -DENABLE_OCC=1 .. && \
        make -j$(nproc) && \
        make install && \
        ln -sf /usr/local/lib/gmsh.py /usr/local/lib/python3.12/dist-packages/gmsh.py && \
        ln -sf /usr/local/lib/libgmsh.so /usr/local/lib/python3.12/dist-packages/libgmsh.so && \
        cd ../.. && rm -rf gmsh-4.15.0-source*; \
    fi

# ── 4. LibreLane IHP SG13G2 PDK compatibility patches ────────────────────────
# Problem 1: wildcard corner names in config.tcl don't match LibreLane 2.x's
#            exact lookup (e.g. "nom_*_typ_1p20V_25C" → "nom_typ_1p20V_25C").
# Problem 2: PDN variables (rail width, pitch, layers, …) are not set for
#            sg13g2_stdcell in the shipped PDK config.
# Problem 3: IHP SG13G2 has no WELLTAP/ENDCAP cells; the PDK config must
#            declare them as empty so LibreLane skips tapcell insertion.
RUN sed -i \
        's/"nom_\*_typ_1p20V_25C"/"nom_typ_1p20V_25C"/g; \
         s/"nom_\*_fast_1p32V_m40C"/"nom_fast_1p32V_m40C"/g; \
         s/"nom_\*_slow_1p08V_125C"/"nom_slow_1p08V_125C"/g' \
        /foss/pdks/ihp-sg13g2/libs.tech/librelane/config.tcl 2>/dev/null || true && \
    { \
        echo ""; \
        echo "# --- Added for LibreLane 2.x compatibility ---"; \
        echo 'set ::env(FP_PDN_RAIL_OFFSET) 0'; \
        echo 'set ::env(FP_PDN_VWIDTH) 2.2'; \
        echo 'set ::env(FP_PDN_VSPACING) 4.0'; \
        echo 'set ::env(FP_PDN_VPITCH) 75.6'; \
        echo 'set ::env(FP_PDN_VOFFSET) 13.6'; \
        echo 'set ::env(FP_PDN_HWIDTH) 2.2'; \
        echo 'set ::env(FP_PDN_HSPACING) 4.0'; \
        echo 'set ::env(FP_PDN_HPITCH) 75.6'; \
        echo 'set ::env(FP_PDN_HOFFSET) 13.6'; \
        echo 'set ::env(FP_PDN_CORE_RING_VWIDTH) 5.0'; \
        echo 'set ::env(FP_PDN_CORE_RING_HWIDTH) 5.0'; \
        echo 'set ::env(FP_PDN_CORE_RING_VSPACING) 2.0'; \
        echo 'set ::env(FP_PDN_CORE_RING_HSPACING) 2.0'; \
        echo 'set ::env(FP_PDN_CORE_RING_VOFFSET) 4.5'; \
        echo 'set ::env(FP_PDN_CORE_RING_HOFFSET) 4.5'; \
        echo 'set ::env(FP_PDN_RAIL_LAYER) "Metal1"'; \
        echo 'set ::env(FP_PDN_RAIL_WIDTH) 0.44'; \
        echo 'set ::env(FP_PDN_HORIZONTAL_LAYER) "TopMetal2"'; \
        echo 'set ::env(FP_PDN_VERTICAL_LAYER) "TopMetal1"'; \
        echo 'set ::env(FILL_CELL) "sg13g2_fill_1 sg13g2_fill_2"'; \
        echo 'set ::env(DECAP_CELL) "sg13g2_decap_*"'; \
        echo 'set ::env(FP_TAPCELL_DIST) 0'; \
        echo 'set ::env(WELLTAP_CELL) ""'; \
        echo 'set ::env(ENDCAP_CELL) ""'; \
    } >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl

# ── 5. LibreLane Tcl script patches ──────────────────────────────────────────
# cut_rows.tcl  → skip -endcap_master when ENDCAP_CELL is empty
# tapcell.tcl   → skip tapcell insertion entirely when WELLTAP_CELL is empty
#                 or FP_TAPCELL_DIST=0 (both true for IHP SG13G2)
RUN printf '%s\n' \
        'source $::env(SCRIPTS_DIR)/openroad/common/io.tcl' \
        'read_current_odb' \
        'if { [info exists ::env(ENDCAP_CELL)] && $::env(ENDCAP_CELL) ne "" } {' \
        '    cut_rows -endcap_master $::env(ENDCAP_CELL) \' \
        '        -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) \' \
        '        -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)' \
        '} else {' \
        '    cut_rows -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) \' \
        '        -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)' \
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
        '    set args [list -distance $::env(FP_TAPCELL_DIST) \' \
        '        -tapcell_master "$welltap" \' \
        '        -halo_width_x $::env(FP_MACRO_HORIZONTAL_HALO) \' \
        '        -halo_width_y $::env(FP_MACRO_VERTICAL_HALO)]' \
        '    if { $endcap ne "" } { lappend args -endcap_master "$endcap" }' \
        '    tapcell {*}$args' \
        '} else {' \
        '    puts {Skipping tapcell insertion: WELLTAP_CELL empty or FP_TAPCELL_DIST=0}' \
        '}' \
        'write_views' \
        'report_design_area_metrics' \
        > /usr/local/lib/python3.12/dist-packages/librelane/scripts/openroad/tapcell.tcl

# ── 6. KLayout symlink for LibreLane XOR signoff ─────────────────────────────
# LibreLane calls "klayout" directly; the binary lives under /foss/tools/klayout/
RUN ln -sf /foss/tools/klayout/klayout /usr/local/bin/klayout

# ── 7. Wrapper scripts ────────────────────────────────────────────────────────
# verilog2gds   → Verilog→GDS via LibreLane + IHP SG13G2 (Python CLI)
# vhdl2gds      → VHDL→GDS via LibreLane + IHP SG13G2 (Python CLI)
# plot_inductor → S-parameter analysis & inductor characterisation (Python CLI)
COPY verilog2gds       /usr/local/bin/verilog2gds
COPY vhdl2gds          /usr/local/bin/vhdl2gds
COPY plot_inductor.py  /usr/local/bin/plot_inductor.py
RUN chmod +x /usr/local/bin/verilog2gds \
             /usr/local/bin/vhdl2gds \
             /usr/local/bin/plot_inductor.py

# ── 8. Desktop shortcuts ──────────────────────────────────────────────────────
# EMStudio launcher → visible in the XFCE Applications menu inside VNC
COPY EMStudio.desktop /usr/share/applications/EMStudio.desktop
RUN chmod 644 /usr/share/applications/EMStudio.desktop && \
    update-desktop-database /usr/share/applications/ 2>/dev/null || true

# ── 9. Python packages (as root — uses --break-system-packages → system Python) ─
# PySide6      → setupEM GUI (Qt6 Python bindings)
# scipy        → setupEM numerical backend
# requests     → setupEM HTTP client
# gdspy        → already in base but pinned here to ensure the correct version
# --break-system-packages is required on Ubuntu 24.04 (PEP 668)
# --ignore-installed silently skips packages already at the right version
# On x86_64: gds2palace & setupEM are pre-installed in the base image; skip.
# On arm64:  install them with --no-deps (gmsh was compiled from source above).
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed \
        PySide6 scipy requests "gdspy==1.6.13" && \
    if [ "$(arch)" != "x86_64" ]; then \
        pip3 install --no-cache-dir --break-system-packages --no-deps \
            "gds2palace==0.1.19" setupEM; \
    fi

# ── 10. gds2palace symlink for EMStudio ───────────────────────────────────────
# Resolved dynamically so the path is correct on both x86_64 and arm64.
# Must run as root because /opt/emstudio/scripts/ is owned by root.
RUN ln -sf \
    "$(python3 -c 'import gds2palace, os; print(os.path.dirname(gds2palace.__file__))')" \
    /opt/emstudio/scripts/gds2palace

# ── 11. Shell aliases ─────────────────────────────────────────────────────────
# Convenience shortcuts available in every terminal session inside the container.
RUN printf '\n# IHP SG13G2 shortcuts\nalias inductor="python3 /usr/local/bin/plot_inductor.py"\nalias emstudio="EMStudio"\nalias pdk-ihp="sak-pdk ihp-sg13g2"\n' \
    >> /headless/.bashrc

# ── 12. Switch back to the container user ─────────────────────────────────────
USER 1000

# ── 13. PATH & working directory ──────────────────────────────────────────────
ENV PATH="/opt/emstudio/scripts:/foss/pdks/ihp-sg13g2/libs.tech/palace/scripts:/foss/tools/bin:/foss/tools/klayout:/headless/.local/bin:${PATH}"

WORKDIR /foss/designs

# ── Uncomment to set a custom desktop background ──────────────────────────────
# USER root
# COPY desktop_background.png /headless/.config/background.png
# COPY xfce4-desktop.xml /headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
# RUN chown 1000:1000 /headless/.config/background.png \
#     /headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
# USER 1000
