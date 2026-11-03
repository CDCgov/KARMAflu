FROM ubuntu:jammy AS app

ARG BLAST_VER="2.17.0"
ARG TARGETARCH

LABEL base.image="ubuntu:jammy"
LABEL dockerfile.version="2"
LABEL software="blast+"
LABEL software.version=$BLAST_VER
LABEL description="Finds matches in sequencing reads"
LABEL website="https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download"
LABEL license="https://www.ncbi.nlm.nih.gov/IEB/ToolBox/CPP_DOC/lxr/source/scripts/projects/blast/LICENSE"
LABEL maintainer="Erin Young"
LABEL maintainer.email="eriny@utah.gov"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      wget \
      ca-certificates \
      libgomp1 \
      libsqlite3-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) BLAST_ARCH="x64" ;; \
      arm64) BLAST_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    BLAST_TARBALL="ncbi-blast-${BLAST_VER}+-${BLAST_ARCH}-linux.tar.gz"; \
    wget -q "https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_VER}/${BLAST_TARBALL}"; \
    tar -xzf "${BLAST_TARBALL}"; \
    rm -f "${BLAST_TARBALL}"

ENV PATH="/ncbi-blast-${BLAST_VER}+/bin:${PATH}" \
    LC_ALL=C

WORKDIR /data

CMD ["blastn", "-help"]

FROM app AS test

RUN ls "/ncbi-blast-${BLAST_VER}+/bin/"
RUN blastn -help