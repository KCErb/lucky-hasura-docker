# LHD

Hi there, this is a quick writeup explaining a particular tech stack that I've been working on. The basic idea here is that I want my frontend apps to talk to the (Postgres) database via [GraphQL](https://graphql.org). [Hasura](https://hasura.io) is a great tool for painlessly adding a GraphQL layer to a Postgres database. As such, Hasura doesn't actually handle business logic. [Lucky](https://luckyframework.org) is a great web framework that we can use to handle the business logic as well as anything else not GraphQL related.

If you're not familiar with any of the links above, please click and read since this tutorial is more about putting them together and less about why they are a good choice or how to use them.

And how is it that we put it all together? Docker.

Yes, that's Docker with a period, not an exclamation point. I'm not gonna lie, this project has taken a little skip out of my step with respect to Docker. The rainbows may have faded, but in their place is a pot of steel ingots, not as shiney as gold but still valuable and very useful.

There are two sections of this writeup, the first is on using Docker to get these tools up together in development, the second is on doing it all in production (with Docker Swarm). As usual, development is just the tip of the iceburg. Much of what's written here and available in the example project is dedicated to having really nice production-grade automated deployment.

# Lucky + Hasura via Docker in Development

## Lucky CLI

The first thing you'll need to do is get a Lucky project scaffolded using the CLI tool. Here's a link to the docs for how to do that on macOS and Linux (window's support has not landed for Crystal yet):

[luckyframework.org/guides/getting-started/installing#install-lucky-cli](https://luckyframework.org/guides/getting-started/installing#install-lucky-cli)

With that tool in place, you can now start a project with `lucky init` as per the next page of documentation: [luckyframework.org/guides/getting-started/starting-project](https://luckyframework.org/guides/getting-started/starting-project). The dialog will ask you if you want to do a "Full" app or an "API only" app. You can do either one, the example app uses an API only app for now.

The next step on that page tells you to run `script/setup` but this is where we part from the Lucky docs. Instead of running this app in our local environment, we'll be running it in Docker.

## My Repo

Getting all the configuration with Docker can be challenging, so I'm providing a repository that contains a bunch of Docker-related files. It has everything you need to use Docker in development and deployment, so if you don't want the deployment stuff you'll have to remove it yourself (until someone wants it out enough to submit a PR). Here's a link to the repo:

[github.com/KCErb/lucky-hasura-docker](https://github.com/KCErb/lucky-hasura-docker)

I'm going to refer to this repo as LHD (lucky-hasura-docker) throughout this tutorial, so heads up!

LHD has "releases" intended to go along with these blog posts. These are a kind of promise that I've actually run through / updated this post to match the latest documentation on Lucky version x.x.x and Hasura y.y.y. So be sure to use the release version that matches the post version.

LHD has directories and files that you should add to your Lucky project, but you can't just drop them in. So let's walk through and get a basic understanding of what we're adding here.

### LHD Search and Replace

The repo has a few "variables" that you should use search and replace to customize to your project. They are:

* GITLAB_USER
* GITLAB_REPO_NAME
* PROJECT_NAME
* SWARM_NAME

The first two are used in commands like `git clone` to pull down your repo. `PROJECT_NAME` and `SWARM_NAME` are up to you. They might be the same as `GITLAB_REPO_NAME` in my case my repo name is too long, so I came up with a shorter name but used the same for both project and swarm.

After you've replaced those 4 with something specific to your project we'll be good to go!

### Docker Tools

#### docker-compose

The first directory in LHD that we should discuss is simply called `Docker`. Before we dig in here, first I want to recommend that you read Docker's getting started guide

[docs.docker.com/get-started](https://docs.docker.com/get-started/)

I trust that you'll get to know Hasura and Lucky on your own, but Docker sometimes has a "set it and forget it" feeling and while that's kind of the point, I highly recommend a basic understanding of the tools since it's the glue holding this all together so nicely.

Before going on, check if you understand this sentence: this is a multi-container project specified as services in several `docker-compose` files, so we'll be using `docker-compose` to build our images, bring up the services and, in production, deploy to a swarm. If you're comfortable with that language, read on, if not, go back and read the docs.

#### docker-sync

Once you have that down, it's time to hit you with some bad news: Docker is slow on macOS. The solution is to use `docker-sync` which is a 3rd-party Ruby app. It's really necessary if you'll have anyone developing on macOS and doesn't interfere with normal Linux development. It's a great solution for a problem I wish didn't exist. If you've never heard of it take a quick read over there and come back:

[docker-sync.io](http://docker-sync.io/)

LHD has a `docker-sync.yml` in it already and a `.ruby-version` but you'll need to install Ruby on your local machine as well as `docker-sync`.

#### up

The last tool I'd like to introduce you to is `up`. You don't need this if you are already comfortable using Docker in development, in that case you probably already have your own workflow and you can use it instead. For the rest of us, `up` is simply a tool that keeps an eye on what local files were used to build a Docker image and takes note if any of them change. That way, instead of getting into the habit of starting our project with `docker-compose up` which can lead to surprises if you forget that you needed to rebuild your image(s), you can get in to the habit of having an `up.yml` and then simply calling `up`.

This is a lesser-known tool because it is new. So far it seems to be taking a role as a stepping-stone instead of a production tool, but it's been fine for me so far:

[github.com/paulcsmith/up](https://github.com/paulcsmith/up)

### Docker Files

Now with all of that introduced, we can talk about the files provided in `LHD/Docker`. There are several `docker-compose` files which in development are called by `up` (see the `up.yml`) as
`docker-compose -f Docker/docker-compose.yml -f Docker/docker-compose.dev.yml` (we'll talk about the other `docker-compose` files later in the Production section of this writeup). Please take a look at those as they define the core services of the project: `postgres`, `lucky`, and `hasura`. You'll notice in the `.dev` file some `docker-sync` config and some reliance on `script/*` files. Hopefully most of what is here is self-explanatory insofar as these things go. If not, let me know and we can certainly improve this section!

As for the directories in here, we have `traefik` and `prometheus-swarm` which are used in production and `lucky` which is where the `Dockerfile`s reside for creating the production and development images. We want these images to be nearly identical and ideally only use one. The catch is that while `production` is stateless, `development` is syncing from local machine to container. This mainly comes up in the final lines of `Dockerfile.prod` where we build the release version of the server binary compared to the `Dockerfile` where we simply use `lucky watch` to constantly rebuild a less-optimized version in development.

Besides these last few lines, we don't want these files to diverge! Shouldn't there be a better way to guarantee this? Yes, but not without having to have a base image which then two more images would build from. That would be cleaner, and perhaps worth it in the long run, but until then, this is the solution I've settled on.

## Scripts folder

Now let's dig into all of the scripts that try to make this whole system reproducible and easy to use. In LHD, the `script` directory has two subdirectories: `docker` and `functions`. The `functions` are functions that are called by more than one script. The `docker` scripts are scripts we copy into docker images and run from within the container.

Now let's run through the scripts:

### script/up

The first we'll look at is `up`. This brings up the `docker-sync` containers and the services with `up`. It then sets up the database once postgres is ready (thanks to `wait-for-postgres`) including migrations and seeding the database. And after that it sets up Hasura to let us handle the migrations.

The main ideas to notice here are

1. In a Docker stack, the best way to know you can send a command to a container is to ping that container with some kind of readiness query on loop until it responds. It surprised me when I first learned this, so you may want to read the rationale yourself:

    [docs.docker.com/compose/startup-order](https://docs.docker.com/compose/startup-order/)

    So you'll see a lot of that in these scripts.

2. Hasura is an awesome tool that supports a lot of use cases! In ours, we want Lucky to manage our migrations so we need to turn off "migrations mode" this can be done with a simple API call ... once Hasura is ready to respond. This can take some time since Hasura won't start itself until it knows postgres is ready (it has it's own wait-for-postgres loop running under the hood too).

Once the services are up, and the database is ready, and Hasura is in the right mode, we should get a simple message: `✔ All done.`.

### script/down

This script does the reverse of `up`. It tears down the volumes and services so that you go back to a clean slate. It's expected that normal development cycle will use `script/up` and if things need to get reset a quick `script/down && script/up` should do the job. Keep in mind though that the `up.yml` specifies when that `script/up` command will rebuild the Lucky image which can be time consuming. So you may need to keep an eye on that.

### Other Scripts

The other scripts are all for production, so you can read about them later or just delete them.

## CI

The last thing to check if you can bring up and down your project as described is to push it to your favorite git host and have tests run automatically. LHD uses gitlab, so it includes a `.gitlab-ci.yml` which is vastly over complicated if you're not using gitlab to build and deploy I recommend you make your own `.gitlab-ci.yml`, it'll be worth your while:

[docs.gitlab.com/ee/ci/introduction](https://docs.gitlab.com/ee/ci/introduction/)

# Lucky + Hasura via Docker in Production

OK, now for the juicy stuff. The above is nice and all, but we can go way further. We can use `traefik` to put up a load-balanced reverse-proxy to our Docker Swarm. We can have Lucky queries going to some containers and GraphQL queries going to others. We're talking actual microservices here. While messing around with this, I once had my Lucky service down for days and didn't notice because I was just testing the GraphQL and had no other alerts setup. These things are actually independent. I love that. And with a few key strokes we can scale up and down to match needs. Maybe we have a bunch of mobile users hammering the GraphQL endpoints but the Lucky server is kinda bored. No problem, just scale up that Hasura service! To keep an eye on everything, a separate swarm for monitoring tools under the `prometheus` umbrella are available and we bring that all online with commandline one-liner.

What's more is Gitlab can do the heavy lifting for us with respect to building and tagging images. If there's an issue with a deployment on staging, we can use the rollback script to go back to a previous image and database state since the images are tagged by git commit. I'm even experimenting with two kinds of migrations: "additive" and "subtractive" to go for a perfect zero downtime history. If you're interested in these ideas read on, the main motivation for building all of this was to achieve devops Nirvana and if the below isn't it, it's close enough that I think the community can get it the rest of the way there. We'll have to sacrifice a bit though, some of the details of a real production deployment get a little hairy but it's worth it in the end.

## Staging and Production Servers

The first thing we need to do is get some servers up somewhere. It's not terribly important how you choose to do this, so please feel free to skip to the next major heading if you've got your own plan. Otherwise, I'll go ahead and describe how I did this with [DigitalOcean](https://www.digitalocean.com) and [Cloudflare](https://www.cloudflare.com).

With DigitalOcean we can spin up a little hobby server for $5 per month. I don't want to go too far astray from the topic here, so I'll leave it to you to do a little googling and learn how to use it. I will point out however that the [DigitalOcean 1-click Docker app](https://marketplace.digitalocean.com/apps/docker) is a pretty convenient starting place. For a real project, I'm a fan of the idea of having a dedicated "staging" server, so later it'll come up that we in fact have two servers here with slightly different purposes.

Next we can do our DNS and security certificates through Cloudflare for free. I won't go into more detail since I want to let cloudflare maintain their own docs, but this might be a good starting place: [support.cloudflare.com/hc/en-us/articles/End-to-end-HTTPS-conceptual-overview](https://support.cloudflare.com/hc/en-us/articles/360024787372-End-to-end-HTTPS-with-Cloudflare-Part-1-conceptual-overview).

I will warn though that it's easy to end up in an infinite redirect loop if your ssl settings aren't quite right. For my setup, under the SSL tab I'm using "Full (Strict)" on the Universal SSL certificate. I created origin certificates and put them into `etc/certs/cloudflare.cert` and `etc/certs/cloudflare.key`. And I'm not using their automatic http => https redirect or HSTS, my http redirect is handled by another service (Traefik).

Lastly, I recommend ssh'ing into the server (take a minute to read how to set that up securely by the way by doing things like removing password-based ssh access) and then doing two things:

1. `ufw allow`: Since we'll be serving from here we'll need to `ufw allow` a couple of ports: 80 and 443. If you're using the 1-click app 8083 is denied by default and that's fine.
2. Set up a "Deploy Token" under Settings > Repository. You can use this to log into gitlab on the server and get access to both the git repository as well as the Docker registry provided by Gitlab. [docs.gitlab.com/ee/user/project/deploy_tokens/#usage](https://docs.gitlab.com/ee/user/project/deploy_tokens/#usage)

## More Scripts

OK, let's take a look at the production/deployment scripts in LHD.

### deploy

The `deploy` script is a good place to start here. The first thing you'll notice is that this thing relies on a small pile of environment variables. The expectation is that we are deploying to a server that has these on it. But sometimes we need to test our production setup locally, so the script provides some dummy values.

The next thing to notice here is that we can pass an argument. If there is no argument or if its value is `add` we run in 'additive deploy' mode and if it is anything else we run in 'subtractive deploy' mode. The idea here is that we can choose to have each deployment only add or subtract columns from the database. The difference between the two is simply the order we migrate the database and update the code. If we added columns / tables, then we need to migrate the database before updating the code since the old code won't ask for columns that didn't exist before. The reverse is true if we take away columns / tables.

NOTE: The first deployment has to "update" code before migrating because that function gets the stack going (i.e. starts services). So on the very first deploy you might call `script/deploy first` for example and on subsequent deploys where the db/project is growing in complexity you'd just call `script/deploy`.

### build

This script is mostly going to be run by our `CD` setup described later on. It's job is simply to run a `docker-compose build` with the right settings to get some images built based on current code. We'll come back to this in a minute, but it's important to note here that production images are tagged with the first 8 characters of the current commit SHA.

### rollback

The rollback script requires one argument: the version you want to rollback to. Since our images are tagged by commit SHA that means providing the first 8 characters of the commit SHA you want to go back to. If you've checked out that commit in the terminal, this is just the output of `git rev-parse --short=8 HEAD`.

You can also provide a second argument which works just like `deploy`. If it was an additive deploy that you're rolling back, then the argument should either be `add` or not provided.

NOTE: this one is a work in progress. There is a `rollback` function which spins up a container and runs `db.rollback` calls, but at the moment it just rolls back one migration. If your deploy had two for example, then you'd want to pass that as an argument. This can probably be automated now that I have a commit SHA, but I haven't implemented this yet so some manual rolling back will be needed in that case.

### Health Checks

In deployment we'll be using docker swarm so you may also notice the `script/docker/*healthcheck` files. These are little scripts that run every so often and make sure the services are healthy. You can read more about them here: [docs.docker.com/compose/compose-file/#healthcheck](https://docs.docker.com/compose/compose-file/#healthcheck).

## Docker Swarm

On the server, you'll need to start a swarm first (see [the Docker guide](https://docs.docker.com/get-started/) if you're not sure about this), but after that you can just run `script/deploy init` as described above and everything should kick off on its own.

Please do have a look at `docker-compose.prod.yml`. You'll see again some of those env variables that are needed to get this started being passed into containers. You'll also see some `deploy` keys being used which start us off with just 1 replica of each service. If you have trouble with the first deploy, the issue may be resolved by double checking that you understand this one file.

You'll notice that the `update_code` function calls the following to deploy:

`docker stack deploy -c Docker/docker-compose.yml -c Docker/docker-compose.prod.yml -c Docker/docker-compose.traefik.yml SWARM_NAME --with-registry-auth` so you'll want to understand those files. Note also that `with-registry-auth` flag is there so that you can pull images from the registry. We'll get more into that in the CD section.

### Traefik

Now we'll turn our attention to connecting the wide world to our Lucky and GraphQL services. The first thing you'll need is a domain name and security certificates so that you can host a `https://example.com`. I'll assume that you took care of this back at the DigitalOcean/Cloudflare section. The second thing you'll need is a reverse proxy so that you can route requests to different services based on the address of the request. In the LHD example, if someone requests `api.example.com/v1/graphql` that request will go to Hasura and if it makes any other `api.example.com` request they'll go to Lucky. This is accomplished by routing `api.example.com` requests to the server (via CNAME records in Cloudflare) and using a neat little docker-ready reverse proxy called [Traefik](https://traefik.io).

Once you've got those CNAME records up, let's take a look at the Traefik config. There are two parts, let's start with `docker-compose.traefik.yml` this file just defines the Traefik service. Some of the config is here and some of it is in `Docker/traefik/traefik.toml`. I think all of it can go in the docker-compose, but I feel like a nice separation of concerns is putting per-service config in the docker-compose and traefik-wide config into this `.toml`.

As we look through the YAML, the first thing we see is that it adds some traefik rules to the hasura and lucky services. You'll almost certainly want to change these to suit your own tastes, so I recommend you read their docs, for example: [docs.traefik.io/routing/overview](https://docs.traefik.io/routing/overview/).

The next thing I want you to notice is the service called `traefik-docker-link`. This piece is needed to avoid a security issue which arises from Traefik needing access to the docker socket and that giving it potential admin priviledges. The Traefik docs point to a lot of good resources on this issue but it's hard to link specifically to the security part of the page so you'll have to read: [docs.traefik.io/providers/docker](https://docs.traefik.io/providers/docker/) if you want to dive in. One resource they point to is the Docker docs: [docs.docker.com/engine/security/security/#docker-daemon-attack-surface](https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface).

The last thing I'll point out here is a comment found in a few places throughout the project: `HTTPS_SWITCH`. This is for running a production setup in development. Unless you want to go to the trouble to convince your local system that https is a thing you can do, you'll need to comment out the lines marked here in order to `docker stack deploy` locally with Traefik in place. It's kind of a hassle, but boils down to just commenting out a the lines marked by this "switch".

Now let's look at the TOML file. It just defines the HTTPS entrypoint and the HTTP redirect as well as providing the docker link so that we can do some service discovery in that `docker-compose.traefik` file.

If you have any other questions about this aspect of things, try to read through and understand the docker-compose setup we have here. There's a lot going on and it took a long time to figure out with lots of debugging. Hopefully for you it'll just work.

## Monitoring with Prometheus

The last directory to point out here is called `prometheus-swarm`. For really excellent application monitoring you can either pay money or use this fairly complex docker swarm for free. I'm really glad that someone else already solved this problem: [github.com/stefanprodan/swarmprom](https://github.com/stefanprodan/swarmprom.git). In this repo I've adapted that repo somewhat to fit the needs of this project.

This toolset can monitor your services, give you real-time graphs looking at memory usage, CPU usage, and much more across services and nodes, it can even send you Slack notifications when an alert is triggered (like memory getting too high). Lots of good stuff in here but I'm going to skip over it all since from my perspective (and as noted in the README), it can be as simple as

```terminal
cd Docker/prometheus-swarm
docker stack deploy -c docker-compose.yml prometheus_swarm
```

But do be careful, this thing needs a bit of memory and if you're using the DigitalOcean $5 server you might not have enough room for Lucky, Hasura, and this monitoring stack all in the same tiny box.

I feel like I should write more since there's a bunch going on under the hood here, but I'll let those interested read the `docker-compose` file, it has all the details. In production I have another CNAME record for `grafana.example.com` and I can do my monitoring from there.

## CD

The `.gitlab-ci.yml` file provided here tests the code, then builds an image, then tags and pushes it to the registry so that it can be reused on subsequent builds, and then finally deploys it to the server. Give those steps a quick read to understand what that's all about. The most unique thing perhaps is the `push` step where we tag an image both with a commit reference via the gitlab-provided variable `$CI_COMMIT_SHORT_SHA` as well as the branch name via `$CI_COMMIT_REF_NAME`. The result is that the most recent / current image is tagged by branch name and by commit reference. On the next build, that can be used as a cache reference to save build time. This idea and many other things are borrowed / adapted from [blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices](https://blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices/).

Many of the variables used here are provided by gitlab such as `$CI_COMMIT_REF_NAME` but not all. Let's head on over to "Settings > CI/CD" under the "Variables" heading. There you'll need to create four variables, 2 each for staging and production. `GITLAB_PRODUCTION_KEY` and `GITLAB_STAGING_KEY` contain the SSH private keys of ssh keypairs where the public key is already on the production or staging servers. This gives us ssh access for the deploy step. The IP addresses are also made into variables as `PRODUCTION_SERVER_IP` and `STAGING_SERVER_IP`.

With those things in place, you'll be able to deploy to the server automatically whenever a commit lands in `master` or `staging`. That is of course assuming you have server's setup properly. I'm assuming here that you've already run `script/deploy init` on the server manually which will only work if everything is set up properly.

# Conclusion

If you read through all of the above and it all worked perfectly: awesome! Let me know to motivate me to keep this project up to date.

I'm afraid it's quite likely though that somewhere along the way some bump came along that you just couldn't resolve or that proved me wrong. If so, please open an issue in the LHD repository. I'd love to fix mistakes and improve on the write up. I might not agree that a section needs to be written on how to do X, but I'm always happy to have links to documentation and other write ups that explain some aspect in more detail.
