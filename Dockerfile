# encodingtools-multiarch

# Use debian:stable-slim for our base build image
FROM docker.io/debian:stable-slim as build

# Set the working directory to /build
WORKDIR /build

# Add /usr/local/lib to the library path
ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib

# Update and install build packages
RUN apt-get update && \
    apt-get install -y \
        autoconf \
        automake \
        build-essential \
        cmake \
        git-core \
        libass-dev \
        libfreetype6-dev \
        libgnutls28-dev \
        libsdl2-dev \
        libtool \
        libva-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        meson \
        nasm \
        ninja-build \
        pkg-config \
        texinfo \
        curl \
        yasm \
        libssl-dev \
        clang \
        zlib1g-dev && \
    # Clone repos
    git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git && \
    git clone https://github.com/xiph/opus.git && \
    git clone https://github.com/Netflix/vmaf.git && \
    git clone https://github.com/quietvoid/hdr10plus_tool.git && \
    git clone https://github.com/quietvoid/dovi_tool.git && \
    git clone https://github.com/gianni-rosato/svt-av1-psy.git && \
    # Install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    # Install cargo-c
    /root/.cargo/bin/cargo install cargo-c && \
    # Build libopus git
    cd /build/opus && \
    autoreconf -fiv && \
    ./configure \
        --prefix=/usr/local \
        --enable-shared && \
    make -j$(nproc) && \
    make install && \
    # Build libvmaf git
    cd /build/vmaf/libvmaf && \
    meson setup build \
        --buildtype release \
        --default-library=shared \
        --bindir="/usr/local/bin" \
        --libdir="/usr/local/lib" \
        -Denable_tests=false \
        -Denable_docs=false && \
    ninja -C build && \
    ninja -C build install && \
    # Build libhdr10plus git
    cd /build/hdr10plus_tool/hdr10plus && \
    /root/.cargo/bin/cargo cinstall \
        --release \
        --prefix=/usr/local && \
    # Build libdovi git
    cd /build/dovi_tool/dolby_vision && \
    /root/.cargo/bin/cargo cinstall \
        --release \
        --prefix=/usr/local && \
    # Build svt-av1-psy git
    cd /build/svt-av1-psy/Build && \
    export CC=clang \
        CXX=clang++ && \
    cmake .. -G"Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BU-DBUILD_SHARED_LIBS=ON \
        -DBUILD_DEC=OFF \
        -DSVT_AV1_LTO=ON \
        -DENABLE_AVX512=ON \
        -DNATIVE=ON \
        -DCMAKE_CXX_FLAGS="-O3" \
        -DCMAKE_C_FLAGS="-O3" \
        -DCMAKE_LD_FLAGS="-O3" \
        -DLIBHDR10PLUS_RS_FOUND=1 \
        -DLIBDOVI_FOUND=1 && \
    make -j $(nproc) && \
    make install && \
    # Build ffmpeg git
    cd /build/FFmpeg && \
    ./configure \
        --prefix=/usr/local \
        --enable-gpl \
        --enable-libass \
        --enable-libfreetype \
        --enable-libopus \
        --enable-libvmaf \
        --enable-libsvtav1 \
        --enable-gpl \
        --enable-version3 \
        --disable-doc && \
    make -j$(nproc) && \
    make install && \
    # Build ab-av1 git
    /root/.cargo/bin/cargo install \
        --git https://github.com/alexheretic/ab-av1 \
        --root /usr/local

# Use debian:stable-slim for our base runtime image
FROM docker.io/debian:stable-slim as runtime

# # Set the working directory to /app
WORKDIR /app

# # Copy from build container
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/lib /usr/local/lib

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
        --no-install-recommends \
        libasound2 \
        libass9 \
        libfreetype6 \
        libdrm2 \
        libsdl2-2.0-0 \
        libsndio7.0 \
        libxcb-shape0 \
        libxcb-shm0 \
        libxcb-util1 \
        libxcb-xfixes0 \
        libxv1 \
        libva2 \
        libva-drm2 \
        libva-x11-2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["/usr/local/bin/ab-av1"]