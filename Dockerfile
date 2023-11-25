FROM debian:bullseye AS builder

MAINTAINER Tomás Farías Santana <tomas@tomasfarias.dev>

ENV HUGO_VERSION=0.120.4

RUN apt -y update \
    && apt -y install curl git \
    && curl -SL https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz -o /tmp/hugo.tar.gz \
    && tar -xzf /tmp/hugo.tar.gz -C /tmp \
    && mv /tmp/hugo /usr/bin

WORKDIR /blog

COPY . .

RUN git submodule update --init
RUN hugo

FROM caddy:2.7-alpine

COPY --from=builder /blog/public ./public

CMD ["caddy", "file-server", "--root", "public", "--listen", "localhost:8080"]
