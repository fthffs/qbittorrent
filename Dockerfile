ARG RADARR_VERSION=5.14.0.9383
ARG QBITTORRENT_VERSION=

# create an up-to-date base image for everything
FROM alpine:3.20 AS base

RUN \
  apk --no-cache --update-cache upgrade

# run-time dependencies
RUN \
  apk --no-cache add \
  bash \
  curl \
  doas \
  python3 \
  qt6-qtbase \
  qt6-qtbase-sqlite \
  tini \
  tzdata

# image for building
FROM base AS builder

ARG QBT_VERSION=release-5.0.1
ARG LIBBT_VERSION="RC_1_2"
ARG LIBBT_CMAKE_FLAGS=""

# check environment variables
RUN \
  if [ -z "${QBT_VERSION}" ]; then \
  echo 'Missing QBT_VERSION variable. Check your command line arguments.' && \
  exit 1 ; \
  fi

# alpine linux packages:
# https://git.alpinelinux.org/aports/tree/community/libtorrent-rasterbar/APKBUILD
# https://git.alpinelinux.org/aports/tree/community/qbittorrent/APKBUILD
RUN \
  apk add \
  boost-dev \
  cmake \
  git \
  g++ \
  ninja \
  openssl-dev \
  qt6-qtbase-dev \
  qt6-qttools-dev

# compiler, linker options:
# https://gcc.gnu.org/onlinedocs/gcc/Option-Summary.html
# https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html
# https://sourceware.org/binutils/docs/ld/Options.html
ENV CFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
  CXXFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS" \
  LDFLAGS="-gz -Wl,-O1,--as-needed,--sort-common,-z,now,-z,pack-relative-relocs,-z,relro"

# build libtorrent
RUN \
  git clone \
  --branch "${LIBBT_VERSION}" \
  --depth 1 \
  --recurse-submodules \
  https://github.com/arvidn/libtorrent.git && \
  cd libtorrent && \
  cmake \
  -B build \
  -G Ninja \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -Ddeprecated-functions=OFF \
  $LIBBT_CMAKE_FLAGS && \
  cmake --build build -j $(nproc) && \
  cmake --install build

# build qbittorrent
RUN \
  if [ "${QBT_VERSION}" = "devel" ]; then \
  git clone \
  --depth 1 \
  --recurse-submodules \
  https://github.com/qbittorrent/qBittorrent.git && \
  cd qBittorrent ; \
  else \
  wget "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${QBT_VERSION}.tar.gz" && \
  tar -xf "release-${QBT_VERSION}.tar.gz" && \
  cd "qBittorrent-release-${QBT_VERSION}" ; \
  fi && \
  cmake \
  -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DGUI=OFF && \
  cmake --build build -j $(nproc) && \
  cmake --install build

RUN \
  ldd /usr/bin/qbittorrent-nox | sort -f

# image for running
FROM base

RUN \
  adduser \
  -D \
  -H \
  -s /sbin/nologin \
  -u 1000 \
  qbtUser

COPY --chmod=755 --from=builder /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER qbtUser

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
