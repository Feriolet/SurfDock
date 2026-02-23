FROM rapidsai/miniforge-cuda:25.08-cuda12.8.0-base-ubuntu24.04-py3.10@sha256:871560f1d2bc8ba85d1cfe43c97bce786f34bc685b2a9222fe2abd289afd1831

WORKDIR /app

RUN apt-get update && \
    apt-get install --no-install-recommends --yes \
    gcc build-essential git wget tar && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the environment:
COPY environment.yaml .
RUN conda env create -f environment.yaml

RUN echo "conda activate SurfDock" >> ~/.bashrc

WORKDIR "/app/SurfDock/comp_surface/tools"
RUN tar -xzvf  APBS_PDB2PQR.tar.gz
RUN tar -xzvf msms_i86_64Linux2_2.6.1.tar.gz

WORKDIR "/app/SurfDock/"
RUN git clone https://github.com/facebookresearch/esm


ENV KMP_AFFINITY=disabled
CMD [ "/bin/bash" ]
