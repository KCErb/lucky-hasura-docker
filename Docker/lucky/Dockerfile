FROM crystallang/crystal:0.34.0

RUN apt-get update && \
  apt-get install -y libnss3 libgconf-2-4 chromium-browser build-essential curl libreadline-dev libevent-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev git golang-go postgresql postgresql-contrib locales && \
  # Lucky cli
  git clone https://github.com/luckyframework/lucky_cli /usr/local/lucky_cli && \
  cd /usr/local/lucky_cli && \
  git checkout v0.20.0 --quiet && \
  shards install && \
  crystal build src/lucky.cr -o /usr/local/bin/lucky && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install shards - that means we need to rebuild to update shards
RUN mkdir /data
COPY . /data
RUN rm -rf /data/bin/* /data/lib/*
WORKDIR /data
COPY shard.* ./
RUN shards install

# Build health check
RUN crystal build script/docker/lucky_healthcheck.cr -o script/docker/lucky_healthcheck

EXPOSE 5000

# After this line dev and prod Dockerfiles differ
RUN crystal build src/start_server.cr -o bin/server
CMD ["/data/script/docker/wait-for-postgres", "lucky watch"]
