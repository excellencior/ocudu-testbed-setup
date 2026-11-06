FROM ubuntu@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c

# gNB mandatory deps
RUN apt-get update && apt-get install -y \
    cmake \
    make \
    gcc \
    g++ \
    pkg-config \
    libmbedtls-dev \
    libsctp-dev \
    libyaml-cpp-dev \
    libgtest-dev \
    libfftw3-dev \
    sudo \
    curl \
    vim \

# srsUE mandatory deps 
RUN sudo apt-get install -y \
    build-essential \
    cmake \
    libfftw3-dev \
    libmbedtls-dev \
    libboost-program-options-dev \
    libconfig++-dev \
    libsctp-dev \