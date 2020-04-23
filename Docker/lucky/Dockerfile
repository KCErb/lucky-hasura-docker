FROM luckyhasuradocker/lucky-crystal:l0.21.0c0.34.0

RUN mkdir /data
WORKDIR /data
COPY . /data

# After this point the file differs from prod
RUN shards install
CMD ["lucky", "watch"]
