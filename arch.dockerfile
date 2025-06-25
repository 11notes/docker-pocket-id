# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
  # GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      BUILD_ROOT=/go/pocket-id \
      BUILD_BIN=/go/pocket-id/backend/pocket-id

  # :: FOREIGN IMAGES
  FROM 11notes/distroless AS distroless
  FROM 11notes/distroless:curl AS distroless-curl
  FROM 11notes/util AS util

# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
  # :: pocket-id
  FROM golang:1.24-alpine AS build
  COPY --from=util /usr/local/bin /usr/local/bin
  ARG APP_VERSION \
      BUILD_ROOT \
      BUILD_BIN

  ENV CGO_ENABLED=0

  RUN set -ex; \
    apk --update --no-cache add \
      build-base \
      upx \
      nodejs \
      npm \
      yarn \
      git;

  RUN set -ex; \
    git clone https://github.com/pocket-id/pocket-id -b v${APP_VERSION};

  RUN set -ex; \
    cd ${BUILD_ROOT}/frontend; \
    npm ci; \
    BUILD_OUTPUT_PATH=dist npm run build;

  RUN set -ex; \
    # fix zealous logging, PR was added upstream: https://github.com/pocket-id/pocket-id/pull/681
    cd ${BUILD_ROOT}/backend; \
    sed -i 's#import (#import (\n\t"strings"#' ${BUILD_ROOT}/backend/internal/bootstrap/router_bootstrap.go; \
    sed -i 's#r := gin.Default()#r := gin.New()\n\tloggerSkipPathsPrefix := []string{"GET /api/application-configuration","GET /_app","GET /fonts","HEAD /healthz",}#' ${BUILD_ROOT}/backend/internal/bootstrap/router_bootstrap.go; \
    sed -i 's#r.Use(gin.Logger())#r.Use(gin.LoggerWithConfig(gin.LoggerConfig{Skip:func(c *gin.Context) bool {for _, prefix := range loggerSkipPathsPrefix {if strings.HasPrefix(fmt.Sprintf("%s %s", c.Request.Method, c.Request.URL.String()), prefix){return true}}; return false}}))#' ${BUILD_ROOT}/backend/internal/bootstrap/router_bootstrap.go; \
    go mod tidy;

  RUN set -ex; \
    cd ${BUILD_ROOT}/backend/cmd; \
    cp -R ${BUILD_ROOT}/frontend/dist ${BUILD_ROOT}/backend/frontend/dist; \
    go build -trimpath -ldflags="-X github.com/pocket-id/pocket-id/backend/internal/common.Version=${APP_VERSION} -buildid=${APP_VERSION} -extldflags=-static" -o ${BUILD_BIN} main.go;

  RUN set -ex; \
    mkdir -p /distroless/usr/local/bin; \
    eleven checkStatic ${BUILD_BIN}; \
    eleven strip ${BUILD_BIN}; \
    chmod +x ${BUILD_BIN}; \
    cp ${BUILD_BIN} /distroless/usr/local/bin;

  # :: file system
  FROM alpine AS file-system
  COPY --from=util /usr/local/bin /usr/local/bin
  ARG APP_ROOT
  USER root
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
    COPY --from=distroless-curl / /
    COPY --from=build /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/var"]

# :: HEALTH
  HEALTHCHECK --interval=5s --timeout=2s --start-interval=5s \
    CMD ["/usr/local/bin/curl", "-kILs", "--fail", "http://localhost:1411/healthz/"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/pocket-id"]