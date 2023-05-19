# syntax=docker/dockerfile:1

# bump: libxml2 /LIBXML2_VERSION=([\d.]+)/ https://gitlab.gnome.org/GNOME/libxml2.git|^2
# bump: libxml2 after ./hashupdate Dockerfile LIBXML2 $LATEST
# bump: libxml2 link "ChangeLog" https://gitlab.gnome.org/GNOME/libxml2/-/blob/master/NEWS
ARG LIBXML2_VERSION=2.11.4
ARG LIBXML2_URL="https://gitlab.gnome.org/GNOME/libxml2/-/archive/v${LIBXML2_VERSION}/libxml2-v${LIBXML2_VERSION}.tar.bz2"
ARG LIBXML2_SHA256=dfad4453beca4e4d9bfe3c27332d7727422b55f87f0eb764ee2a377f3ec27a7a

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBXML2_URL
ARG LIBXML2_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libxml2.tar.bz2 "$LIBXML2_URL" && \
  echo "$LIBXML2_SHA256  libxml2.tar.bz2" | sha256sum --status -c - && \
  mkdir libxml2 && \
  tar xf libxml2.tar.bz2 -C libxml2 --strip-components=1 && \
  rm libxml2.tar.bz2 && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/libxml2/ /tmp/libxml2/
WORKDIR /tmp/libxml2/build
ARG CFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
RUN \
  apk add --no-cache --virtual build \
    build-base cmake pkgconf && \
  cmake -S .. -B . \
    -D BUILD_SHARED_LIBS=OFF \
    -D CMAKE_BUILD_TYPE=Release \
    -D LIBXML2_WITH_ICONV=OFF \
    -D LIBXML2_WITH_LZMA=OFF \
    -D LIBXML2_WITH_PYTHON=OFF \
    -D LIBXML2_WITH_ZLIB=OFF \
  && \
  cmake --build . && \
  cmake --install . && \
  # Sanity tests
  pkg-config --exists --modversion --path libxml-2.0 && \
  ar -t /usr/local/lib/libxml2.a && \
  readelf -h /usr/local/lib/libxml2.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBXML2_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libxml-2.0.pc /usr/local/lib/pkgconfig/libxml-2.0.pc
COPY --from=build /usr/local/lib/libxml2.a /usr/local/lib/libxml2.a
COPY --from=build /usr/local/include/libxml2/ /usr/local/include/libxml2/
