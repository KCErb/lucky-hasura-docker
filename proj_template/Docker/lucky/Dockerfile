FROM luckyhasuradocker/lucky-crystal:l0.21.0c0.34.0-alpine

# Don't default to root
RUN addgroup -g 1000 -S lucky && \
    adduser -u 1000 -S lucky -G lucky
USER lucky

COPY --chown=lucky:lucky shard.yml /home/lucky/app/
# RUN chown -R lucky:lucky /home/lucky/app
WORKDIR /home/lucky/app

# After this point the file differs from prod
RUN shards install
CMD ["lucky", "watch"]
