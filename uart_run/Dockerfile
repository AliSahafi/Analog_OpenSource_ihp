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
    echo 'set ::env(WELLTAP_CELL) "sg13g2_fill_1"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl && \
    echo 'set ::env(ENDCAP_CELL) "sg13g2_fill_1"' >> /foss/pdks/ihp-sg13g2/libs.tech/librelane/sg13g2_stdcell/config.tcl

# Install the verilog2gds wrapper script for easy Verilog to GDS conversion
COPY verilog2gds /usr/local/bin/verilog2gds
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
