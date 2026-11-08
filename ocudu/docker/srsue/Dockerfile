FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y \
    build-essential \
    cmake \
    libfftw3-dev \
    libmbedtls-dev \
    libboost-program-options-dev \
    libconfig++-dev \
    libsctp-dev \
    libzmq3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srsRAN_4G
COPY srsue/srsRAN_4G/ .

RUN mkdir build && \
    cd build && \
    cmake ../ -DENABLE_ZEROMQ=ON && \
    make -j8 srsue && \
    make install && \
    ldconfig