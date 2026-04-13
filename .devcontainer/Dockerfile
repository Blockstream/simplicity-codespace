FROM mcr.microsoft.com/devcontainers/base:ubuntu

# -----------------------------------------------
# Repo URLs — override via devcontainer.json args
# -----------------------------------------------
ARG SIMPLICITYHL_REPO=https://github.com/BlockstreamResearch/SimplicityHL.git
ARG HAL_SIMPLICITY_REPO=https://github.com/BlockstreamResearch/hal-simplicity.git

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    ca-certificates \
    pkg-config \
    libssl-dev \
    mcpp \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# -------------------------
# Build simc (SimplicityHL)
# -------------------------
WORKDIR /opt
RUN git clone ${SIMPLICITYHL_REPO}
WORKDIR /opt/SimplicityHL
RUN cargo build --release --features "serde"
RUN cp target/release/simc /usr/local/bin/

# -------------------------------
# Build hal-simplicity
# -------------------------------
WORKDIR /opt
RUN git clone ${HAL_SIMPLICITY_REPO}
WORKDIR /opt/hal-simplicity
RUN cargo build --release
RUN cp target/release/hal-simplicity /usr/local/bin/

# ----------------
# Install smplx
# ----------------
RUN curl -L https://smplx.simplicity-lang.org | bash && \
    ~/.simplex/bin/simplexup && \
    cp ~/.simplex/bin/simplex /usr/local/bin/simplex && \
    cp ~/.simplex/bin/simplex /usr/local/bin/smplx

# Default workspace
WORKDIR /workspace
