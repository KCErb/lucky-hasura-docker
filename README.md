# LHD

Hi there, this is a quick writeup explaining a particular tech stack that I've been working on. The basic idea here is that I want my frontend apps to talk to the (Postgres) database via [GraphQL](https://graphql.org). [Hasura](https://hasura.io) is a great tool for painlessly adding a GraphQL layer to a Postgres database. As such, Hasura doesn't actually handle business logic. [Lucky](https://luckyframework.org) is a great web framework that we can use to handle the business logic, database migrations, and anything else not GraphQL related.

If you're not familiar with any of these tools, please click on the links above and read since this tutorial is more about putting them together and less about why they are a good choice or how to use them. Much of the following assumes you have at least a cursory knowledge of GraphQL, Hasura, and Lucky.

And how is it that we put it all together? Docker.

Yes, that's Docker with a period, not an exclamation point. I'm not gonna lie, this project has taken a little skip out of my step with respect to Docker. The rainbows may have faded, but at the end is a pot of steel ingots, not as shiney as gold but still valuable and very useful.

There are two sections of this writeup, the first is on using Docker to get these tools up together in development, the second is on doing it all in production (with Docker Swarm). As usual, development is just the tip of the iceburg. Much of what's written here and available in the example project is dedicated to having really nice production-grade automated deployment. So if you don't plan to use Docker in production, that's fine, I think the first half will still be useful, but be aware that that wasn't my intent when creating this project initially. If there is interest and PRs I'd be happy to make this more development-only friendly.

# Lucky + Hasura via Docker in Development

Some of the tools here will be on your local machine, others will be in the docker image. Let's start with the things you need locally in order to get this up.

## Lucky CLI

The first thing you'll need to do is get a Lucky project scaffolded using Lucky CLI. Here are links to the docs for how to do that on [macOS](https://luckyframework.org/guides/getting-started/installing#install-lucky-cli-on-macos) and [Linux](https://luckyframework.org/guides/getting-started/installing#install-lucky-cli-on-linux) (Windows support has not landed for Crystal yet).

With that tool in place, you can now start a project with `lucky init` as per the next page of documentation [Starting a Lucky Project](https://luckyframework.org/guides/getting-started/starting-project). Please notice that though we are generating the scaffold locally, everything else will be done in the Docker container. This could lead to some confusion since, for example, your local crystal might be a different version than that in the Docker container. Be careful to make sure they match for this one step, and from here on your local crystal shouldn't really matter. 

`lucky init` will have you name your app and then the dialog will ask you if you want to do a "Full" app or an "API only" app. You can do either one, the example app uses an API-only app for now. You'll then be asked if you want to generate authentication. The answer is yes, we'll definitely want authentication helpers since Hasura uses JWT. Here's a one-liner that does the same:

    lucky init.custom foo_bar --api

After that, the project is created and you're told to do things like `check database settings in config/database.cr`. We'll **not** be following those steps because we are more interested in this running in Docker than on our own machine. (Notice we'll not even be installing Crystal locally.)

## LHD

Getting all the configuration with Docker can be challenging, so I'm providing this repository which contains a bunch of Docker-related files. It has everything you need (and then some) to use Docker in development *and* deployment, so if you don't want the deployment stuff, you'll have to remove it yourself (until someone wants it out enough to submit a PR). Here's a link to the repo in case this README and the source get separated:

[github.com/KCErb/lucky-hasura-docker](https://github.com/KCErb/lucky-hasura-docker)

I'm going to refer to this repo as LHD (lucky-hasura-docker) throughout the tutorial, so heads up!

I plan to use tags and 'releases' and a 'tested on/by' table to communicate clearly how up-to-date this repo is. It'll probably take a couple of releases to get right, so hang with me if this is the first one or two :). When it's done, you should be able to clearly see 'this copy of the README has been tested on macOS with lucky 0.21.0 crystal 0.34.0 Hasura 1.1.1 Docker Engine 19.03.8' and that copy of the repo will be referencing those versions in its compose files.

LHD has directories and files that you should add to your Lucky project, so go ahead and clone that down into a separate local directory for a start. We'll be modifying it and then moving files from LHD to the lucky project.

### LHD Step 1: Search and Replace

This repo has a few "variables" that you should use search and replace to customize to your project. They are:

* `GITLAB_USER`
* `GITLAB_REPO_NAME`
* `PROJECT_NAME`
* `SWARM_NAME`

The first two are used in git commands (like `git clone`) to pull/push your project around (i.e. `gitlab.com/<GITLAB_USER>/<GITLAB_REPO_NAME>`). 

(Oh yeah, did I mention that we'll be using Gitlab in this tutorial as well? That also is tied in with the deployment setup here. In the future if someone wants to pitch in instructions for doing this with a mixture of tools (Github and CircleCI for example), I'll be happy to discuss the best ways to make this more accessible to a wider audience.)

`PROJECT_NAME` and `SWARM_NAME` are up to you but for a start you'll probably want them to be the same as `GITLAB_REPO_NAME`. The key is that these two names you sometimes have to type, so if your repo name is long like `lucky_hasura_docker` you might want your swarm and project names to be `lhd` or if you want them to be separate `lhd` and `lhd_swarm`. **Also** in many places I have docker configs like `SWARM_NAME_internal` so if your names have dashes you'll end up with mixed names `cool-app_internal`. If that bothers you, you might want to stick with underscore names. (Not to mention that in Crystal land, the project `foo_bar` will be in namespace `FooBar` while the project `foo-bar` will be in namespace `Foo::Bar`.)

So go ahead and use sed, or your IDE or whatever you like to replace those throughout your copy of the LHD repo. The following might be handy:

**Linux**
```
cd lucky-hasura-docker
git grep -l 'GITLAB_USER' | xargs sed -i 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i 's/SWARM_NAME/foo_bar/g'
```

**macOS**
```
cd lucky-hasura-docker
git grep -l 'GITLAB_USER' | xargs sed -i '' -e 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i '' -e 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i '' -e 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i '' -e 's/SWARM_NAME/foo_bar/g'
```

**Windows**
```
PR welcome
```

Once that's done, you can move (almost) all of the files over to your lucky app. The following excerpt assumes your project and LHD are setup next to each other such as `git/lucky-hasura-docker` and `git/foo_bar`. It removes all of the Lucky scripts in `foo_bar/script` because those are not needed in LHD development. It also removes the `Procfile`s and copies almost everything from LHD to `foo_bar`. Be sure to replace `foo_bar` with your actual Lucky project's name.

```
rm -rf foo_bar/script
rm foo_bar/Procfile
rm foo_bar/Procfile.dev
rsync -avr --exclude='.git' lucky-hasura-docker/ foo_bar
mv lucky-hasura-docker/README.template foo_bar/README.md
# add .docker-sync dir to git ignore
echo '\n.docker-sync/\nup.cache' >> foo_bar/.gitignore
```

**dotenv**: Oh and one more thing. I should probably take advantage of the dotenv idea. In the following you won't see it used, but I'd love for someone who knows more about this pattern to improve this repo by implementing it. So you can go ahead and get rid of the `.env` file provided by Lucky for now.

The last change you'll need to make, now that the LHD and Lucky projects are together, is take a look in `config/server.cr` you should see a line that starts with `settings.secret_key_base =` (line 17). The string that follows is your development-mode secret key base and will be used to sign the JWTs that are passed to Hasura. It gets randomly generated on project creation, so I need you to paste this several places (until this project has automated tools for this kind of thing) 
* `Docker/docker-compose.dev.yml`
* `script/test`
* `.gitlab-ci.yml`

so that Hasura knows the secret too and can verify your JWTs (if you don't want to share the secret, Hasura supports a public/private keypair option too, it's detailed in their docs). I've marked the spot where this string goes with `DEV_SECRET_KEY_BASE`.

### Docker Intro

Assuming you've installed Docker and can use it on your local machine, let's learn a bit about the Docker config/tools that are provided by LHD.

Before we dig in here, first I want to recommend that you read Docker's getting started guide

[docs.docker.com/get-started](https://docs.docker.com/get-started/)

I trust that you'll get to know Hasura and Lucky on your own, but Docker sometimes has a "set it and forget it" feeling and while that's kind of the point, I highly recommend a basic understanding of the tools since it's the glue holding this all together so nicely.

Before going on, check if you understand this sentence: this is a multi-container project specified as services in several `docker-compose` files, so we'll be using `docker-compose` to build our images, bring up the services and, in production, deploy to a swarm. If you're comfortable with that language, read on, if not, go back and read the docs.

#### docker-sync

If you're developing on macOS or Windows, and new to Docker, it's time to hit you with some bad news: Docker can be painfully slow. The solution is to use `docker-sync` which is a 3rd-party Ruby app. It's really necessary if you'll have anyone developing on anything other than Linux and doesn't interfere with those on your team doing Linux development. It's a great solution for a problem I wish didn't exist. If you've never heard of it take a quick read over there and come back:

[docker-sync.io](http://docker-sync.io/)

LHD has a `docker-sync.yml` in it and a `.ruby-version` but if you don't have Ruby on your local machine you'll need to get it and then install the `docker-sync` gem. Even if you don't plan on developing on macOS or Windows, you'll still need to install this since it's hardwired in at the moment. I know it's a pity to have a non-Docker dependency in a Docker project but it would seem that's just the state of Docker for now.

#### up

The last thing you'll need locally is `up`. You don't need this if you are already comfortable using Docker in development, in that case you probably already have your own workflow and you can use it instead (just be sure to replace `up` in `script/up` and `script/down`). For the rest of us, `up` is simply a tool that keeps an eye on what local files were used to build a Docker image and takes note if any of them change. That way, instead of getting into the habit of starting our project with `docker-compose up` which can lead to surprises if you forget that you needed to rebuild your image(s), you can get into the habit of having an `up.yml` and then simply calling `up`.

This is a lesser-known tool because it is new. So far it seems to be taking a role as a stepping-stone instead of a production tool, but it's been fine for me so far. Go ahead and install it according to instructions and read a little about its usefulness:

[github.com/paulcsmith/up](https://github.com/paulcsmith/up)

### Docker Files

Now with all of that introduced, we can talk about the files provided in `LHD/Docker`. There are several `docker-compose` files which in development are called by `up` (see the `up.yml`) as
`docker-compose -f Docker/docker-compose.yml -f Docker/docker-compose.dev.yml` (we'll talk about the other `docker-compose` files later in the Production section of this writeup). Please take a look at those as they define the core services of the project: `postgres`, `lucky`, and `hasura`. You'll notice in the `.dev` file some `docker-sync` config and some reliance on `script/*` files. Hopefully most of what is here is self-explanatory insofar as these things go. If not, let me know and we can certainly improve this section!

As for the directories in here, we have `traefik` and `prometheus-swarm` which are used in production (we'll come back to them) and `lucky` which is where the `Dockerfile`s reside for creating the production and development images. 

The reason there are two images is that while `production` is stateless, `development` is syncing from local machine to container. This mainly comes up in the final lines of `Dockerfile.prod` where we build the release version of the server binary compared to the `Dockerfile` where we simply use `lucky watch` to constantly rebuild a less-optimized version in development. The one thing our development image has beyond crystal and lucky is shards and executables (in `lib`, `.shards`, and `bin`). These are kept in the image for a few reasons:

1. Docker development on something besides Linux requires a `sync` strategy and IO-intenstive activities like `shards install` can actually crash your instance! (That's why the `.dockerignore` and `docker-sync.yml` files ignore those directories.)
2. Developers need to be working with the same dependency trees. That is already taken care of by `shard.lock` but why re-install if you can simply stick your shard in an image to share?
3. If the shards produce binaries, they will be machine dependent.

That means we have to rebuild the image whenever we want to update Crystal, Lucky, or our shards and we leave this to `up`. Whenever we run a command, `up lucky db.migrate` for example, `up` will double check that our development image doesn't need to be rebuilt first based on the rules in `up.yml`.

## Scripts folder

Now let's dig into all of the scripts that try to make this whole system reproducible and easy to use. In LHD, the `script` directory has two subdirectories: `docker` and `functions`. The `functions` are functions that are called by more than one script. The `docker` scripts are scripts we copy into docker images and run from within the container.

These scripts are the heart of LHD so let's get into some details:

### script/up

The first we'll look at is `up`. This brings up the `docker-sync` containers and all of our services with `up`. It then sets up the database once postgres is ready (thanks to `wait-for-postgres`) including migrations and seeding the database. Once that's all in place, it sets up Hasura so that we can do Hasura migrations.

The main ideas to notice here are

1. In a Docker stack, the best way to know you can send a command to a container is to ping that container with some kind of readiness query on loop until it responds. It surprised me when I first learned this, so you may want to read the rationale yourself:

    [docs.docker.com/compose/startup-order](https://docs.docker.com/compose/startup-order/)

    So you'll see a lot of that in these scripts.

2. Hasura is an awesome tool that supports a lot of use cases! In ours, we want Lucky to manage our migrations so we need to turn off "migrations mode" this can be done with a simple API call ... once Hasura is ready to respond. This can take some time since Hasura won't start itself until it knows postgres is ready (it has its own `wait-for-postgres`-like loop running under the hood too).

Enough talking! Let's go ahead and give this a whirl. Run `script/up` now and if all went according to plan you'll see `✔ Setup is finished!` after about a minute. Then the script enters the Lucky container and starts a `tail -f` of the logs. 

You can now visit `http://localhost:5000` and see the default JSON that Lucky comes with `{"hello":"Hello World from Home::Index"}`. You should also be able to see the Hasura version number at `http://localhost:8080/v1/version` as `{"version":"v1.1.1"}`. And the Hasura console is at `http://localhost:9695/`. This console is slightly different than the default UI console. This one was launched from the Hasura CLI and (among other things) that means that any changes you make in the UI will be automatically written to `/hasura/migrations` which will be copied locally to `db/hasura/migrations`. 

Lastly, be sure to take a look at your docker containers, you should see `foo_bar_lucky:dev`, your lucky container, as well as the default `hasura` and `postgres` containers ready to rock and roll!

### script/down

This script does the reverse of `up`. It tears down the sync-volumes and removes the containers so that you go back to a clean slate. It's expected that a normal development cycle will use `script/up` and if things need to get reset a quick `script/down && script/up` should do the job. If you just want to stop containers without deleting them, `script/down` is not what you are looking for. You can use `up` for things like that. If you are looking for a _deep_ deep reset, you'll need to at least delete the lucky image (or adjust `up.yml` to do a rebuild).

WARNING: I haven't tested this script on a machine where I have multiple Docker projects, so this might have unexpected side effects like stopping or removing containers/volumes unexpectedly. It shouldn't, but it's not properly tested.

### script/test

This script can run in two modes. If you pass an argument, it runs in production mode for testing production images locally. I'll describe that more in the production section below. With no argument it spins up test copies of hasura and lucky in different containers and on different ports than `script/up` and then drops you into a Bash session in the `foo_bar_lucky_test` container. From there you can run `crystal spec` or just generally play around. It'll stay synced with your dev containers via docker-sync. Once you are done, you can just exit the shell session and the test script will clean up afterwards (remove the containers and related volumes). If you'd rather spin up, run tests, and tear down automatically (as we do in CI) just pass the `-t` flag.

It is important that you use this script (or something similar to it) to run tests since we are sharing a hard-coded `DATABASE_URL` between Lucky and Hasura. Your tests will run on whatever database that URL is set to and since tests truncate the database, you could end up truncating your development database at an inopportune time. This script also has the advantage of setting things up properly so that Hasura is available for API calls in the test suite. 

It won't hurt anything, but I recommend that you delete `spec/setup/setup_database.cr` since `script/test` covers this base.

### Other Scripts

The other scripts are all for production, so you can read about them further down in the `production` section of this guide. Or if you're not planning on using the production tools here you can just delete them.

## Setup Hasura

I think now is the right time to get our feet wet in Hasura land a little bit. We want to be able to hit a Lucky endpoint with an email and password and get an account, and then hit it again to get a JWT token that we can pass to Hasura to get our own email address back to us but not someone else's. This will involve editing some Lucky files and doing a little setting up on the Hasura side and is a nice introduction to the core reason this is being done: to separate our Business logic (DB management, authentication, nightly biller etc.) from our presentation (GraphQL).

Now let's seed the database with two users. An admin user and a regular user. Just add these lines to the `call` method in `tasks/create_required_seeds`.

```crystal
%w{admin buzz}.each do |name|
  email = name + "@foo_bar.business"
  user = UserQuery.new.email(email).first?
  UserBox.create &.email(email) unless user
end
```

And then you can run `up lucky db.create_required_seeds` and they'll be added to your database. You'll be able to see that for yourself pretty quickly if you go to `http://localhost:9695/` (your Hasura Console). From their you can run a GraphQL query for users (if you are tracking the users table) or just view the table directly. If you're new to Hasura, take a second to play around here.

Next, we'll need to get Lucky to produce the kind of JWT that Hasura can understand. Go into `src/models/user_token.cr` and replace the `payload` with

```crystal
allowed_roles = ["user"]
default_role = "user"
if user.email.includes?("admin")
  allowed_roles << "admin" 
  default_role = "admin"
end
payload = {"user_id" => user.id,
  "https://hasura.io/jwt/claims" => {
    "x-hasura-allowed-roles" => allowed_roles,
    "x-hasura-default-role" => default_role,
    "x-hasura-user-id" => user.id.to_s,
  }
}
```

Please don't use this in production for determining roles, this is just a demo :)

Note: If you watch the Docker logs in your `foo_bar_lucky` container, you should notice that as soon as you save changes to this file, the app recompiles. You don't need to do anything else to build or serve the app, just save changes, and wait a second for it to recompile.

Now we should be able to post the username and password to `localhost:5000/api/sign_ins` and get back our JWT:

```
curl localhost:5000/api/sign_ins -X POST -d "user:email=admin@foo_bar.business" -d "user:password=password"
```

(If you look in `spec/support/boxes/user_box.cr` you'll see that the default password is "password".)

Notice that the top-level key is `user`, so if you wanted instead to POST json it would be in this shape:

```json
{
	"user": {
		"email": "admin@foo_bar.business",
		"password": "password"
	}
}
```

And you can paste the token into your favorite JWT parser (https://jwt.io is mine) and you should see that `admin` has the `admin` role and `user` has only the `user` role. So far so good. Now let's make a GraphQL query to Hasura. I'd recommend using a nice tool like [Insomnia](https://insomnia.rest/) for this, in that application you can [chain requests](https://support.insomnia.rest/article/43-chaining-requests) and hence use the response from the sign-in request as the 'Bearer' token in the other and they even have a 'graphql' mode that just lets you paste graphql in. Pretty spiffy. Please read the Hasura docs and the docs of your favorite API-testing tool until you can post the following GraphQL to `http://localhost:8080/v1/graphql` using the token you got from your admin sign in.

```
query MyQuery {
  users {
    email
  }
}
```

and receive in response

```
{
  "data": {
    "users": [
      {
        "email": "admin@foo_bar.business",
      },
      {
        "email": "buzz@foo_bar.business",
      }
    ]
  }
}
```

Now, if you try that with the token you get from signing in as `buzz` you'll get the following

```
{
  "errors": [
    {
      "extensions": {
        "path": "$.selectionSet.users",
        "code": "validation-failed"
      },
      "message": "field \"users\" not found in type: 'query_root'"
    }
  ]
}
```

That's because Hasura doesn't know about our `user` role and that it should at least be able to see its own email. Let's go to the dashboard and add that, again I'd rather leave the details to the Hasura docs, but here's a screenshot of the permissions I set to help you get off on the right foot:

![hasura permissions screen](https://github.com/KCErb/lucky-hasura-docker/blob/master/img/user-permissions.jpg)

I just entered a new role called 'users' and edited the 'select' permission to allow a user to query their own email. Now the response is

```
{
  "data": {
    "users": [
      {
        "email": "buzz@foo_bar.business"
      }
    ]
  }
}
```

As a last check, you should see that `db/hasura/migrations/metadata.yml` now looks like this:

```
version: 2
tables:
- table:
    schema: public
    name: users
  select_permissions:
  - role: user
    permission:
      columns:
      - email
      filter:
        id:
          _eq: X-Hasura-User-Id
```

### Test Hasura

Now let's add the above to our Lucky test suite. Here's an example file that gets the job done. I'm not saying this is an ideal way to test, I would actually prefer to abstract this out a little so that I could have a graphql request helper and a config file for example, but for the purposes of demonstration it's easier to keep it in a single file. Go ahead and add this to `spec/requests/graphql/users/query_spec.r` if you want to copy the pattern Lucky ships with and then run `crystal spec` in your test container.

```crystal
require "../../../spec_helper"
require "http/client"
require "json"

describe "GraphQL::Users::Query" do
  it "admin can see all users" do
    admin, user = make_test_users
    users = graphql_request(admin)
    users.size.should eq 2
  end

  it "user can see only self" do
    admin, user = make_test_users
    users = graphql_request(user)
    users.size.should eq 1
    users.first["email"].should eq "user@example.com"
  end
end

private def make_test_users
  admin = UserBox.create &.email("admin@example.com")
  user = UserBox.create &.email("user@example.com")
  {admin, user}
end

# returns [{"email" => "buzz@foo_bar.business"}]
private def graphql_request(user) : Array(JSON::Any)
  client = HTTP::Client.new("foo_bar_hasura_test", 8080)
  client.before_request do |request|
    request.headers["Authorization"] = "Bearer #{UserToken.generate(user)}"
  end
  query = %({"query": "{ users { email } }"})
  response = client.post("/v1/graphql", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: query)
  json = JSON.parse response.body
  data = json["data"]?
  data = data.should_not be_nil
  data["users"].as_a
end
```

Though I don't recommend following exactly the above as a kind of 'best practice', I do recommend understanding what's going on in there implementing something like it since making sure you didn't break your GraphQL endpoint recently is a good idea.

## From Development to Production

And now, it is decision time. If you're not much interested in deploying your project to a server whenever you push to a special branch then you should delete the provided `.gitlab-ci.yml` and this is where we part ways. Good luck to you, please feel free to open an issue or a PR to improve this project in making it more geared towards people like yourself. I'd be happy to support you and them here :)

If you are however interested in getting some of the awesome benefits I've put together here, then the next step will be to start thinking about deployment. We'll be commiting and push our project to the `master` branch on Gitlab and that will kick off a deployment to a production server. So before we push this proejct up, we'll need to provision such a server and get some environment variables put together in Gitlab and on the server so that things go smoothly.

For now, we'll just remove the TravisCI file that lucky provided since we'll not be using their service here:

```
rm foo_bar/.travis.yml
```

# Lucky + Hasura via Docker in Production

OK, now for the juicy stuff. The above is nice and all, but we can go way further. We can use [Traefik](https://docs.traefik.io/) to put up a load-balanced reverse-proxy to our Docker Swarm. We can have Lucky queries going to some containers and GraphQL queries going to others. (Yay *real* microservices, once while developing this workflow, I had my Lucky service down for days and didn't notice because I was just testing the GraphQL and had no other alerts setup. These things are actually independent. I love that. And with a few keystrokes we can scale up and down to match needs. Maybe we have a bunch of mobile users hammering the GraphQL endpoints but the Lucky server is kinda bored. No problem, just scale up that Hasura service! To keep an eye on everything, a separate swarm for monitoring tools under the [Prometheus](https://prometheus.io/) umbrella are available and we bring that swarm online with an easy one-liner.

What's more is Gitlab can do the heavy lifting for us with respect to building and tagging images. If there's an issue with a deployment on staging, we can use the rollback script to go back to a previous image and database state since the images are tagged by git commit. I'm even experimenting with two kinds of migrations: "additive" and "subtractive" to go for a perfect zero-downtime history. If you're interested in these ideas read on, the main motivation for building all of this was to achieve devops Nirvana and if the below isn't it, then I hope it's close enough that the community can help me get it the rest of the way there. We'll have to sacrifice a bit though, some of the details of a real production deployment get a little hairy but it's worth it in the end.

## First commit and push

To start, we'll commit our code and use a special flag in the commit message: `[no-deploy]`. If you take a look at `.gitlab-ci.yml` you'll see that we have 4 stages `test` `build` `push` and `deploy`. This flag is configured to skip the deploy stage. Hence this first commit will test our code, then build a production image and then tag and push that image to the Gitlab registry for use in the deployment stage.

Note: any `scripts` you want to run here like `script/test` or `script/build` must either be a `sh`ell script (not bash) or you need to install bash on the docker image. If you fail to do this, you'll get a cryptic message `/bin/sh: eval: line 98: script/test: not found` which seems like it's saying 'file not found' but what it's really saying is '`sh` file not found' and it is unaware that you have a `bash` script in that exact location.

The most unique thing here is perhaps the `push` step where we tag an image both with a commit reference via the gitlab-provided variable `$CI_COMMIT_SHORT_SHA` as well as the branch name via `$CI_COMMIT_REF_NAME`. The result is that the most recent / current image is tagged by branch name and by commit reference. On the next build, that can be used as a cache reference to save build time. This idea and many other things are borrowed / adapted from [blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices](https://blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices/).

Many of the variables used here are provided by gitlab such as `$CI_COMMIT_REF_NAME` but not all. When we start talking about the `deploy` stage later we'll need to add some of our own but for now we'll content ourselves with simply being able to test and build our code.

If your first push was successful, your Gitlab registry now has a production image built and tagged ready to be pulled onto a production server. So let's turn our attention to getting those going.

### Testing Production Images

You might notice that the test stage follows the build stage. The idea here is that we want to test our production image so we have to build it first. But if you have an unexpected test failure (remember, that a push to master or staging is a deploy, so you shouldn't push code you haven't tested locally anyways) you could get into a situation that is hard to debug, no one wants to debug a testing issue that only happens on CI!

The solution is to pass an argument to `script/test`. This will cause the test script to run in CI mode and will pull whatever image you like based no the tag name that you pass to `script/test`, so if you want to test the latest push to staging then

    script/test staging

If your repo is private, then you'll need to log into the Gitlab repo in order to pull that image down locally. The first time you log in to the gitlab registry you'll need to enter your username and password or you can setup either an access or deploy token see the [Gitlab registry docs](https://docs.gitlab.com/ee/user/packages/container_registry/#authenticating-to-the-gitlab-container-registry). Afterwards Docker will just reuse the credentials since it stores them.

## Staging and Production Servers

The first thing we need to do is get some servers up somewhere. It's not terribly important how you choose to do this, so please feel free to skip to the next major heading if you've got your own plan. Otherwise, I'll go ahead and describe how I did this with [DigitalOcean](https://www.digitalocean.com) and [Cloudflare](https://www.cloudflare.com).

(Sidenote: for a real project, I'm a fan of the idea of having a dedicated "staging" server, so later it'll come up that we in fact have two servers here with slightly different purposes but identical configuration.)

With DigitalOcean (DO) we can spin up a little hobby server for $5 per month. I don't want to go too far astray from the topic here, so I'll leave it to you to do a little googling and learn how to use it. I will point out however that the [DigitalOcean 1-click Docker app](https://marketplace.digitalocean.com/apps/docker) is a pretty convenient starting place. They can setup ssh-only access for you before you even create the droplet which is a great starting place security-wise. 

Whether you use DigitalOcean or AWS or a box in your basement, you'll want to be sure you do a little reading on using Docker in production. There are some settings security-wise that you'll want to get right, and plenty of reading material out there to get you started. So please address this now. (But don't log into Docker yet on the new box, we'll be logging into the Gitlab registry since this box will need to talk to your custom-built images).

Next, I recommend 

1. ssh'ing into the server to make sure you can.
2. In the DO droplet, we use `ufw` (Uncomplicated Firewall) and since we'll be serving from this box we'll need to `ufw allow` a couple of ports: 80 and 443. You can use `ufw status` to see a list of ports that are allowed. 2375 and 2376 are used by docker for communication between instances, this is so that you can have droplets participate in the same Docker network.
3. In your Gitlab repository, provision two Deploy Tokens under `Settings > CI/CD`. 
    1. The first one will be used during CI/CD. It must be named `gitlab-deploy-token` and you should select the `read_registry` scope. If you like to, you can use this one in the next step. I'm going to recommend creating a second token though because the special 'gitlab-deploy-token' has 'write' access which other tokens don't have. Also, for the other tokens you can use names to help you remember what it is for like 'foobar-production' and 'foobar-staging'. And then if you leak that token you can revoke it and leave your CI/CD alone. (See more at [docs.gitlab.com/ee/user/project/deploy_tokens/#usage](https://docs.gitlab.com/ee/user/project/deploy_tokens/#usage)).
    2. The second token will be used to log into the Gitlab Docker registry from your server. Give it a meaningful name and read access to both the registry and the repository and jot down the username and password.
    3. In your Docker-enabled server, we next want to log in to Docker with the username and password you just got. 
        
            docker login registry.gitlab.com -u gitlab+deploy-token-#####
        
        You'll get a warning that credentials are stored unsecurely. We'll be putting other production credentials here as env variables, so it is assumed that the production server contains sensitive information. I'm open to a better system, but remember that for automatic deployments to work, things have to be passwordless or Gitlab has to hold the password/secret and hand it over during CD.

Next we can do our DNS and security certificates through Cloudflare (for free). The first thing you'll need is a domain, so go get one of those. For the next steps, I won't go into too much detail since I want to let cloudflare maintain their own docs (see [support.cloudflare.com/hc/en-us/articles/End-to-end-HTTPS-conceptual-overview](https://support.cloudflare.com/hc/en-us/articles/360024787372-End-to-end-HTTPS-with-Cloudflare-Part-1-conceptual-overview)) but here are some basic steps. Please note that the process of creating a domain and provisioning certificates for it can be time consuming. If you get to a step and don't see a button or get a weird error like "this zone is not part of your account" then you probably just need to wait a few minutes (or as much as two days). Sorry, such is the nature of real production work. My experience is that I can do the following in 15 minutes without hassle:

1. Setup some special CNAME's on the DNS page for various Docker services: `api`, `traefik`, and `grafana`.
    
    ![docker dns](https://github.com/KCErb/lucky-hasura-docker/blob/master/img/cloudflare-dns.jpg)

2. Use the "Full (Strict)" encryption mode, don't use automatic `http => https` and don't use HSTS enforcement, otherwise you'll get into a redirect loop (we'll be using an origin certificate and Traefik will handle that enforcement/redirect).

3. Create a `.cert` and `.key` origin certificate pair and place them in `etc/certs` on the server (production for now, but you'll do this again for staging). The name / path here are used by the scripts so please double check them:

    ```
    etc/certs/cloudflare.cert
    etc/certs/cloudflare.key
    ```

    ![docker certs](https://github.com/KCErb/lucky-hasura-docker/blob/master/img/cloudflare-origin-certs.jpg)

## Production Scripts

Next we'll take a look at the scripts that are provided here for automatic deployment. The first push is special, some hand holding needs to be done. We need to have a fully running setup before these scripts can really do their magic. So instead of just running these scripts blindly, we're going to walk through them and do much of what they do by hand, and then see how those manual steps have been brought together into convenient executables.

### deploy

The `deploy` script is a good place to start here. The first thing you'll notice is that this thing relies on a small pile of environment variables. The expectation is that this script is run in a production server where these vars are set. But sometimes we need to test our production setup locally, so the script provides some dummy values. Let's go ahead and add the real environment variables to our production server now. The following are the first few environment variables from an example `~/.profile` (we'll do 6 more when we set up the monitoring tools).

```
export POSTGRES_USER=5JHMOA1JBfElT3pVyPd4AssrMKaU6wkq1fvuximxezcPjkqfZl3VlfTL
export POSTGRES_PASSWORD=JHMlT3pVyPd4xezAssrMVlJKaU6wPHuximcPjkq1fvjfZl3BfOA1InElfTL5
export POSTGRES_DB=foo_bar_production
export HASURA_GRAPHQL_ADMIN_SECRET=6wPHux5JHMlT3pVyPd4xezAssrMVlJKaU6wPHuximcPjkq1fvjfZl3BfO
export APP_DOMAIN=foobar.business
export SEND_GRID_KEY=SG.ALd_3xkHTRioKaeQ.APYYxwUdr00BJypHuximcjNBmOxET1gV8Q
export SECRET_KEY_BASE=z8PNM2T3pVkLCa5/IMFrEQBRhuKaU6waHL1Aw=
```

You can fill in the first three entries above with randomly generated strings (not too long, some of these services have limits 63 chars or less should be safe, also, careful with special characters, you might want to check PostGres and Hasura docs if you'd like to use special chars).  The next three are more or less up to you. The postgres db name will be something you actually use so make it easy to type/read. `APP_DOMAIN` is the domain of the app that you registered in the Cloudflare step, it used by Traefik and Lucky. `SEND_GRID_KEY` comes from [sendgrid.com](https://sendgrid.com/) and is simply a convenient Lucky default for handling emails: https://luckyframework.org/guides/deploying/heroku#quickstart. You'll have to go sign up with them and generate an API key. And finally, the `SECRET_KEY_BASE` comes from `lucky gen.secret_key`. You should probably run that command in the Docker container, otherwise you'll have to `shards install` locally which isn't so bad but kinda defeats the point.

Please note in the above that the special characters given to me by `sendgrid` and `lucky gen.secret_key` didn't need escaping in my shell (bash). In particular the last entry has special quoting to get that `SECRET_KEY_BASE` interpolated into JSON. I can't guarantee that in your shell the same will be true or what is the best strategy for escaping special characters. Depends on the shell and the characters! After doing this step, you might want to just run through the vars in the shell and make sure they look right.

`script/deploy` by default runs in 'additive deploy' mode but we can pass a `-s` flag to use 'subtractive deploy' mode. The idea here is that we can choose to have each deployment only add or subtract columns from the database. The difference between the two is simply the order we migrate the database and update the code. If we added columns / tables, then we need to migrate the database before updating the code since the old code won't ask for columns that didn't exist before. The reverse is true if we take away columns / tables.

NOTE: The first deployment has to "update" code before migrating because that function gets the stack going (i.e. starts services). So on the very first deploy (which is done manually) you must use `script/deploy -s`. Subsequent deployments should be handled automatically and ... ???a commit message can put them into subtractive mode???

### script/rollback

The rollback script requires one argument: the version you want to rollback to. Since our images are tagged by commit SHA that means providing the first 8 characters of the commit SHA you want to go back to. If you've checked out that commit in the terminal, this is just the output of `git rev-parse --short=8 HEAD`.

You can also provide a second argument which works just like `deploy`. If it was an additive deploy that you're rolling back, then the argument should either be `add` or not provided.

NOTE: this one is a work in progress. There is a `rollback` function which spins up a container and runs `db.rollback` calls, but at the moment it just rolls back one migration. If your deploy had two for example, then you'd want to pass that as an argument. This can probably be automated now that I have a commit SHA, but I haven't implemented this yet so some manual rolling back will be needed in that case.

### Health Checks

In deployment we'll be using docker swarm so you may also notice the `script/docker/*healthcheck` files. These are little scripts that run every so often and make sure the services are healthy. You can read more about them here: [docs.docker.com/compose/compose-file/#healthcheck](https://docs.docker.com/compose/compose-file/#healthcheck). 

LHD includes a health check for Lucky that makes sure it has a good DB connection. It relies on us creating a `version` route so we'll do that now.

The version route is used for our Docker healthcheck. We'll get to the Docker Swarm stuff a little later, but for now, let's give it a route it can ping to know our application is healthy (responding to requests and talking to the db). You can choose whatever you like for this, I'm choosing to store a 'version' string in the DB and fetch it on request.

So let's create our first model: `version`. First, open a shell in the lucky container with `docker exec -it foo_bar_lucky /bin/bash`. And then run `lucky gen.model Version`. You should get something like

```
root@5b357ed2ad28:/data# lucky gen.model Version
Created CreateVersions::V20200415124905 in ./db/migrations/20200415124905_create_versions.cr
Generated Version in ./src/models/version.cr
Generated VersionOperation in ./src/operations/save_version.cr
Generated VersionQuery in ./src/queries/version_query.cr
```
and you should see the corresponding files on your local system. Let's add a table by replacing the contents of `src/models/version.cr` with:

```crystal
class Version < BaseModel
  table :versions do
    column value : String
  end
end
```

and updating the corresponding migration by adding 1 line in the create block `add value : String`. My file looks like this:

```crystal
class CreateVersions::V20200415124905 < Avram::Migrator::Migration::V1
  def migrate
    # Learn about migrations at: https://luckyframework.org/guides/database/migrations
    create table_for(Version) do
      primary_key id : Int64
      add_timestamps
      add value : String # <<< LIKE THIS
    end
  end

  def rollback
    drop table_for(Version)
  end
end
```

Next we'll add a route to `GET` the current version. Put the following in `src/actions/version/get.cr`

```crystal
class Version::Get < ApiAction
  get "/version" do
    last_version = VersionQuery.last?
    if last_version
      json({version: last_version.value})
    else
      json({error: "Unable to reach database"}, 503)
    end
  end
end
```

Lastly, we'll add some logic to `tasks/create_required_seeds.cr` so that each time the required seeds are created we make sure the latest version number is provided:

```crystal
current_version = `git rev-parse --short=8 HEAD`.rchop
current_version = "pre-first-commit" unless current_version.size > 0
last_version = VersionQuery.last?
version_is_same = last_version && last_version == current_version
SaveVersion.create!(value: current_version) unless version_is_same
```

## Docker Swarm

On the server, you'll need to start a swarm first (see [the Docker guide](https://docs.docker.com/get-started/) if you're not sure about this), but after that you can just run `script/deploy init` as described above and everything should kick off on its own.

Please do have a look at `docker-compose.prod.yml`. You'll see again some of those env variables that are needed to get this started being passed into containers. You'll also see some `deploy` keys being used which start us off with just 1 replica of each service. If you have trouble with the first deploy, the issue may be resolved by double checking that you understand this one file.

You'll notice that the `update_code` function calls the following to deploy:

`docker stack deploy -c Docker/docker-compose.yml -c Docker/docker-compose.prod.yml -c Docker/docker-compose.swarm.yml SWARM_NAME --with-registry-auth` so you'll want to understand those files. Note also that `with-registry-auth` flag is there so that you can pull images from the registry. We'll get more into that in the CD section.

# Monitoring tools

export SLACK_URL=https://hooks.slack.com/services/G61J230A7/CK9P23U17/qaGCB6TKZVFpHRng0WqTEaeX
export SLACK_CHANNEL=alerts
export SLACK_USER=Prometheus
export ADMIN_USER=foo_bar_admin
export ADMIN_PASSWORD=QIgvfT8folMq1Myvqq53kT3O91TRh4K1
export HASHED_PASSWORD="$apr1$Vz7vV1pF$Ip0GENX2ah09sEhp2PFaq."

### Traefik

TODO::
ADMIN_USER
ADMIN_PASSWORD
HASHED_PASSWORD
https://docs.traefik.io/middlewares/basicauth/
```echo $(htpasswd -nb user password) | sed -e s/\\$/\\$\\$/g```


Now we'll turn our attention to connecting the wide world to our Lucky and GraphQL services. The first thing you'll need is a domain name and security certificates so that you can host a `https://example.com`. I'll assume that you took care of this back at the DigitalOcean/Cloudflare section. The second thing you'll need is a reverse proxy so that you can route requests to different services based on the address of the request. In the LHD example, if someone requests `api.example.com/v1/graphql` that request will go to Hasura and if it makes any other `api.example.com` request they'll go to Lucky. This is accomplished by routing `api.example.com` requests to the server (via CNAME records in Cloudflare) and using a neat little docker-ready reverse proxy called [Traefik](https://traefik.io).

Once you've got those CNAME records up, let's take a look at the Traefik config. There are two parts, let's start with `docker-compose.swarm.yml` this file just defines some swarm-only keys like 'deploy' and the Traefik service. Some of the config is here and some of it is in `Docker/traefik/traefik.toml`. I think all of it can go in the docker-compose, but I feel like a nice separation of concerns is putting per-service config in the docker-compose and traefik-wide config into this `.toml`.

As we look through the YAML, the first thing we see is that it adds some traefik rules to the hasura and lucky services. You'll almost certainly want to change these to suit your own tastes, so I recommend you read their docs, for example: [docs.traefik.io/routing/overview](https://docs.traefik.io/routing/overview/).

The next thing I want you to notice is the service called `traefik-docker-link`. This piece is needed to avoid a security issue which arises from Traefik needing access to the docker socket and that giving it potential admin priviledges. The Traefik docs point to a lot of good resources on this issue but it's hard to link specifically to the security part of the page so you'll have to read: [docs.traefik.io/providers/docker](https://docs.traefik.io/providers/docker/) if you want to dive in. One resource they point to is the Docker docs: [docs.docker.com/engine/security/security/#docker-daemon-attack-surface](https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface).

The last thing I'll point out here is a comment found in a few places throughout the project: `HTTPS_SWITCH`. This is for running a production setup in development. Unless you want to go to the trouble to convince your local system that https is a thing you can do, you'll need to comment out the lines marked here in order to `docker stack deploy` locally with Traefik in place. It's kind of a hassle, but boils down to just commenting out a the lines marked by this "switch".

Now let's look at the TOML file. It just defines the HTTPS entrypoint and the HTTP redirect as well as providing the docker link so that we can do some service discovery in that `docker-compose.swarm.yml` file.

If you have any other questions about this aspect of things, try to read through and understand the docker-compose setup we have here. There's a lot going on and it took a long time to figure out with lots of debugging. Hopefully for you it'll just work.

## Monitoring with Prometheus

The last directory to point out here is called `prometheus-swarm`. For really excellent application monitoring you can either pay money or use this fairly complex docker swarm for free. I'm really glad that someone else already solved this problem: [github.com/stefanprodan/swarmprom](https://github.com/stefanprodan/swarmprom.git). In this repo I've adapted that repo somewhat to fit the needs of this project.

This toolset can monitor your services, give you real-time graphs looking at memory usage, CPU usage, and much more across services and nodes, it can even send you Slack notifications when an alert is triggered (like memory getting too high). Lots of good stuff in here but I'm going to skip over it all since from my perspective (and as noted in the README), it can be as simple as

```terminal
cd Docker/prometheus-swarm
docker stack deploy -c docker-compose.yml prometheus_swarm
```

But do be careful, this thing needs a bit of memory and if you're using the DigitalOcean $5 server you might not have enough room for Lucky, Hasura, and this monitoring stack all in the same tiny box.

I feel like I should write more since there's a bunch going on under the hood here, but I'll let those interested read the `docker-compose` file, it 
has all the details. In production I have another CNAME record for `grafana.example.com` and I can do my monitoring from there.

# Automatic Deployments

The final step is to kick off another commit and this time allow the deployment stage to run.

Let's head on over to "Settings > CI/CD" under the "Variables" heading. There you'll need to create four variables, 2 each for staging and production. `GITLAB_PRODUCTION_KEY` and `GITLAB_STAGING_KEY` contain the SSH private keys of ssh keypairs where the public key is already on the production or staging servers. This gives us ssh access for the deploy step. The IP addresses are also made into variables as `PRODUCTION_SERVER_IP` and `STAGING_SERVER_IP`.
With those things in place, you'll be able to deploy to the server automatically whenever a commit lands in `master` or `staging`. That is of course assuming you have server's setup properly. I'm assuming here that you've already run `script/deploy init` on the server manually which will only work if everything is set up properly.

# Conclusion

If you read through all of the above and it all worked perfectly: awesome! Let me know to motivate me to keep this project up to date.

I'm afraid it's quite likely though that somewhere along the way some bump came along that you just couldn't resolve or that proved me wrong. If so, please open an issue in the LHD repository. I'd love to fix mistakes and improve on the write up. I might not agree that a section needs to be written on how to do X, but I'm always happy to have links to documentation and other write ups that explain some aspect in more detail.
