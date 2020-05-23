# Lucky Hasura Docker

The goal of this project is to provide fantastic backend boilerplate using Lucky, Hasura, and Docker. The problem I wanted to solve can be demonstrated by a quick image search for [backend vs frontend joke](https://google.com/search?q=backend+vs+frontend+joke).

The basic idea is that you'll have a Postgres database which you can talk to in one of two ways. If you post GraphQL queries to `api.example.com/v1/graphql` then [Hasura](https://hasura.io/) will handle the request. If you make any other request to `api.example.com` then [Lucky](https://luckyframework.org/) will handle the request. Thus Hasura is responsible for GraphQL, and Lucky is responsible for business logic and managing your database as it will be responsible for the object model. Of course, that's just one way to configure it. Since we're using [Traefik](https://containo.us/traefik/) to handle the reverse proxy, it's pretty easy to route any shape of request to any server we like.

[Docker](https://www.docker.com/why-docker) is used in development, testing, and production so that developers work in a consistent environment as each other, and so that we can build, test, and deploy stateless production images to a Docker Swarm.

## Getting Started

When a developer encounters a new tool or library they tend to do so with one of three attitudes:

1. What's all the fuss about X?
2. What's the minimum I can learn/invest in order to get this running and move on?
3. I want to become proficient in X, where are some good detailed guides that can show me the ropes?

For each of these audiences I've provided a different resource. In the same order as above they are:

1. A _TL;DT_ (too lazy; didn't type) guide on [YouTube](https://www.youtube.com/watch?v=H2YpigiNxjs).
2. A TL;DR guide [in this repo](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/TLDR.md).
3. A full [GUIDE.md](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/GUIDE.md) also in this repo.

So feel free to watch the YouTube video to get a flavor and follow the `TLDR` to try it out. Once you've decided to actually adopt this as a foundation for your own app, you should read the full `GUIDE`. This is not a dependency, it is boilerplate. That means in order for you to customize your app you'll need to understand how your app works and that means reading this guide as well as guides on Docker, Hasura, Lucky, Traefik and so on according to your interest in customizing those pieces.

## Version Control

I want to make it easy to read one of these markdown files and know whether or not the exact words you are reading were tested. I hate following a tutorial and seeing instructions that don't match reality. So if you read the `TLDR` here from a tagged point in the commit history, you can be confident that every major and minor version has actually been tested from beginning to end (see the [semver](https://semver.org/) guide if you don't know what major and minor means here). I bring up a totally new Gitlab repo and DigitalOcean droplet and then follow the instructions verbatim before I tag a commit of this repo. I also try to keep the `GUIDE` and `TLDT` in sync with `TLDR`.

For the first little while, things will be `v0.y.z` which means potentially breaking changes from `y` to `y`. I'll update `z` when I need to correct something small like a typo, so those versions won't be fully tested.

## Roadmap

This is a work in progress. Please open up an issue to discuss how it can be improved! Here are some of my thoughts at the moment, I'll be motivated to work on them according to the interest that I hear expressed by 'the community' should one ever form.

- CLI to do the scaffolding work, support old and new Lucky projects.
- Support other CI/CD tools like Github Actions, CircleCI, TravisCI, and so on.
- Add docs for Heroku, AWS, and other kinds of hosting providers.
- Other SSL options like Let's Encrypt.
- Add / improve monitoring swarm .... might need to take swarmprom in house.
- Support for other orchestration options like Kubernetes.

I'm very open-minded about this and would love to see this project go in a better direction from this rudimentary little beginning.

## Disclaimer

This project is in a pre-release stage. That means, to my knowledge, it is not in use in any actual production systems. Some day I hope it will be a battle-hardened backend framework but right now it's just a set of ideas.
