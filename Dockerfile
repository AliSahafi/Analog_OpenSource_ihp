FROM hpretl/iic-osic-tools:latest

# ============================================================================
#  IHP SG13G2 Extended Toolset
#  Adds EMStudio, RF/EM scripts, LibreLane PDK patches, and Verilog/VHDL→GDS
#  wrappers on top of the upstream iic-osic-tools image.
#  Compatible with: hpretl/iic-osic-tools:latest (Ubuntu 24.04, Python 3.12,
#                   LibreLane 3.x, gds2palace 0.3.x, setupEM 0.1.x)
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
# NOTE: the gds2palace symlink is created in step 9 (already in base image).
# NOTE: On Ubuntu 24.04, qt5-qmake installs the binary at /usr/lib/qt5/bin/qmake.
RUN git clone https://github.com/IHP-GmbH/EMStudio.git /tmp/emstudio && \
    mkdir -p /tmp/emstudio/build && \
    cd /tmp/emstudio/build && \
    /usr/lib/qt5/bin/qmake ../EMStudio.pro && \
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

# ── 3. Gmsh (arm64 note) ─────────────────────────────────────────────────────
# The base image now ships a working gmsh build on both x86_64 and arm64
# (via a custom dev wheel packaged by iic-osic-tools). No source compilation
# is needed. If you ever need to override the version, uncomment and adapt:
#
# RUN if [ "$(arch)" != "x86_64" ]; then \
#         pip3 install --no-cache-dir --break-system-packages gmsh==<version>; \
#     fi


# ── 4. LibreLane IHP SG13G2 PDK compatibility patches ────────────────────────
# The PDK's config.tcl corner names are already explicit in recent iic-osic-tools
# images (nom_typ_1p20V_25C, etc.), so the sed below is a safe no-op.
# The sg13g2_stdcell config is still missing PDN variables and cell declarations
# needed by LibreLane 3.x; we append them here.
# IHP SG13G2 has no WELLTAP/ENDCAP cells — LibreLane 3.x's tapcell.tcl and
# cut_rows.tcl already handle empty strings gracefully via append_if_exists_argument.
RUN sed -i \
        's/"nom_\*_typ_1p20V_25C"/"nom_typ_1p20V_25C"/g; \
         s/"nom_\*_fast_1p32V_m40C"/"nom_fast_1p32V_m40C"/g; \
         s/"nom_\*_slow_1p08V_125C"/"nom_slow_1p08V_125C"/g' \
        /foss/pdks/ihp-sg13g2/libs.tech/librelane/config.tcl 2>/dev/null || true && \
    { \
        echo ""; \
        echo "# --- Added for LibreLane 3.x compatibility ---"; \
        echo 'set ::env(PDN_RAIL_OFFSET) 0'; \
        echo 'set ::env(PDN_VWIDTH) 2.2'; \
        echo 'set ::env(PDN_VSPACING) 4.0'; \
        echo 'set ::env(PDN_VPITCH) 75.6'; \
        echo 'set ::env(PDN_VOFFSET) 13.6'; \
        echo 'set ::env(PDN_HWIDTH) 2.2'; \
        echo 'set ::env(PDN_HSPACING) 4.0'; \
        echo 'set ::env(PDN_HPITCH) 75.6'; \
        echo 'set ::env(PDN_HOFFSET) 13.6'; \
        echo 'set ::env(PDN_CORE_RING_VWIDTH) 5.0'; \
        echo 'set ::env(PDN_CORE_RING_HWIDTH) 5.0'; \
        echo 'set ::env(PDN_CORE_RING_VSPACING) 2.0'; \
        echo 'set ::env(PDN_CORE_RING_HSPACING) 2.0'; \
        echo 'set ::env(PDN_CORE_RING_VOFFSET) 4.5'; \
        echo 'set ::env(PDN_CORE_RING_HOFFSET) 4.5'; \
        echo 'set ::env(PDN_RAIL_LAYER) "Metal1"'; \
        echo 'set ::env(PDN_RAIL_WIDTH) 0.44'; \
        echo 'set ::env(PDN_HORIZONTAL_LAYER) "TopMetal2"'; \
        echo 'set ::env(PDN_VERTICAL_LAYER) "TopMetal1"'; \
        echo 'set ::env(FILL_CELL) "sg13g2_fill_1 sg13g2_fill_2"'; \
        echo 'set ::env(DECAP_CELL) "sg13g2_decap_*"'; \
    } >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    sed -i 's/set ::env(PAD_BONDPAD_NAME)/#set ::env(PAD_BONDPAD_NAME)/g' \
        /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_io/config.tcl 2>/dev/null || true && \
    echo 'set ::env(PAD_PLACE_IO_TERMINALS) "sg13g2_IOPad*/pad"' \
        >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_io/config.tcl && \
    sed -i 's/if {\$master_name == \$check_master_name}/if {[string match \$check_master_name \$master_name]}/g' \
        /usr/local/lib/python3.12/dist-packages/librelane/scripts/openroad/common/pad_cfg.tcl 2>/dev/null || true

# ── 5. LibreLane Tcl script patches ──────────────────────────────────────────
# Standard patches applied above; LibreLane 3.x is fully enabled.


# ── 6. KLayout symlink for LibreLane XOR signoff ─────────────────────────────
# LibreLane calls "klayout" directly; the binary lives under /foss/tools/klayout/
RUN ln -sf /foss/tools/klayout/klayout /usr/local/bin/klayout

# ── 7. Wrapper scripts ────────────────────────────────────────────────────────
# verilog2gds   → Verilog→GDS via LibreLane + IHP SG13G2 (Python CLI)
# vhdl2gds      → VHDL→GDS via LibreLane + IHP SG13G2 (Python CLI)
# padgen        → IHP SG13G2 pad ring generator (Chip-flow project scaffold)
# plot_inductor → S-parameter analysis & inductor characterisation (Python CLI)
COPY verilog2gds       /usr/local/bin/verilog2gds
COPY vhdl2gds          /usr/local/bin/vhdl2gds
COPY padgen            /usr/local/bin/padgen
COPY plot_inductor.py  /usr/local/bin/plot_inductor.py
RUN chmod +x /usr/local/bin/verilog2gds \
             /usr/local/bin/vhdl2gds \
             /usr/local/bin/padgen \
             /usr/local/bin/plot_inductor.py

# ── 8. Desktop shortcuts & default terminal ──────────────────────────────────
# EMStudio launcher → visible in the XFCE Applications menu inside VNC
COPY EMStudio.desktop /usr/share/applications/EMStudio.desktop
RUN chmod 644 /usr/share/applications/EMStudio.desktop && \
    update-desktop-database /usr/share/applications/ 2>/dev/null || true && \
    update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper 2>/dev/null || true

# ── 9. Python packages ────────────────────────────────────────────────────────
# All required Python packages are pre-installed in the base image on both
# x86_64 and arm64:
#   PySide6 6.x     → setupEM GUI (Qt6 Python bindings)
#   scipy            → setupEM numerical backend
#   requests         → setupEM HTTP client
#   gdspy 1.6.13     → GDS manipulation
#   gds2palace 0.3.x → GDS → Palace workflow
#   setupEM 0.1.x    → EM setup tool
#   gmsh             → custom dev build (works on both arches)
#
# No pip install is required here. If you need a different version, use:
#   RUN pip3 install --no-cache-dir --break-system-packages <package>==<ver>


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

# ── 14. Flat desktop background ──────────────────────────────────────────────
USER root
COPY desktop_background.png /headless/.config/background.png
COPY xfce4-desktop.xml /headless/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
RUN mkdir -p /headless/.config/xfce4/xfconf/xfce-perchannel-xml && \
    chown -R 1000:1000 /headless/.config/background.png \
                       /headless/.config/xfce4/
USER 1000

