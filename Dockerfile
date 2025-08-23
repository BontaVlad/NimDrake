# -------------------------------------------------------------------
# Stage 1: Build Nim 2.2.4 with your patch
# -------------------------------------------------------------------
FROM ubuntu:22.04 AS nim-build

RUN apt-get update && apt-get install -y \
    git build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/nim-lang/Nim.git
WORKDIR /src/Nim
RUN git checkout v2.2.4

# Apply your patch
COPY nim.2.2.4_heaptracker_addon.patch /src/Nim/
RUN git apply nim.2.2.4_heaptracker_addon.patch

# Build Nim in performance mode
RUN sh build_all.sh

# -------------------------------------------------------------------
# Stage 2: Build heaptrack (minimal)
# -------------------------------------------------------------------
FROM ubuntu:22.04 AS heaptrack-build

RUN apt-get update && apt-get install -y \
    gdb git g++ make cmake zlib1g-dev \
    libboost-dev libboost-iostreams-dev \
    libunwind-dev libdw-dev libelf-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/KDE/heaptrack.git /heaptrack
WORKDIR /heaptrack
RUN git reset --hard f9cc35ebbdde92a292fe3870fe011ad2874da0ca

RUN mkdir -p build
WORKDIR /heaptrack/build
RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DHEAPTRACK_BUILD_GUI=OFF \
          -DHEAPTRACK_BUILD_PRINT=OFF \
          ..
RUN make -j$(nproc)


# -------------------------------------------------------------------
# Final Stage: Debug image with Nim + heaptrack
# -------------------------------------------------------------------
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    gdb git libunwind8 libdw1 libelf1 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    clang \
    libclang-dev \
    wget \
    unzip \
    gcc \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install DuckDB
RUN mkdir -p /tmp/duckdb-cache && \
    cd /tmp/duckdb-cache && \
    wget https://github.com/duckdb/duckdb/releases/download/v1.3.2/libduckdb-linux-amd64.zip && \
    unzip libduckdb-linux-amd64.zip && \
    cp libduckdb.so /usr/lib/ && \
    ldconfig && \
    rm -rf /tmp/duckdb-cache

# Copy entire Nim installation
COPY --from=nim-build /src/Nim /usr/local/lib/nim

# Nim binaries
COPY --from=nim-build /src/Nim/bin/nim /usr/local/bin/nim
COPY --from=nim-build /src/Nim/bin/nimble /usr/local/bin/nimble
COPY --from=nim-build /src/Nim/bin/nimsuggest /usr/local/bin/nimsuggest

# Heaptrack
COPY --from=heaptrack-build /heaptrack/build/bin/heaptrack /usr/local/bin/heaptrack
COPY --from=heaptrack-build /heaptrack/build/lib/heaptrack/ /usr/local/lib/heaptrack/

ENV LD_LIBRARY_PATH=/usr/local/lib/heaptrack/:$LD_LIBRARY_PATH
ENV NIMCACHE_DIR="nimcache"

WORKDIR /app
COPY ./ /app

RUN /usr/local/bin/nimble install -y
RUN /usr/local/bin/nim c -d:release -d:heaptracker benchmarks/benchmark_fetch.nim
ENTRYPOINT ["heaptrack", "-o", "out/heaptrack.benchmark_fetch.1.gz", "benchmarks/benchmark_fetch"]
