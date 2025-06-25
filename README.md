![banner](https://github.com/11notes/defaults/blob/main/static/img/banner.png?raw=true)

# POCKET-ID
![size](https://img.shields.io/docker/image-size/11notes/pocket-id/1.4.1?color=0eb305)![5px](https://github.com/11notes/defaults/blob/main/static/img/transparent5x2px.png?raw=true)![version](https://img.shields.io/docker/v/11notes/pocket-id/1.4.1?color=eb7a09)![5px](https://github.com/11notes/defaults/blob/main/static/img/transparent5x2px.png?raw=true)![pulls](https://img.shields.io/docker/pulls/11notes/pocket-id?color=2b75d6)![5px](https://github.com/11notes/defaults/blob/main/static/img/transparent5x2px.png?raw=true)[<img src="https://img.shields.io/github/issues/11notes/docker-POCKET-ID?color=7842f5">](https://github.com/11notes/docker-POCKET-ID/issues)![5px](https://github.com/11notes/defaults/blob/main/static/img/transparent5x2px.png?raw=true)![swiss_made](https://img.shields.io/badge/Swiss_Made-FFFFFF?labelColor=FF0000&logo=data:image/svg%2bxml;base64,PHN2ZyB2ZXJzaW9uPSIxIiB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDMyIDMyIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxyZWN0IHdpZHRoPSIzMiIgaGVpZ2h0PSIzMiIgZmlsbD0idHJhbnNwYXJlbnQiLz4KICA8cGF0aCBkPSJtMTMgNmg2djdoN3Y2aC03djdoLTZ2LTdoLTd2LTZoN3oiIGZpbGw9IiNmZmYiLz4KPC9zdmc+)

Run pocket-id rootless and distroless.

# INTRODUCTION 📢

Pocket ID is a simple OIDC provider that allows users to authenticate with their passkeys to your services.

# SYNOPSIS 📖
**What can I do with this?** This image will run pocket-id rootless and distroless, for maximum security. It also contains a quick fix[^1] to quiet done the logging of gin.

> [!IMPORTANT]
>* This image runs as 1000:1000 by default, most other images run everything as root
>* This image has no shell since it is distroless, most other images run on a distro like Debian or Alpine with full shell access (security)
>* This image does not ship with any critical or high rated CVE and is automatically maintained via CI/CD, most other images mostly have no CVE scanning or code quality tools in place
>* This image is created via a secure, pinned CI/CD process and immune to upstream attacks, most other images have upstream dependencies that can be exploited
>* This image works as read-only, most other images need to write files to the image filesystem
>* This image is a lot smaller than most other images

If you value security, simplicity and the ability to interact with the maintainer and developer of an image. Using my images is a great start in that direction.

# COMPARISON 🏁
Below you find a comparison between this image and the most used or original one.

| **image** | 11notes/pocket-id:1.4.1 | ghcr.io/pocket-id/pocket-id |
| ---: | :---: | :---: |
| **image size on disk** | 20.7MB | 68.9MB |
| **process UID/GID** | 1000/1000 | 0/0 |
| **distroless?** | ✅ | ❌ |
| **rootless?** | ✅ | ❌ |


# VOLUMES 📁
* **/pocket-id/var** - Directory of your keys, uploads and geolite database (if license is set)

# COMPOSE ✂️
```yaml
name: "idp"
services:
  db:
    image: "11notes/postgres:16"
    read_only: true
    environment:
      TZ: "Europe/Zurich"
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - "db.etc:/postgres/etc"
      - "db.var:/postgres/var"
      - "db.backup:/postgres/backup"
      # used for optional cron container to create automatic backups
      - "db.cmd:/run/cmd"
    tmpfs:
      - "/run/postgresql:uid=1000,gid=1000"
      - "/postgres/log:uid=1000,gid=1000"
    networks:
      backend:
    restart: "always"

  pocket-id:
    depends_on:
      db:
        condition: "service_healthy"
        restart: true
    read_only: true
    image: "11notes/pocket-id:1.4.1"
    environment:
      TZ: "Europe/Zurich"
      APP_URL: "${FQDN}"
      TRUST_PROXY: true
      DB_PROVIDER: "postgres"
      DB_CONNECTION_STRING: "postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres"
    volumes:
      - "pocket-id.var:/pocket-id/var"
    ports:
      - "3000:1411/tcp"
    networks:
      frontend:
      backend:
    restart: "always"

  # optional images
  cron:
    depends_on:
      db:
        condition: "service_healthy"
        restart: true
    image: "11notes/cron:4.6"
    environment:
      TZ: "Europe/Zurich"
      # create daily full backup at 3 o'clock
      CRONTAB: |-
        0 3 * * * cmd-socket '{"bin":"backup"}' > /proc/1/fd/1
    volumes:
      - "db.cmd:/run/cmd"
    restart: "always"

volumes:
  pocket-id.var:
  db.etc:
  db.var:
  db.backup:
  db.cmd:

networks:
  frontend:
  backend:
    internal: true
```

# DEFAULT SETTINGS 🗃️
| Parameter | Value | Description |
| --- | --- | --- |
| `user` | docker | user name |
| `uid` | 1000 | [user identifier](https://en.wikipedia.org/wiki/User_identifier) |
| `gid` | 1000 | [group identifier](https://en.wikipedia.org/wiki/Group_identifier) |
| `home` | /pocket-id | home directory of user docker |

# ENVIRONMENT 📝
| Parameter | Value | Default |
| --- | --- | --- |
| `TZ` | [Time Zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) | |
| `DEBUG` | Will activate debug option for container image and app (if available) | |

# MAIN TAGS 🏷️
These are the main tags for the image. There is also a tag for each commit and its shorthand sha256 value.

* [1.4.1](https://hub.docker.com/r/11notes/pocket-id/tags?name=1.4.1)

### There is no latest tag, what am I supposed to do about updates?
It is of my opinion that the ```:latest``` tag is dangerous. Many times, I’ve introduced **breaking** changes to my images. This would have messed up everything for some people. If you don’t want to change the tag to the latest [semver](https://semver.org/), simply use the short versions of [semver](https://semver.org/). Instead of using ```:1.4.1``` you can use ```:1``` or ```:1.4```. Since on each new version these tags are updated to the latest version of the software, using them is identical to using ```:latest``` but at least fixed to a major or minor version.

If you still insist on having the bleeding edge release of this app, simply use the ```:rolling``` tag, but be warned! You will get the latest version of the app instantly, regardless of breaking changes or security issues or what so ever. You do this at your own risk!

# REGISTRIES ☁️
```
docker pull 11notes/pocket-id:1.4.1
docker pull ghcr.io/11notes/pocket-id:1.4.1
docker pull quay.io/11notes/pocket-id:1.4.1
```

# SOURCE 💾
* [11notes/pocket-id](https://github.com/11notes/docker-POCKET-ID)

# PARENT IMAGE 🏛️
> [!IMPORTANT]
>This image is not based on another image but uses [scratch](https://hub.docker.com/_/scratch) as the starting layer.
>The image consists of the following distroless layers that were added:
>* [11notes/distroless](https://github.com/11notes/docker-distroless/blob/master/arch.dockerfile) - contains users, timezones and Root CA certificates
>* [11notes/distroless:curl](https://github.com/11notes/docker-distroless/blob/master/curl.dockerfile) - app to execute HTTP or UNIX requests

# BUILT WITH 🧰
* [pocket-id/pocket-id](https://github.com/pocket-id/pocket-id)

# GENERAL TIPS 📌
> [!TIP]
>* Use a reverse proxy like Traefik, Nginx, HAproxy to terminate TLS and to protect your endpoints
>* Use Let’s Encrypt DNS-01 challenge to obtain valid SSL certificates for your services

[^1]: A [PR](https://github.com/pocket-id/pocket-id/pull/681) was added to resolve this issue upstream

# ElevenNotes™️
This image is provided to you at your own risk. Always make backups before updating an image to a different version. Check the [releases](https://github.com/11notes/docker-pocket-id/releases) for breaking changes. If you have any problems with using this image simply raise an [issue](https://github.com/11notes/docker-pocket-id/issues), thanks. If you have a question or inputs please create a new [discussion](https://github.com/11notes/docker-pocket-id/discussions) instead of an issue. You can find all my other repositories on [github](https://github.com/11notes?tab=repositories).

*created 26.06.2025, 00:00:01 (CET)*