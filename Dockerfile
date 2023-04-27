FROM alpine:3.12 AS builder

MAINTAINER Tomás Farías Santana <tomas@tomasfarias.dev>

ENV HUGO_VERSION=0.111.3

RUN apk --no-cache add \
    git \
    curl \
    && curl -SL https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz \
    -o /tmp/hugo.tar.gz \
    && tar -xzf /tmp/hugo.tar.gz -C /tmp \
    && mv /tmp/hugo /usr/local/bin/ \
    && apk del curl \
    && rm -rf /tmp/*

WORKDIR /blog

COPY . .

RUN git submodule update --init
RUN hugo

FROM caddy:2.6.4-alpine

COPY --from=builder /blog/public ./public

CMD ["caddy", "file-server", "--root", "public", "--listen", "localhost:8080"]
