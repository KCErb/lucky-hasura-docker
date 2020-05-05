# Lucky Hasura Docker

The goal of this project is to provide awesome backend boilerplate using Lucky, Hasura, and Docker. The problem I wanted to solve can be demonstrated by a quick image search for "backend vs frontend joke". This boilerplate provides a backend that any frontend can query to provide the desired UI/UX.

* quick overview of postgres <=> Hasura <=> GraphQL queries + postgres <=> Lucky <=> other business logic requests
* sell it a little with some nice screenshots?


## Usage

I've included two guides. If you are newish to production / backend development, you should read the lengthy and detailed 'GUIDE.md'. If you are new to Hasura or Lucky or Docker you'll probably want to read the full GUIDE too. It might be a little boring in places for you if you are experienced. If you are an old hand you might want to give TLDR a shot. It's as brief as I could make it. Many of the steps there will be automated in a future version of these docs.

Speaking of versions. I want to make it easy to read one of these markdown files and know whether or not the exact words you are reading were actually tested on the exact version of the template files provided. Thus I've implemented the following tag / release scheme:

## Roadmap

- CLI to scaffold new lucky project
- Support Github Actions, TravisCi, CircleCI and so on
- Add docs for AWS and other providers
- Add / improve monitoring stuff .... might need to take swarmprom in house

## Disclaimer

This project is in a pre-release stage. That means, to my knowledge, it is not in use in any actual production systems.