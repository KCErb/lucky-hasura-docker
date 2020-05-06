# Lucky Hasura Docker

The goal of this project is to provide awesome backend boilerplate using Lucky, Hasura, and Docker. The problem I wanted to solve can be demonstrated by a quick image search for "backend vs frontend joke". This boilerplate provides a backend that any frontend can query to provide the desired UI/UX.

The basic idea is that you'll have a Postgres database which you can talk to in one of two ways. If you post GraphQL queries to `api.example.com/v1/graphql` then Hasura will handle the request. If you make any other request to `api.example.com` then `Lucky` will handle the request. Thus Hasura is responsible for GraphQL and Lucky is responsible for business logic and managing your database as it will be responsible for the object model.

And all of this is running in Docker.

## Usage

I've included two guides. If you are newish to production / backend development, you should read the lengthy and detailed 'GUIDE.md'. If you are new to Hasura or Lucky or Docker you'll probably want to read the full GUIDE too. It might be a little boring in places for you if you are experienced, but it might also have some time-saving details. If you are an old hand you might want to give the `TLDR.md` a shot. It's as brief as I could make it. Many of the steps there will be automated in a future version of this project with a nice CLI tool. Until then, I'm afraid you'll need to read, copy, and paste.

Speaking of versions. I want to make it easy to read one of these markdown files and know whether or not the exact words you are reading were tested. I hate following a tutorial and seeing instructions that don't match reality. So if you read the GUIDE here from a tagged point in the commit history, you can be confident that those instructions have actually been tested. I'll also try to keep the TLDR in sync.

## Roadmap

This is a work in progress. Please open up an issue to discuss how it can be improved! Here are some of my thoughts at the moment, I'll be motivated to work on them according to the interest that I hear expressed by 'the community' should one ever form.

- CLI to do the scaffolding work, support old and new Lucky projects.
- Support other CI/CD tools like Github Actions, CircleCI, TravisCI, and so on.
- Add docs for Heroku, AWS, and other kinds of hosting providers.
- Add / improve monitoring swarm .... might need to take swarmprom in house.
- Support for other orchestration options like Kubernetes.
- Support for other sync options like just editing directly in the container (VSCode makes this easy).

I'm very open-minded about this and would love to see this project go in a better and better direction from this little beginning.

## Disclaimer

This project is in a pre-release stage. That means, to my knowledge, it is not in use in any actual production systems. Some day it will be a battle-hardened backend framework but right now it's just a set of ideas.
