FROM node:latest AS build-js

RUN npm install gulp gulp-cli -g

RUN git clone https://github.com/warhorse/gophish /build
WORKDIR /build
RUN npm install --only=dev
RUN gulp

# Build Golang binary
FROM golang:1.15.2 AS build-golang

ENV EGP_USER="fin3ss3g0d"

RUN git clone https://github.com/warhorse/gophish /go/src/github.com/warhorse/gophish \
    && git clone https://github.com/${EGP_USER}/evilgophish /go/src/github.com/warhorse/${EGP_USER}/evilgophish
    
RUN cp -r /go/src/github.com/warhorse/${EGP_USER}/evilgophish/gophish /go/src/github.com/warhorse/gophish

# # Stripping X-Gophish 

# RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
# RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
# RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
# RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go

# # Stripping X-Gophish-Signature
# RUN sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

# # Changing server name
# RUN sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

# # Changing rid value
# RUN sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "keyname"/g' models/campaign.go

WORKDIR /go/src/github.com/warhorse/gophish

RUN go get -v && go build -v

# Runtime container
FROM debian:stable-slim

ENV GITHUB_USER="gophish"
ENV GOPHISH_REPOSITORY="github.com/${GITHUB_USER}/gophish"
ENV PROJECT_DIR="${GOPATH}/src/${GOPHISH_REPOSITORY}"

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="v0.0.1"

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
	apt-get install --no-install-recommends -y jq libcap2-bin && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish
COPY ./files/phish.go ./controllers/phish.go
COPY ./files/404.html ./templates/
COPY --from=build-golang /go/src/github.com/warhorse/gophish/ ./
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /go/src/github.com/warhorse/gophish/config.json ./
COPY ./docker-entrypoint.sh /opt/gophish
RUN chmod +x /opt/gophish/docker-entrypoint.sh
RUN chown app. config.json docker-entrypoint.sh

RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app
RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json
RUN touch config.json.tmp


EXPOSE 3333 8080 8443 80

CMD ["/opt/gophish/docker-entrypoint.sh"]

STOPSIGNAL SIGKILL

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="Gophish Docker" \
  org.label-schema.description="Gophish Docker Build" \
  org.label-schema.url="https://github.com/war-horse/docker-gophish" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/war-horse/docker-gophish" \
  org.label-schema.vendor="warhorse" \
  org.label-schema.version=$VERSION \
  org.label-schema.schema-version="1.0"
