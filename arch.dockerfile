# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      BUILD_SRC=pocket-id/pocket-id.git \
      BUILD_ROOT=/go/pocket-id 
  ARG BUILD_BIN=${BUILD_ROOT}/backend/pocket-id

# :: FOREIGN IMAGES
  FROM 11notes/distroless AS distroless
  FROM 11notes/util AS util

# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: POCKET-ID
  FROM golang:1.24-alpine AS build
  ARG APP_VERSION \
      BUILD_SRC \
      BUILD_ROOT \
      BUILD_BIN

  RUN set -ex; \
    apk --update --no-cache add \
      nodejs \
      npm \
      yarn;

  RUN set -ex; \
    eleven git clone ${BUILD_SRC} v${APP_VERSION};

  RUN set -ex; \
    cd ${BUILD_ROOT}/frontend; \
    npm ci; \
    BUILD_OUTPUT_PATH=dist npm run build;

  RUN set -ex; \
    cd ${BUILD_ROOT}/backend/cmd; \
    cp -R ${BUILD_ROOT}/frontend/dist ${BUILD_ROOT}/backend/frontend/dist; \
    go build -trimpath -ldflags="-X github.com/pocket-id/pocket-id/backend/internal/common.Version=${APP_VERSION} -buildid=${APP_VERSION} -extldflags=-static" -o ${BUILD_BIN} main.go;

  RUN set -ex; \
    eleven distroless ${BUILD_BIN};

  # :: file system
  FROM alpine AS file-system
  COPY --from=util / /
  ARG APP_ROOT
  RUN set -ex; \
    eleven mkdir /distroless${APP_ROOT}/var/{uploads,keys,geolite};

# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
# :: HEADER
  FROM scratch

  # :: default arguments
    ARG TARGETPLATFORM \
        TARGETOS \
        TARGETARCH \
        TARGETVARIANT \
        APP_IMAGE \
        APP_NAME \
        APP_VERSION \
        APP_ROOT \
        APP_UID \
        APP_GID \
        APP_NO_CACHE

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
        APP_NAME=${APP_NAME} \
        APP_VERSION=${APP_VERSION} \
        APP_ROOT=${APP_ROOT}

  # :: app specific environment
    ENV APP_ENV=production \
        ANALYTICS_DISABLED=true \
        UPLOAD_PATH=${APP_ROOT}/var/uploads \
        KEYS_PATH=${APP_ROOT}/var/keys \
        GEOLITE_DB_PATH=${APP_ROOT}/var/geolite;

  # :: multi-stage
    COPY --from=distroless / /
    COPY --from=build /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/var"]

# :: HEALTH
  HEALTHCHECK --interval=5s --timeout=2s --start-interval=5s \
    CMD ["/usr/local/bin/pocket-id", "healthcheck"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/pocket-id"]