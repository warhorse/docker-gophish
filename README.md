# [warhorse/gophish](https://github.com/war-horse/docker-gophish)
[![GitHub Release](https://img.shields.io/github/release/war-horse/docker-gophish.svg?style=flat-square&color=E68523)](https://github.com/war-horse/docker-gophish/releases)
[![MicroBadger Layers](https://img.shields.io/microbadger/layers/warhorse/gophish.svg?style=flat-square&color=E68523)](https://microbadger.com/images/warhorse/gophish "Get your own version badge on microbadger.com")
[![MicroBadger Size](https://img.shields.io/microbadger/image-size/warhorse/gophish.svg?style=flat-square&color=E68523)](https://microbadger.com/images/warhorse/gophish "Get your own version badge on microbadger.com")
[![Docker Pulls](https://img.shields.io/docker/pulls/warhorse/gophish.svg?style=flat-square&color=E68523)](https://hub.docker.com/r/warhorse/gophish)
[![Docker Stars](https://img.shields.io/docker/stars/warhorse/gophish.svg?style=flat-square&color=E68523)](https://hub.docker.com/r/warhorse/gophish)

[Gophish](https://github.com/gophish/gophish) - is an open-source phishing toolkit designed for businesses and penetration testers. It provides the ability to quickly and easily setup and execute phishing engagements and security awareness training.

![Gophish](https://camo.githubusercontent.com/e401fbe8f27b84bdba6d577b6ba7c693029491d2a93b86662c31e16f9cef6712/68747470733a2f2f7261772e6769746875622e636f6d2f676f70686973682f676f70686973682f6d61737465722f7374617469632f696d616765732f676f70686973685f707572706c652e706e67)

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=gophish \
  -p 443:443 \
  -p 3333:3333 \
  -v <path to data>:/data \
  --restart unless-stopped \
  warhorse/gophish
```

### docker-compose

Compatible with docker-compose v2 schemas.

```
---
version: "2"
services:
  gophish:
    image: warhorse/gophish
    container_name: gophish
    environment:
      ADMIN_USE_TLS: "false"
      PHISH_USE_TLS: "false"
      DB_FILE_PATH: "/data/gophish.db"
    volumes:
      - <path to data>:/data
      - "/etc/localtime:/etc/localtime:ro"
    ports:
      - 443:443
      - 3333:3333
    restart: unless-stopped
```

## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 3333` | The port for HTTP traffic |
| `-p 443` | The port for HTTPS traffic |
| `-v /data` | gophish configs |

&nbsp;
## Application Setup

Access the webui at `<your-ip>:3333`, for more information check out [gophish](https://github.com/gophish/gophish).


## Support Info

* Shell access whilst the container is running: `docker exec -it gophish /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f gophish`

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:
```
git clone https://github.com/warhorse/docker-gophish.git
cd docker-gophish
docker build \
  --no-cache \
  --pull \
  -t warhorse/gophish:latest .
```
## Versions

* **04.06.21:** - First Push