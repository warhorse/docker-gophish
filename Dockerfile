# ---------- Stage 1: build JS assets ----------
FROM node:latest AS build-js

RUN npm install -g gulp gulp-cli

RUN git clone https://github.com/kgretzky/gophish /build
WORKDIR /build
RUN npm install --only=dev
RUN gulp    # produces built assets under ./static

# ---------- Stage 2: build Go binary ----------
FROM golang:latest AS build-golang

RUN apt-get update && \
  apt-get install --no-install-recommends -y build-essential ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/kgretzky/gophish /go/src/github.com/kgretzky/gophish
WORKDIR /go/src/github.com/kgretzky/gophish

# Bring over the freshly-built static assets from stage 1
COPY --from=build-js /build/static ./static


RUN sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go
RUN set -ex \
    && sed -i 's/SignatureHeader = "X-Gophish-Signature"/SignatureHeader = "X-Report-Signature"/g' webhook/webhook.go \
    && sed -i 's/"github.com\/gophish\/gophish\/config"/\/\/"github.com\/gophish\/gophish\/config"/g' models/maillog.go \
    && sed -i 's/msg.SetHeader("X-Mailer", config.ServerName)/\/\/msg.SetHeader("X-Mailer", config.ServerName)/g' models/maillog.go \
    && sed -i 's/"X-Gophish-Contact": "",/\/\/"X-Gophish-Contact": "",/g' models/maillog_test.go \
    && sed -i 's/Header{Key: "X-Gophish-Contact", Value: ""},/\/\/Header{Key: "X-Gophish-Contact", Value: ""},/g' models/maillog_test.go \
    && sed -i 's/"X-Gophish-Contact": s.config.ContactAddress,/\/\/"X-Gophish-Contact": s.config.ContactAddress,/g' models/maillog_test.go \
    && sed -i 's/msg.SetHeader("X-Gophish-Contact", conf.ContactAddress)/\/\/msg.SetHeader("X-Gophish-Contact", conf.ContactAddress)/g' models/email_request.go \
    && sed -i 's/"X-Gophish-Contact": s.config.ContactAddress,/\/\/"X-Gophish-Contact": s.config.ContactAddress,/g' models/email_request_test.go \
    && sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/g' config/config.go \
    && sed -i 's/hostname, err := os.Hostname()/hostname := "mailgun"/' models/smtp.go

# Patch only inside generateMessageID()
RUN grep -q 'h := "mailgun"' models/maillog.go || ( \
  sed -i '/func (m \*MailLog) generateMessageID/,/return msgid, nil/ s/h, \?err \?:= \?os\.Hostname()$/h := "mailgun"/' models/maillog.go && \
  sed -i '/If we can.t get the hostname, we.ll use localhost/{N;N;N;d}' models/maillog.go \
)

RUN sed -i -E \
  -e '/^[[:space:]]*import[[:space:]]*\(/,/^[[:space:]]*\)/ { /^[[:space:]]*([_.[:alnum:]]+[[:space:]]+)?\"os\"[[:space:]]*$/d }' \
  -e '/^[[:space:]]*import[[:space:]]+([_.[:alnum:]]+[[:space:]]+)?\"os\"[[:space:]]*$/d' \
  -e '/^[[:space:]]*import[[:space:]]*\([[:space:]]*\)[[:space:]]*$/d' \
  models/smtp.go


# Stripping X-Gophish-Signature
RUN sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

# --- IMPORTANT: ensure VERSION exists for both build and runtime ---
ARG VERSION="v0.12.1"
RUN printf "%s\n" "$VERSION" > VERSION

# Build with Go modules
RUN set -eux; \
    if [ -f go.mod ]; then go mod download; fi; \
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -v -o /go/bin/gophish .

# ---------- Stage 3: runtime ----------
FROM debian:stable-slim

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG VCS_REF="local"
ARG VERSION="v0.12.1"

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
    apt-get install --no-install-recommends -y jq libcap2-bin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish

# Binary
COPY --from=build-golang /go/bin/gophish /opt/gophish/gophish

# ---- Runtime assets Gophish expects on disk ----
# VERSION file (fixes your "open ./VERSION" at runtime)
COPY --from=build-golang /go/src/github.com/kgretzky/gophish/VERSION ./VERSION
# DB migrations and templates (Gophish reads these from disk)
COPY --from=build-golang /go/src/github.com/kgretzky/gophish/db ./db
COPY --from=build-golang /go/src/github.com/kgretzky/gophish/templates ./templates
# Full static dir built in stage 1 (includes js/css/images, etc.)
COPY --from=build-js      /build/static ./static

# Config & entrypoint
COPY --from=build-golang /go/src/github.com/kgretzky/gophish/config.json ./
COPY ./docker-entrypoint.sh /opt/gophish
RUN chmod +x /opt/gophish/docker-entrypoint.sh && \
    chown app. config.json docker-entrypoint.sh

# allow binding low ports
RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app
RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json && touch config.json.tmp

EXPOSE 3333 8080 8443 80
STOPSIGNAL SIGKILL
CMD ["/opt/gophish/docker-entrypoint.sh"]

# labels
ARG BUILD_DATE
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Gophish Docker" \
      org.label-schema.description="Gophish Docker Build" \
      org.label-schema.url="https://github.com/almart/docker-gophish" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/almart/docker-gophish" \
      org.label-schema.vendor="almart" \
      org.label-schema.version="v0.12.2" \
      org.label-schema.schema-version="1.0"
