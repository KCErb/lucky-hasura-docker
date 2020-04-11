# Purpose

This directory contains scripts for starting and stopping local dev environment (up and down) and for deploying / rolling back production.

The `docker` dir contains scripts which should be run in a docker container, other scripts will call these via `docker exec` for example. They are built into the image.

The `functions` dir is for functions to include in main scripts.

# Deployment Testing

The `deploy` script is used to actually put code into production. But if it's not working, then you'll want to "deploy" locally for debugging. This presents a challenge since locally you'll not be running over HTTPS but some of the production configs require it. The solution I've come up with for now is to mark a few sections with "HTTPS_SWITCH". You should just need to comment out the code in that section and if you read it should be clear if it's just 1 line or a group, but it's always a continuous section. For discontinous sections I've repeated the flag.

Furthermore:

* deploy script exports some dummy env vars
* migrations.env in Docker handles the migration runner
* readme in prometheus tells how to launch prometheus in development
