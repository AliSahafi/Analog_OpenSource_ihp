# Analog OpenSource IHP Complementary Setup

This complementary repository provides an enhanced Dockerfile alongside post-processing scripts specifically designed for working with the IHP SG13G2 open-source PDK inside the `iic-osic-tools` environment.

## Overview

This setup is built on top of the excellent base image provided by the [IIC-OSIC-TOOLS project on GitHub](https://github.com/iic-jku/iic-osic-tools) (Docker: `hpretl/iic-osic-tools`), which provides a vast collection of analog and digital EDA tools.

However, for fully simulating and meshing RF structures, this repository extends the environment with additional steps to support [Volker Muehlhaus's setupEM tool](https://github.com/muehlhaus/setupEM) and the `AWS Palace` 3D EM simulator. The included Python plotting script (`plot_inductor.py`) was also originally provided by Volker Muehlhaus.

This repository automatically applies these patches to your local container.

### Included Patches & Additions:
1.  **Gmsh with OpenCASCADE Support**: Compiles `gmsh` 4.15.0 from source natively with `-DENABLE_OCC=1`, enabling 3D boolean operations and geometry processing required by `gds2palace`.
2.  **Volker's setupEM Tool**: Pip installs `setupEM` alongside precisely pinned dependencies (`gds2palace==0.1.19`, `gdspy==1.6.13`).
3.  **IHP EMStudio GUI**: Clones, compiles, and installs the official `IHP-GmbH/EMStudio` repository from source.
4.  **Global Script Execution Fixes**: Exposes `setupEM`, `EMStudio`, and essential post-processing commands right into your system PATH. It additionally patches the `combine_snp` executable from the localized PDK folder to globally run using your active python interpreter.

---

## 🚀 Quick Start Guide

### 1. Requirements

Before starting, ensure you have **Docker Desktop** (or a compatible Docker engine) installed and running on your system.

### 2. Download & Build Container
Clone this repository and build the container locally. You only need to do this once.

```bash
git clone https://github.com/AliSahafi/Analog_OpenSource_ihp.git
cd Analog_OpenSource_ihp
docker build -t opensource_setupem .
```

### 3. Run Container
Launch the built image using the provided `hpretl/iic-osic-tools` wrapper syntax! We launch the GUI into a headless VNC session over port `:80`.

```bash
docker run -d -p 8081:80 -v $(pwd)/inductor_output:/workdir --name analog_sim opensource_setupem
```

For the full desktop experience, navigate to **`http://localhost:8081/vnc.html`** in your web browser.

### 4. Start Simulations!
From the XFCE Desktop Terminal within your browser, you can directly run:

```bash
setupEM
# -> GUI and setup tool for the gds2palace RFIC FEM simulation workflow.

EMStudio
# -> Open-source electromagnetic field simulation software using the FDTD method.

KLayout.sh
# -> Launches KLayout with the EMStudio driver fully integrated!
```

**EMStudio Configuration Setup:**
When launching EMStudio for the first time, open **Setup -> Preferences** and ensure the following paths are configured:

*   **EMStudio -> MODEL_TEMPLATES_DIR:** `/opt/emstudio/scripts`
*   **OpenEMS -> Python Path:** `/usr/bin/python3`
*   **Palace -> PALACE_RUN_MODE:** `Script`
*   **Palace -> PALACE_RUN_SCRIPT:** `/opt/emstudio/scripts/run_palace`

---

## 📈 Post-Processing S-Parameters

Included in this repository is `plot_inductor.py`. When your RF simulation in `palace` finishes, it will generate an output directory (e.g. `palace_model/inductor_output`). 

You can extract that folder and run this script locally using `scikit-rf` to plot your parameters smoothly!

```bash
pip install scikit-rf matplotlib

# Generic usage:
python3 plot_inductor.py <path_to_s2p_file> <path_to_deembedded_s2p_file>

# Example for the 500pH Inductor:
python3 plot_inductor.py ./inductor_500pH_with_ports.s2p ./inductor_500pH_with_ports_deembedded.s2p
```

This will output two graphical figures (defaulting to inductor naming):
-   `inductor_plot_diff.png` (Differential Inductor Parameters - L, Q, R)
-   `inductor_plot_pi.png` (Pi Model Parameters)

---

## 🙌 Acknowledgments

*   **SetupEM & gds2palace**: Developed and maintained by **Volker Muehlhaus**. ([GitHub](https://github.com/muehlhaus/setupEM))
*   **plot_inductor.py**: The plotting script provided in this repository was originally authored by **Volker Muehlhaus**.
*   **Base Docker Image**: The underlying IC design environment is provided by the excellent **IIC-OSIC-TOOLS** project. ([GitHub](https://github.com/iic-jku/iic-osic-tools) | [Docker Hub](https://hub.docker.com/r/hpretl/iic-osic-tools))
