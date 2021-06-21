# vi: filetype=Dockerfile
# Distributed under the terms of the Modified BSD License.

ARG BASE_CONTAINER=jupyter/tensorflow-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Zhang Maiyun <myzhang1029@hotmail.com>"

RUN pip install toyplot
