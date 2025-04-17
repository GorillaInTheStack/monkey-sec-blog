FROM debian:bullseye-slim

WORKDIR /site

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  git \
  ca-certificates \
  unzip \
  wget \
  && rm -rf /var/lib/apt/lists/*

ENV GO_VERSION=1.24.2
RUN curl -LO https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
  && rm go${GO_VERSION}.linux-amd64.tar.gz \
  && ln -s /usr/local/go/bin/go /usr/bin/go

ENV HUGO_VERSION=0.146.5
RUN curl -L https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz \
  -o hugo.tar.gz \
  && tar -xzf hugo.tar.gz \
  && mv hugo /usr/local/bin/hugo \
  && rm hugo.tar.gz

RUN git config --global --add safe.directory /site\
  && hugo mod tidy

CMD ["hugo", "server", "--bind", "0.0.0.0", "--baseURL", "http://localhost", "--logLevel", "debug", "--disableFastRender"]

