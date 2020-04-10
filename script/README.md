# Purpose

This directory contains scripts for starting and stopping local dev environment (up and down) and for deploying / rolling back production.

The `docker` dir contains scripts which should be run in a docker container, other scripts will call these via `docker exec` for example. They are built into the image.

The `functions` dir is for functions to include in main scripts.

# Deployment Testing

* HTTPS_SWITCH is a comment flag for commenting out https stuff for local testing
* deploy script exports some dummy env vars
* migrations.env in Docker handles the migration runner
* readme in prometheus tells how to launch prometheus in development
