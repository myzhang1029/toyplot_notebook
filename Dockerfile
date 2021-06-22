# Jupyter notebook using mamba
FROM mambaorg/micromamba:latest

LABEL maintainer="Zhang Maiyun <myzhang1029@hotmail.com>"

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# base-notebook

# Install all OS dependencies for fully functional notebook server
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    tini \
    wget \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    # minimal-notebook
    build-essential \
    vim-tiny \
    git \
    inkscape \
    libsm6 \
    libxext-dev \
    libxrender1 \
    lmodern \
    netcat \
    openssh-client \
    # ---- nbconvert dependencies ----
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic \
    # ----
    tzdata \
    unzip \
    nano-tiny \
    # scipy-notebook
    ffmpeg dvipng cm-super

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    HOME="/home/${NB_USER}" \
    PATH="${CONDA_DIR}/bin:${PATH}" \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER with name ${NB_USER} user with UID=${NB_UID} and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

# Create alternative for nano -> nano-tiny
RUN update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

USER ${NB_UID}

RUN micromamba install -y -n base -c conda-forge \
       # base notebook
       notebook \
       jupyterhub \
       jupyterlab \
       pyopenssl \
       python \
       requests \
       altair \
       beautifulsoup4 \
       bokeh \
       bottleneck \
       cloudpickle \
       cython \
       dask \
       dill \
       h5py \
       ipython \
       ipympl \
       ipywidgets \
       matplotlib-base \
       toyplot \
       numba \
       numexpr \
       pandas \
       patsy \
       protobuf \
       pytables \
       scikit-image \
       scikit-learn \
       scipy \
       seaborn \
       sqlalchemy \
       statsmodels \
       sympy \
       widgetsnbextension \
       xlrd && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

RUN micromamba clean --all --yes

EXPOSE 8888

ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter", "lab"]

COPY jupyter_server_config.py /etc/jupyter/

WORKDIR "${HOME}"
