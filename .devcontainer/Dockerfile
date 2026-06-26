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

# Install Rust to a system-wide location so all users (incl. vscode) have access
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    chmod -R a+rwX /usr/local/rustup /usr/local/cargo

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

# Re-open cargo registry permissions after all builds (root created new cache entries above)
RUN chmod -R a+rwX /usr/local/cargo

# ----------------
# Install smplx
# ----------------
RUN curl -L https://smplx.simplicity-lang.org | bash && \
    ~/.simplex/bin/simplexup && \
    cp ~/.simplex/bin/* /usr/local/bin/

# ----------------
# Install simplicity-lsp
# ----------------
RUN cargo install simplicityhl-lsp && \
    cp /usr/local/cargo/bin/simplicityhl-lsp /usr/local/bin/

# ------------------------------------------------
# Install tx-manifest-wallet via asdf plugin
# ------------------------------------------------
ENV ASDF_DIR=/opt/asdf \
    ASDF_DATA_DIR=/opt/asdf-data
RUN git clone https://github.com/asdf-vm/asdf.git ${ASDF_DIR} --branch v0.14.1 && \
    . ${ASDF_DIR}/asdf.sh && \
    asdf plugin add tx-manifest-wallet https://github.com/stringhandler/asdf-tx-manifest-wallet.git && \
    VERSION="$(asdf latest tx-manifest-wallet)" && \
    asdf install tx-manifest-wallet "$VERSION" && \
    cp "$(asdf where tx-manifest-wallet "$VERSION")/bin/tx-manifest-wallet" /usr/local/bin/ && \
    ln -s /usr/local/bin/tx-manifest-wallet /usr/local/bin/txw

# Default workspace
WORKDIR /workspace
