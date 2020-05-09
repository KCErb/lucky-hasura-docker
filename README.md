# Lucky Hasura Docker

The goal of this project is to provide fantastic backend boilerplate using Lucky, Hasura, and Docker. The problem I wanted to solve can be demonstrated by a quick image search for [backend vs frontend joke](google.com/search?q=backend+vs+frontend+joke).

The basic idea is that you'll have a Postgres database which you can talk to in one of two ways. If you post GraphQL queries to `api.example.com/v1/graphql` then [Hasura](https://hasura.io/) will handle the request. If you make any other request to `api.example.com` then [Lucky](https://luckyframework.org/) will handle the request. Thus Hasura is responsible for GraphQL, and Lucky is responsible for business logic and managing your database as it will be responsible for the object model. Of course, that's just one way to configure it. Since we're using [Traefik](https://containo.us/traefik/) to handle the reverse proxy, it's pretty easy to route any shape of request to any server we like.

[Docker](https://www.docker.com/why-docker) is used in development, testing, and production so that developers work in a consistent environment as each other, and so that we can build, test, and deploy stateless production images to a Docker Swarm.

## Getting Started

I've included two guides. If you are newish to production / backend development, you should read the lengthy and detailed 'GUIDE.md'. If you are new to Hasura or Lucky or Docker you'll probably want to read the full `GUIDE` too. It might be a little boring in places for you if you are experienced, but it might also have some time-saving details.

If you are an old hand, you might want to give the `TLDR.md` a shot. It's as brief as I could make it. Many of the steps there will be automated in a future version of this project with a nice CLI tool. Until then, I'm afraid you'll need to read, copy, paste, and type.

If you want to see what this project is about, but all this stuff about "reading" and "typing" seems like too much, you might want to try the _TL;DT_ (too lazy; didn't type) version on [YouTube](https://www.youtube.com/watch?v=H2YpigiNxjs).

## Version Control

I want to make it easy to read one of these markdown files and know whether or not the exact words you are reading were tested. I hate following a tutorial and seeing instructions that don't match reality. So if you read the `GUIDE` here from a tagged point in the commit history, you can be confident that every major and minor version has actually been tested from beginning to end (see the [semver](https://semver.org/) guide if you don't know what major and minor means here). For the first little while, things will be `v0.y.z` which means potentially breaking changes from `y` to `y`. I'll update `z` when I need to correct something small like a typo so those versions won't be tested.

I can't promise that I'll release a TL;DT with every minor version ... but we'll see.

## Roadmap

This is a work in progress. Please open up an issue to discuss how it can be improved! Here are some of my thoughts at the moment, I'll be motivated to work on them according to the interest that I hear expressed by 'the community' should one ever form.

- CLI to do the scaffolding work, support old and new Lucky projects.
- Support other CI/CD tools like Github Actions, CircleCI, TravisCI, and so on.
- Add docs for Heroku, AWS, and other kinds of hosting providers.
- Other SSL options like Let's Encrypt.
- Add / improve monitoring swarm .... might need to take swarmprom in house.
- Support for other orchestration options like Kubernetes.
- Support for other sync options, for example, just editing directly in the container (VSCode makes this easy).

I'm very open-minded about this and would love to see this project go in a better direction from this rudimentary little beginning.

## Disclaimer

This project is in a pre-release stage. That means, to my knowledge, it is not in use in any actual production systems. Some day I hope it will be a battle-hardened backend framework but right now it's just a set of ideas.
