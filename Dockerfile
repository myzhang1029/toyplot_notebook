# JupyterLab image using micromamba
FROM debian:buster-slim

LABEL maintainer="Zhang Maiyun <myzhang1029@hotmail.com>"

ARG NB_USER="mamba"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Install all OS dependencies for fully functional notebook server
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends \
    # base-notebook
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
    ffmpeg dvipng cm-super && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Micromamba
# No need to keep the image small as micromamba does. Jupyter requires
# those packages anyways
ARG TARGETARCH
ARG MAMBA_VERSION="latest"
RUN [ "${TARGETARCH}" = 'arm64' ] && export ARCH='aarch64' || export ARCH='64' && \
    wget -qO - "https://micromamba.snakepit.net/api/micromamba/linux-${ARCH}/${MAMBA_VERSION}" | \
    tar -xj -C / bin/micromamba

ENV SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    ENV_NAME="base" \
    MAMBA_ROOT_PREFIX="/opt/conda" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"
ENV HOME="/home/${NB_USER}" \
    PATH="${MAMBA_ROOT_PREFIX}/bin:${PATH}"

# Make sure when users use the terminal, the locales are reasonable
RUN sed -i.bak -e 's/^# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && \
    locale-gen && \
    update-locale && \
    dpkg-reconfigure --frontend noninteractive locales

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER with name ${NB_USER} user with UID=${NB_UID} and in the 'users' group
# and make sure these dirs are writable by the `users` group.
# Then initialize micromamba
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${HOME}" && \
    /bin/micromamba shell init -s bash -p "${MAMBA_ROOT_PREFIX}" && \
    echo "micromamba activate ${ENV_NAME}" >> "${HOME}/.bashrc" && \
    chown "${NB_USER}:${NB_GID}" "${MAMBA_ROOT_PREFIX}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}" && \
    fix-permissions "${MAMBA_ROOT_PREFIX}"

# Create alternative for nano -> nano-tiny
RUN update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

USER ${NB_UID}

RUN micromamba install -y -n base -c conda-forge \
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
       jupyterhub \
       jupyterlab \
       jupyterlab-git \
       matplotlib-base \
       notebook \
       numba \
       numexpr \
       pandas \
       patsy \
       protobuf \
       pyopenssl \
       pytables \
       python \
       requests \
       scikit-image \
       scikit-learn \
       scipy \
       seaborn \
       sqlalchemy \
       statsmodels \
       sympy \
       toyplot \
       widgetsnbextension \
       xlrd && \
    micromamba clean --all --yes

EXPOSE 8888

ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter", "lab"]

COPY jupyter_server_config.py /etc/jupyter/

WORKDIR "${HOME}"
