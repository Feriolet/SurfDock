FROM rapidsai/miniforge-cuda:25.08-cuda12.8.0-base-ubuntu24.04-py3.10@sha256:871560f1d2bc8ba85d1cfe43c97bce786f34bc685b2a9222fe2abd289afd1831

COPY . /app/SurfDock
WORKDIR /app/SurfDock

RUN apt-get update && \
    apt-get install --no-install-recommends --yes \
    gcc build-essential git wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the environment:

RUN conda env create -f environment.yaml

RUN echo "conda activate SurfDock" >> ~/.bashrc

ADD SurfDock/comp_surface/tools/APBS_PDB2PQR.tar.gz /app/SurfDock/SurfDock/comp_surface/tools
ADD SurfDock/comp_surface/tools/msms_i86_64Linux2_2.6.1.tar.gz /app/SurfDock/SurfDock/comp_surface/tools

WORKDIR /app/SurfDock/SurfDock
RUN git clone https://github.com/facebookresearch/esm
ENV precomputed_arrays=/app/SurfDock/precomputed/precomputed_arrays
ENV KMP_AFFINITY=disabled
RUN conda run --no-capture-output -n SurfDock python -c "from utils import so3, torus"

WORKDIR /app/SurfDock

CMD [ "/bin/bash" ]
