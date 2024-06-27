# encodingtools-multiarch

# Use five82/buildtools:latest for our base build image
FROM ghcr.io/five82/buildtools:latest as build

# Set the working directory to /build
WORKDIR /build

# Copy the patches directory
COPY patches /build/patches

# Add /usr/local/lib to the library path
ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib \
    PATH="/root/.local/pipx/bin:$PATH"

# Update and install build packages
RUN apt-get update && \
    apt-get install -y \
        libass-dev \
        libfreetype6-dev \
        libgnutls28-dev \
        libsdl2-dev \
        libtool \
        libva-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        pipx \
        xxd

# Build libopus git
RUN git clone https://gitlab.xiph.org/xiph/opus.git && \
    cd /build/opus && \
    autoreconf -fiv && \
    ./configure \
        --prefix=/usr/local \
        --enable-shared && \
    make -j$(nproc) && \
    make install

# Build libvmaf git
RUN git clone https://github.com/Netflix/vmaf.git && \
    cd /build/vmaf/libvmaf && \
    meson setup build \
        --buildtype release \
        --default-library=shared \
        --bindir="/usr/local/bin" \
        --libdir="/usr/local/lib" \
        -Denable_tests=false \
        -Denable_docs=false && \
    ninja -C build && \
    ninja -C build install

# Build libhdr10plus git
RUN git clone https://github.com/quietvoid/hdr10plus_tool.git && \
    cd /build/hdr10plus_tool/hdr10plus && \
    /root/.cargo/bin/cargo cinstall \
        --release \
        --prefix=/usr/local \
        --jobs $(nproc)

# Build libdovi git
RUN git clone https://github.com/quietvoid/dovi_tool.git && \
    cd /build/dovi_tool/dolby_vision && \
    /root/.cargo/bin/cargo cinstall \
        --release \
        --prefix=/usr/local\
        --jobs $(nproc)

# Build svt-av1-psy git
RUN git clone https://github.com/gianni-rosato/svt-av1-psy.git && \
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
    make install

# Build libdav1d git
RUN git clone --depth=1 https://code.videolan.org/videolan/dav1d.git && \
    cd /build/dav1d && \
    meson setup build \
        --buildtype release \
        --default-library=shared \
        --prefix=/usr/local \
        --bindir="/usr/local/bin" \
        --libdir="/usr/local/lib" \
        -Denable_tools=false \
        -Denable_tests=false \
        -Denable_asm=true && \
    ninja -C build && \
    ninja -C build install

# Build ffmpeg git
RUN git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git && \
    cd /build/FFmpeg && \
    ./configure \
        --prefix=/usr/local \
        --enable-gpl \
        --enable-libass \
        --enable-libdav1d \
        --enable-libfreetype \
        --enable-libopus \
        --enable-libvmaf \
        --enable-libsvtav1 \
        --enable-gpl \
        --enable-version3 \
        --disable-doc \
        --disable-debug \
        --disable-ffplay \
        --disable-static \
        --enable-shared && \
    make -j$(nproc) && \
    make install

# Install alabamaencoder
RUN pipx install alabamaencoder

# Use debian:stable-slim for our base runtime image
FROM docker.io/debian:stable-slim as runtime

# # Set the working directory to /app
WORKDIR /app

# # Copy from build container
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /root/.local/pipx /root/.local/pipx

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
        libva-x11-2 \
        python3 \
        libgl1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Create a symlink to alabamaencoder
    ln -s /root/.local/pipx/venvs/alabamaencoder/bin/alabamaEncoder /usr/local/bin/alabamaencoder

CMD ["/usr/local/bin/alabamaencoder"]