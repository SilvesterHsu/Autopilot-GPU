FROM nvidia/cuda:11.4.2-cudnn8-devel-ubuntu20.04 as build

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && \
    apt install autoconf automake libtool curl wget make cmake g++ unzip git -y && \
    rm -rf /var/lib/apt/lists/*

# Protobuf
ENV PROTOBUF 3.7.0
ENV PROTOBUF_URL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF}/protobuf-all-${PROTOBUF}.zip

RUN cd /opt && \
    wget "${PROTOBUF_URL}" -O protobuf.zip && \
    unzip protobuf.zip && \
    cd protobuf* && \
    ./autogen.sh && \
    ./configure  --prefix=/usr/local && \
    make -j 15 && \
    make install && \
    ldconfig

# Gtest
ENV GTEST 1.10.0
ENV GTEST_URL https://github.com/google/googletest/archive/refs/tags/release-${GTEST}.zip

RUN cd /opt && \
    wget "${GTEST_URL}" -O gtest.zip && \
    unzip gtest.zip && \
    cd googletest-release-${GTEST} && \
    cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr/local/ . && \
    make -j 15 && \
    cp -r googletest/include/gtest /usr/local/include && \
    cp lib/*.so /usr/local/lib

# OPENCV
ENV OPENCV 4.5.4
ENV OPENCV_URL https://github.com/opencv/opencv/archive/refs/tags/${OPENCV}.zip
ENV OPENCV_CONTRIB_URL https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV}.zip

RUN cd /opt && \
    wget "${OPENCV_CONTRIB_URL}" -O opencv_contrib.zip && \
    unzip opencv_contrib.zip && \
    wget "${OPENCV_URL}" -O opencv.zip && \
    unzip opencv.zip && \
    mkdir -p opencv-${OPENCV}/build && cd opencv-${OPENCV}/build && \
    cmake -D CMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs \
          -D BUILD_OPENEXR=OFF WITH_OPENEXR=OFF \
          -D WITH_CUDA=ON \
          -D ENABLE_PRECOMPILED_HEADERS=OFF \
          -D CUDA_ARCH_BIN="6.1" \
          -D CUDA_ARCH_PTX="" \
          -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-${OPENCV}/modules \
          -D WITH_GSTREAMER=ON \
          -D WITH_LIBV4L=ON \
          -D BUILD_opencv_python2=ON \
          -D BUILD_opencv_python3=ON \
          -D BUILD_TESTS=OFF \
          -D BUILD_PERF_TESTS=OFF \
          -D BUILD_EXAMPLES=OFF \
          -D CMAKE_BUILD_TYPE=RELEASE \
          -D CMAKE_INSTALL_PREFIX=/usr/local/ .. && \
    make -j15 && \
    make install

# EIGEN
ENV EIGEN 3.3.9
ENV EIGEN_URL https://gitlab.com/libeigen/eigen/-/archive/${EIGEN}/eigen-${EIGEN}.zip

RUN cd /opt && \
    wget "${EIGEN_URL}" -O eigen-${EIGEN}.zip && \
    unzip eigen-${EIGEN}.zip && \
    mkdir -p eigen-${EIGEN}/build && cd eigen-${EIGEN}/build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/ .. && \
    make -j 15 install 

# FLANN
ENV FLANN 1.9.1
ENV FLANN_URL https://github.com/flann-lib/flann/archive/refs/tags/${FLANN}.zip

RUN cd /opt && \
    wget "${FLANN_URL}" -O flann-${FLANN}.zip && \
    unzip flann-${FLANN}.zip && \
    mkdir -p flann-${FLANN}/build && cd flann-${FLANN} && \
    touch src/cpp/empty.cpp && \
    sed -e '/add_library(flann_cpp SHARED/ s/""/empty.cpp/' \
        -e '/add_library(flann SHARED/ s/""/empty.cpp/' \
        -i src/cpp/CMakeLists.txt && \
    cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/ \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_TESTS=OFF \
      -DBUILD_PYTHON_BINDINGS=OFF \
      -DBUILD_MATLAB_BINDINGS=OFF \
      .. && \
    make -j 15 && \
    make -j 15 install

# BOOST
ENV BOOST 1.71.0
ENV BOOST_URL https://github.com/boostorg/boost.git

RUN cd /opt && \
    git clone -b boost-${BOOST} --recursive ${BOOST_URL} && \
    cd boost && \
    ./bootstrap.sh && \
    ./b2 install --prefix=/usr/local/ --exec-prefix=/usr/local/ --with-test && \
    ./b2 install --prefix=/usr/local/ --exec-prefix=/usr/local/ link=shared runtime-link=shared threading=multi

# PCL
ENV PCL 1.11.0
ENV PCL_URL https://github.com/PointCloudLibrary/pcl/archive/refs/tags/pcl-${PCL}.zip

RUN cd /opt && \
    wget "${PCL_URL}" -O pcl-${PCL}.zip && \
    unzip pcl-${PCL}.zip && \
    mkdir -p pcl-pcl-${PCL}/build && cd pcl-pcl-${PCL}/build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/ \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_LIBUSB=FALSE \
      -DWITH_QHULL=TRUE \
      -DWITH_CUDA=FALSE \
      -DWITH_QT=FALSE \
      -DWITH_PCAP=FALSE \
      -DWITH_OPENGL=FALSE \
      -DWITH_VTK=FALSE \
      .. && \
    make -j15 && \
    make -j15 install

FROM nvidia/cuda:11.4.2-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND noninteractive

COPY --from=build /usr/local/include /usr/local/include
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /usr/local/bin /usr/local/bin

RUN apt update && \
    apt install curl wget -y && \
    rm -rf /var/lib/apt/lists/*

# BLADE
ADD third_party /opt/third_party
RUN /opt/third_party/blade/install && \
    apt update && apt install python2.7 scons gdb git -y && \
    ln -s /usr/bin/python2.7 /usr/bin/python2 && \
    ln -s /usr/bin/python2.7 /usr/bin/python && \
    sed -i 's/python3/python2/g' /usr/bin/scons && \
    wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /tmp/get-pip.py && \
    python2 /tmp/get-pip.py && pip install cpplint

RUN apt update && apt install zsh openssh-server vim curl  -y && \
    echo "export \$(cat /proc/1/environ |tr '\\\0' '\\\n' | xargs)" >> /etc/profile && \
    echo "export \$(cat /proc/1/environ |tr '\\\0' '\\\n' | xargs)" >> /etc/zsh/zprofile && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/SilvesterHsu/utils/main/zsh.sh)" && \
    mkdir ~/.ssh && touch ~/.ssh/authorized_keys && \
    chmod 700 ~/.ssh && chmod 600  ~/.ssh/authorized_keys

# TENSORRT
ENV TENSORRT_VERSION ubuntu2004-cuda11.6-trt8.4.1.5-ga-20220604
ENV TENSORRT_URL http://ftp.zelostech.cloud/nvidia/nv-tensorrt-repo-${TENSORRT_VERSION}_1-1_amd64.deb

RUN apt update && \
    apt install curl -y && \
    rm -rf /var/lib/apt/lists/* && \
    curl "${TENSORRT_URL}" -o tensorrt.deb && \
    dpkg -i tensorrt.deb && \
    apt-key add /var/nv-tensorrt-repo-${TENSORRT_VERSION}/*.pub && \
    apt update && \
    rm -rf /var/lib/apt/lists/*nvidia* && \
    apt install -y tensorrt && \
    rm -f tensorrt.deb && \
    rm -rf /var/lib/apt/lists/*

# PYTORCH
ENV TORCH_VERSION 1.9.1
ENV TORCHVISION_VERSION 0.10.1

RUN apt update && \
    apt install -y vim curl python3 python3-pip libboost-filesystem-dev && \
    pip3 install --upgrade pip && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir torch==${TORCH_VERSION}+cu111 \
    torchvision==${TORCHVISION_VERSION}+cu111 -f https://download.pytorch.org/whl/torch_stable.html && \
    pip3 install --no-cache-dir numpy

RUN ln -s /usr/local/include/opencv4/opencv2 /usr/local/include/opencv2 && \
    ln -s /usr/local/include/pcl-1.12/pcl /usr/local/include/pcl && \
    ln -s /usr/local/include/eigen3/Eigen /usr/local/include/Eigen && \
    ln -s /usr/local/include/eigen3/unsupported /usr/local/include/unsupported && \
    echo '/usr/local/cuda/lib64' >> /etc/ld.so.conf && \
    ldconfig

ENV PATH $PATH:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/cuda/bin:/usr/local/bin:/root/bin
ENV LD_LIBRARY_PATH /usr/local/lib:/usr/local/cuda/lib64
ENV LIBRARY_PATH /usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:/usr/local/lib
ENV C_INCLUDE_PATH /usr/include/x86_64-linux-gnu:/usr/local/include:/usr/local/cuda/include
ENV CPLUS_INCLUDE_PATH /usr/include/x86_64-linux-gnu:/usr/local/include:/usr/local/cuda/include
