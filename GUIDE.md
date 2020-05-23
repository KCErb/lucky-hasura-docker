# Guide

Hi there, this is a writeup explaining a particular tech stack that I've been working on. The basic idea here is that I want my frontend apps to talk to the (Postgres) database via [GraphQL](https://graphql.org). [Hasura](https://hasura.io) is a great tool for painlessly adding a GraphQL layer to a Postgres database. As such, Hasura doesn't actually handle business logic. [Lucky](https://luckyframework.org) is a great web framework that we can use to handle the business logic, database migrations, and anything else not GraphQL related.

If you're not familiar with any of these tools, please click on the links above and read since this tutorial is more about putting them together and less about why they are a good choice or how to use them. Much of the following assumes you have at least a cursory knowledge of Crystal, Lucky, GraphQL, and Hasura.

And how is it that we put it all together? Docker.

Yes, that's Docker with a period, not an exclamation point. I'm not gonna lie, this project has taken a little skip out of my step with respect to Docker. The rainbows may have faded, but at the end is a pot of steel ingots, not as shiny as gold but still valuable and very useful.

There are two sections of this writeup, the first is on using Docker to get these tools up together in development, the second is on doing it all in production (with Docker Swarm). As usual, development is just the tip of the iceberg. Much of what's written here and available in the example project is dedicated to having really nice production-grade automated deployment. So if you don't plan to use Docker in production, that's fine, I think the first half will still be useful, but be aware that that wasn't my intent when creating this project initially. If there is interest and PRs I'd be happy to make this more development-only friendly.

## Lucky + Hasura via Docker in Development

Some of the tools here will be on your local machine, others will be in the docker image. Let's start with the things you need locally in order to get this up.

### Lucky CLI

The first thing you'll need to do is get a Lucky project scaffolded using Lucky CLI. Here are links to the docs for how to do that on [macOS](https://luckyframework.org/guides/getting-started/installing#install-lucky-cli-on-macos) and [Linux](https://luckyframework.org/guides/getting-started/installing#install-lucky-cli-on-linux) (Windows support has not landed for Crystal yet).

With that tool in place, you can now start a project with `lucky init` as per the next page of documentation [Starting a Lucky Project](https://luckyframework.org/guides/getting-started/starting-project). Please notice that though we are generating the scaffold locally, everything else will be done in the Docker container. This could lead to some confusion since, for example, your local Crystal or Lucky might be a different version than that in the Docker container. Be careful to make sure they match for this one step, and from here on your local crystal shouldn't really matter.

`lucky init` will have you name your app and then the dialog will ask you if you want to do a "Full" app or an "API only" app. You can of course do either one, but for this demo the focus is on backend tools, so the example app is API-only. You'll then be asked if you want to generate authentication. The answer is yes, we'll definitely want authentication helpers since Hasura uses JWT. Here's a one-liner that does the same:

```shell
lucky init.custom foo_bar --api
```

After that, the project is created and you're told to do things like `check database settings in config/database.cr`. We'll **not** be following those steps because we are more interested in this running in Docker than on our own machine. (Notice we'll not even be installing Crystal locally.)

### Up

Another tool this project uses is called simply `up`. You don't need this if you are already comfortable using Docker in development, in that case, you probably already have your own workflow and you can use it instead. To remove `up` as a dependency you just need to replace 2 lines in this project (one in `script/up` and another in `script/down`). For the rest of us, `up` is simply a tool that keeps an eye on what local files were used to build a Docker image and takes note if any of them change. That way, instead of getting into the habit of starting our project with `docker-compose up` which can lead to surprises if you forget that you needed to rebuild your image(s), you can get into the habit of having an `up.yml` and then simply calling `up`.

It also comes with lots of other handy shortcuts to common docker operations so please give the project a read:

[github.com/paulcsmith/up](https://github.com/paulcsmith/up)

### LHD

The last local dependency, at least for bootstrapping your project, is this very repository. Getting all the configuration with Docker can be challenging, so I'm providing here a bunch of Docker-related files. It has everything you need (and then some) to use Docker in development *and* deployment, so if you don't want the deployment stuff, you'll have to remove it yourself (for now). Here's a link to the repo in case this README and the source get separated:

[github.com/KCErb/lucky-hasura-docker](https://github.com/KCErb/lucky-hasura-docker)

I'm going to refer to this project as LHD (lucky-hasura-docker) and in particular, since the boilerplate is in the `proj_template` directory of the repo, when I refer to `LHD/script/` you can find the directory I'm talking about by looking in `lucky-hasura-docker/proj_template/script/`.

This repo has directories and files that you should add to your Lucky project, so go ahead and clone that down into a separate local directory for a start. We'll be modifying it and then moving files over to the Lucky project.

#### LHD Step 1: Search and Replace

This repo has a few "variables" that you should use search-and-replace to customize to your project. They are:

* `GITLAB_USER`
* `GITLAB_REPO_NAME`
* `PROJECT_NAME`
* `SWARM_NAME`

The first two are used in git commands (like `git clone`) to pull/push your project around (i.e. `gitlab.com/<GITLAB_USER>/<GITLAB_REPO_NAME>`).

(Oh yeah, did I mention that we'll be using Gitlab in this tutorial as well? That also is tied in with the deployment setup here. The roadmap for this project includes a plan to add support for other git/CI/CD providers.)

`PROJECT_NAME` and `SWARM_NAME` are up to you, but for a start, you'll probably want them to be the same as `GITLAB_REPO_NAME`. The key is that you sometimes have to type these two names, so if your repo name is long like `lucky_hasura_docker` you might want your swarm and project names to be `lhd` or if you want them to be separate `lhd` and `lhd_swarm`. **Also** in many places I have variable names like `SWARM_NAME_internal` so if your names have dashes, you'll end up with mixed names `cool-app_internal`. If that bothers you, you might want to stick with underscore names. (Not to mention that in Crystal land, the project `foo_bar` will be in the namespace `FooBar` while the project `foo-bar` will be in the namespace `Foo::Bar`.)

So go ahead and use `sed`, or your IDE or whatever you like to replace those throughout your copy of the LHD repo. The following might be handy:

##### Linux

```shell
cd lucky-hasura-docker
git grep -l 'GITLAB_USER' | xargs sed -i 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i 's/SWARM_NAME/foo_bar/g'
```

##### macOS

```shell
cd lucky-hasura-docker
git grep -l 'GITLAB_USER' | xargs sed -i '' -e 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i '' -e 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i '' -e 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i '' -e 's/SWARM_NAME/foo_bar/g'
```

Once that's done, you can move all of the files in `proj_template` over to your Lucky app. The following excerpt assumes your project and LHD are siblings: `git/lucky-hasura-docker` and `git/foo_bar`. It also deletes all of the default scripts in `foo_bar/script` since, at the time of this writing, they are not useful in an LHD workflow. It also removes the `Procfile`s and copies everything from `proj_template` to `foo_bar`. Be sure to replace `foo_bar` with your actual Lucky project's name!

```shell
# modify foo_bar a bit
rm -rf foo_bar/script
rm foo_bar/Procfile
rm foo_bar/Procfile.dev
echo '\nup.cache' >> foo_bar/.gitignore
# rsync contents of template dir into foo_bar
rsync -avr lucky-hasura-docker/proj_template/ foo_bar
```

For the last change you'll need to make, now that the LHD and Lucky projects are together, take a look in `config/server.cr` you should see a line that starts with `settings.secret_key_base =` (line 17). The string that follows is your development-mode secret key base and will be used to sign the JWTs that are passed to Hasura. It gets randomly generated on project creation and `hasura` will need to know its value. You can either change it to `lucky_hasura_32_character_secret` (the static default in this project) or you can update all instances of `lucky_hasura_32_character_secret` with the value you find here. Either way it'll only run in development so you should be safe.

### Docker Intro

Assuming you've installed Docker and can use it on your local machine, let's learn a bit about the Docker config/tools that are provided by LHD.

I trust that you'll get to know Hasura and Lucky on your own, but Docker sometimes has a "set it and forget it" feeling and while that's kind of the point, I highly recommend a basic understanding of the tools since it's the glue holding this all together so nicely.

Before going on, check if you understand this sentence: this is a multi-container project specified as services in several `docker-compose` files, so we'll be using `docker-compose` to build our images, bring up the services and, in production, deploy to a swarm. If you're comfortable with that language, read on, if not, please spend a few minutes with Docker docs / tutorials. Their overview page can at least get the ball rolling vocab-wise.

[docs.docker.com/get-started/overview](https://docs.docker.com/get-started/overview/)

### Docker Files

Now with all of that introduced, we can talk about the files provided in `LHD/Docker`. There are several `docker-compose` files which in development are called by `up` (see the `up.yml`) as
`docker-compose -f Docker/docker-compose.yml -f Docker/docker-compose.dev.yml` (we'll talk about the other `docker-compose` files later in the Production section of this writeup). Please take a look at those as they define the core services of the project: `postgres`, `lucky`, and `hasura`. You'll notice in the `.dev` file and some reliance on `script/*` files. Hopefully, most of what is here is self-explanatory insofar as these things go. If not, open an issue and we can certainly improve this section!

As for the directories in here, we have `traefik` and `prometheus-swarm` which are used in production (we'll come back to them) and `lucky` which is where the `Dockerfile`s reside for creating the production and development images.

The reason there are two images, is that while `production` is stateless, `development` has code mounted from local machine to container. This mainly comes up in the final lines of `Dockerfile.prod` where we build the release version of the server binary compared to the `Dockerfile` where we simply use `lucky watch` to constantly rebuild a less-optimized version in development. The one thing our development image has beyond Crystal and Lucky is shards and executables (in `lib`, `.shards`, and `bin`). These are kept in the image for a few reasons:

1. Developers need to be working with the same dependency trees. That is already taken care of by `shard.lock` but why re-install if you can simply stick your shard in an image to share?
2. If the shards produce binaries, they will be architecture-dependent.

That means we have to rebuild the image whenever we want to update Crystal, Lucky, or our shards and we leave this to `up`. Whenever we run a command, `up lucky db.migrate` for example, `up` will check if our development image needs to be rebuilt based on the rules in `up.yml`.

## Scripts folder

Now let's dig into all of the scripts that try to make this whole system reproducible and easy to use. In LHD, the `script` directory has two subdirectories: `docker` and `functions`. The `functions` are functions that are included by `bash` scripts. The `docker` scripts are scripts we copy into docker images and run from within the container.

These scripts are the heart of LHD so let's get into some details:

### script/up

The first we'll look at is `up`. This brings up all of our services with `up`. It then sets up the database once Postgres is ready (thanks to `wait_for_postgres`) including migrations and seeding the database. Once that's all in place, it sets up Hasura so that we can do Hasura migrations.

The main ideas to notice here are

1. In a Docker stack, the best way to know you can send a command to a container is to ping that container with some kind of readiness query on loop until it responds. It surprised me when I first learned this, so you may want to read the rationale yourself:

    [docs.docker.com/compose/startup-order](https://docs.docker.com/compose/startup-order/)

    You'll see a fair bit of that in these scripts.

2. Hasura is an awesome tool that supports a lot of use cases! In ours, we want Lucky to manage our migrations so we need to turn off "migrations mode" this can be done with a simple API call ... once Hasura is ready to respond. This can take some time since Hasura won't start itself until it knows Postgres is ready (it has its own `wait_for_postgres`-like loop running under the hood too).

Enough talking! Let's go ahead and give this a whirl. Run `script/up` now and if all went according to plan you'll see `✔ Setup is finished!` after about a minute. Then the script will enter the Lucky container and start a `tail -f` of the logs.

Once Lucky gives you the signal, you can visit [localhost:5000](http://localhost:5000) and see the default JSON that Lucky comes with `{"hello":"Hello World from Home::Index"}`. You should also be able to see the Hasura version number at [localhost:8080/v1/version](http://localhost:8080/v1/version) as `{"version":"v1.2.0"}`. And the Hasura console is at [localhost:9695](http://localhost:9695/). This console is slightly different than the default UI console. This one was launched from the Hasura CLI and we're using the `cli-migrations` Hasura image. Among other things, this means that any changes you make in the UI will be automatically written to `/hasura/migrations` which will be copied locally to `db/hasura/migrations`.

Lastly, be sure to take a look at your docker containers, you should see `foo_bar_lucky:dev`, your lucky container, as well as the default `hasura` and `postgres` containers ready to rock and roll!

### script/down

This script does the reverse of `up`. It removes the containers so that you go back to a clean slate. It's expected that a normal development cycle will use `script/up` and if things need to get reset a quick `script/down && script/up` should do the job. If you just want to stop containers without deleting them, `script/down` is not what you are looking for. If you are looking for a _deep_ deep reset, you'll need to at least delete the lucky image (or adjust `up.yml` to do a rebuild).

WARNING: I haven't tested this script on a machine where I have multiple Docker projects, so this might have unexpected side effects like stopping or removing containers/volumes unexpectedly. It shouldn't, but it's not properly tested.

### script/test

This script can run in two modes. If you pass an argument, it runs in production mode for testing production images locally. I'll describe that more in the production section below. With no argument, it spins up test copies of Hasura and Lucky in different containers and on different ports than `script/up` and then drops you into a shell session in the `foo_bar_lucky_test` container. From there you can run `crystal spec` or just generally play around. Once you are done, you can exit the shell session and the test script will clean up afterward (remove the containers and related volumes).

It is important that you use this script (or something similar to it) to run tests since we are sharing a hard-coded `DATABASE_URL` between Lucky and Hasura. Your tests will run on whatever database that URL is set to and since tests truncate the database, you could end up truncating your development database at an inopportune time. This script also has the advantage of setting things up properly so that Hasura is available for API calls in the test suite.

It won't hurt anything, but I recommend that you delete `spec/setup/setup_database.cr` since `script/test` covers this need.

### Other Scripts

The other scripts are all for production, so you can read about them further down in the `production` section of this guide. Or if you're not planning on using the production tools here you can just delete them.

## Setup Hasura

I think now is the right time to get our feet wet in Hasura land a little bit. We want to be able to hit a Lucky endpoint with an email and password and get an account, and then hit it again to get a JWT token that we can pass to Hasura to get our own email address back to us but not someone else's. This will involve editing some Lucky files and doing a little setting up on the Hasura side and is a nice introduction to the core reason this is being done: to separate our Business logic (DB management, authentication, nightly biller, etc.) from our front-end logic (GraphQL).

Now let's seed the database with two users. An admin user and a regular user. Just add these lines to the `call` method in `tasks/create_required_seeds` if you want them available in production (like I do for the demo) or to `tasks/create_sample_seeds` if you want them only in development.

```crystal
%w{admin buzz}.each do |name|
  email = name + "@foobar.business"
  user = UserQuery.new.email(email).first?
  UserBox.create &.email(email) unless user
end
```

And then you can run `up lucky db.create_required_seeds` and they'll be added to your database (the `up` command here will spin up a lucky container and run the command there). You'll be able to see that for yourself pretty quickly if you go to [localhost:9695](http://localhost:9695/) (your Hasura Console). From there you can view the `users` table (if you are tracking it).

Next, we'll need to get Lucky to produce the kind of JWT that Hasura can understand. Go into `src/models/user_token.cr` and replace the `payload` with

```crystal
allowed_roles = ["user"]
default_role = "user"
# VERY BAD IDEA - DEMO ONLY
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

Please don't use this in production for determining roles, this is just a demo! When the time comes to actually determine how you want to handle authentication, you should read Hasura's excellent documentation on [JWT authentication](https://hasura.io/docs/1.0/graphql/manual/auth/authentication/jwt.html).

Note: If you watch the Docker logs in your `foo_bar_lucky` container, you should notice that as soon as you save changes to this file, the app recompiles. You don't need to do anything else to build or serve the app, just save changes, and wait a second for it to recompile.

Now we should be able to post the username and password to `localhost:5000/api/sign_ins` and get back our JWT:

```shell
curl localhost:5000/api/sign_ins -X POST -d "user:email=admin@foobar.business" -d "user:password=password"
```

(If you look in `spec/support/boxes/user_box.cr` you'll see that the default password is "password".)

Notice that the top-level key is `user`, so if you wanted instead to POST json it would be in this shape:

```json
{
  "user": {
    "email": "admin@foobar.business",
    "password": "password"
  }
}
```

And you can paste the token into your favorite JWT inspector ([jwt.io](https://jwt.io) is mine) and you should see that `admin` has the `admin` role and `user` has only the `user` role. So far so good. Now let's make a GraphQL query to Hasura. I'd recommend using a nice tool like [Insomnia](https://insomnia.rest/) for this, in that application you can [chain requests](https://support.insomnia.rest/article/43-chaining-requests) and hence use the response from the sign-in request as the `Bearer` token in the other and they even have a `graphql` mode that just lets you paste GraphQL in. Pretty spiffy.

![Screenshot of setting up chained insomnia request](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/img/insomnia-chain.jpg)

Please read the Hasura docs and the docs of your favorite API-testing tool until you can post the following GraphQL to [localhost:8080/v1/graphql](http://localhost:8080/v1/graphql) using the token you got from your admin sign in.

```graphql
query MyQuery {
  users {
    email
  }
}
```

and receive in response

```json
{
  "data": {
    "users": [
      {
        "email": "admin@foobar.business",
      },
      {
        "email": "buzz@foobar.business",
      }
    ]
  }
}
```

Now, if you try that with the token you get from signing in as `buzz` you'll get the following

```json
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

![hasura permissions screen](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/img/user-permissions.jpg)

I just entered a new role called 'users' and edited the 'select' permission to allow a user to query their own email. Now the response is

```json
{
  "data": {
    "users": [
      {
        "email": "buzz@foobar.business"
      }
    ]
  }
}
```

As a last check, you should see that `db/hasura/metadata/tables.yaml` now looks like this:

```yaml
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

Now let's add the above to our Lucky test suite. Here's an example file that gets the job done. I'm not saying this is an ideal way to test, I would actually prefer to abstract this out a little so that I could have a GraphQL request helper and a config file for example, but for the purposes of demonstration, it's easier to keep it in a single file. Go ahead and add this to `spec/requests/graphql/users/query_spec.cr` if you want to copy the pattern Lucky ships with. Then run `crystal spec` in your test container.

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

# returns [{"email" => "buzz@example.com"}]
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

Though I don't recommend following exactly the above as a kind of 'best practice', I do recommend understanding what's going on in there and implementing something like it since making sure you didn't break your GraphQL endpoint recently is a good idea.

### From Development to Production

And now, it is decision time. If you're not much interested in deploying your project to a server whenever you push to a special branch then you should delete the provided `.gitlab-ci.yml` and this is where we part ways. Good luck to you, please feel free to open an issue or a PR to improve this project in making it more geared towards people like yourself. I'd be happy to support you and them here :)

If you are however interested in getting some of the awesome benefits I've put together here, then the next step will be to start thinking about deployment.

## Lucky + Hasura via Docker in Production

OK, now for the juicy stuff. The above is nice and all, but we can go way further. We can use [Traefik](https://containo.us/traefik/) to put up a load-balanced reverse-proxy to our Docker Swarm. We can have Lucky queries going to some containers and GraphQL queries going to others. (Yay *real* microservices! Once, while developing this workflow, I had my Lucky service down for days and didn't notice because I was just testing the GraphQL and had no other alerts set up.) These things are actually independent. I love that. And with a few keystrokes, we can scale up and down to match needs. Maybe we have a bunch of mobile users hammering the GraphQL endpoints but the Lucky server is kinda bored. No problem, just scale up that Hasura service! To keep an eye on everything, a separate swarm for monitoring tools under the [Prometheus](https://prometheus.io/) umbrella are available and we bring that swarm online with an easy one-liner.

What's more, is Gitlab can do the heavy lifting for us with respect to building and tagging images. If there's an issue with a deployment on staging, we can use the rollback script to go back to a previous image and database state since the images are tagged by git commit. I'm even experimenting with two kinds of migrations: "additive" and "subtractive" to go for a perfect zero-downtime history. If you're interested in these ideas read on, the main motivation for building all of this was to achieve DevOps Nirvana and if the below isn't it, then I hope it's close enough that the community can help me get it the rest of the way there. We'll have to sacrifice a bit though, some of the details of a real production deployment get a little hairy but it's worth it in the end.

First we have a few things to do to get ready.

1. Prepare the production machine / environment
2. Add a health check endpoint to Lucky so that Docker Swarm can determine if our Lucky containers are running well.
3. Put some ssh credentials into Gitlab so that the CI can reach into production and run code.

### Staging and Production Servers

The first thing we need to do is get some servers up somewhere. It's not terribly important how you choose to do this, so please feel free to skip to the next major heading if you've got your own plan. Otherwise, I'll go ahead and describe how I did this with [DigitalOcean](https://www.digitalocean.com) and [Cloudflare](https://www.cloudflare.com).

(Sidenote: for a real project, I'm a fan of the idea of having a dedicated "staging" server, so later it'll come up that we, in fact, have two servers here with slightly different purposes but identical configuration.)

With DigitalOcean (DO) we can spin up a little hobby server for $5 per month. I don't want to go too far astray from the topic here, so I'll leave it to you to do a little googling and learn how to use it. I will point out however that the [DigitalOcean 1-click Docker app](https://marketplace.digitalocean.com/apps/docker) is pretty convenient. They can setup ssh-only access for you before you even create the droplet which is a great starting place security-wise.

Whether you use DigitalOcean or AWS or a box in your basement, you'll want to be sure you do a little reading on using Docker in production. There are some settings that you'll want to get right for security reasons, and plenty of reading material out there to get you started. So please address this now. (But don't log into Docker yet on the new box, we'll be logging into your Gitlab repo's Docker registry since this box will need to talk to your custom-built images).

Next, I recommend:

1. `ssh`ing into the server as root and then creating a non-root account. I'll call that account `lhd` but you can pick what you like:

   ```shell
   useradd -m -d /home/lhd -s /bin/bash lhd
   usermod -a -G docker lhd
   mkdir /home/lhd/.ssh
   cp ~/.ssh/authorized_keys /home/lhd/.ssh
   chown -R lhd:lhd /home/lhd/.ssh
   chmod 700 /home/lhd/.ssh
   chmod 600 /home/lhd/.ssh/authorized_keys
   ```

   This setup copies the authorized keys from root to the user so that you can still log in with the same key you were using to log in as root. It also adds `lhd` to the docker group.

2. In the DO droplet, we use `ufw` (Uncomplicated Firewall) and since we'll be serving from this box we'll need to `ufw allow` a couple of ports: 80 and 443. You can use `ufw status` to see a list of ports that are allowed. 2375 and 2376 are used by docker for communication between instances, this is so that you can have droplets participate in the same Docker network.
3. In your Gitlab repository, provision two Deploy Tokens under `Settings > Repository`.
    1. The first one will be used during CI/CD. It must be named `gitlab-deploy-token` and you should select at least the `read_registry` scope. You don't need to save the username or token anywhere, this is only used by Gitlab. (Read more about deploy token at [docs.gitlab.com/ee/user/project/deploy_tokens/#usage](https://docs.gitlab.com/ee/user/project/deploy_tokens/#usage)).
    2. The second token will be used to log in to the Gitlab Docker registry from your server. Give it a meaningful name and (at least) read access to both the registry and the repository. We'll save these values in a special `.lhd-env` file in the next step.

    Another secret we need is `SEND_GRID_KEY`. This comes from [sendgrid.com](https://sendgrid.com/) and is simply a convenient Lucky default for handling emails: [luckyframework.org/guides/deploying/heroku#quickstart](https://luckyframework.org/guides/deploying/heroku#quickstart). You'll have to go sign up with them and generate an API key.

    Once you have these three special values, save them in a new file on the server called `.lhd-env` and place it in the home directory of your non-root user (`lhd`):

     ```shell
     # in ~/.lhd-env
     export DEPLOY_USERNAME='gitlab+deploy-token-######'
     export DEPLOY_TOKEN='en3Z4e7GafxRp4i1Jx0'
     export SEND_GRID_KEY='SG.ALf_3xkHTRioKaeQ.APYYxwUdr00B1ypHuximcjNBmOxET1gV8Q'
     ```

**Note on `.lhd-env`** - We are storing a lot of sensitive information in this special file. There are more heavy-duty solutions to secret storage / use in Docker please read up on those and choose the number of layers of security you'd like to have. For this guide I recommend that you `chmod 600` this file. I chose not to use the `.env` file Lucky is looking for because it's not available before the repo is cloned, and it doesn't support exporting variables for use by others that need them like Traefik and Hasura.

Next, we can do our DNS and security certificates through Cloudflare (for free). The first thing you'll need is a domain, so go get one of those. For the next steps, I won't go into too much detail since I want to let Cloudflare maintain their own docs (see [support.cloudflare.com/hc/en-us/articles/End-to-end-HTTPS-conceptual-overview](https://support.cloudflare.com/hc/en-us/articles/360024787372-End-to-end-HTTPS-with-Cloudflare-Part-1-conceptual-overview)) but here are some basic steps. Please note that the process of creating a domain and provisioning certificates for it can be time-consuming. If you get to a step and don't see a button or get a weird error like "this zone is not part of your account" then you probably just need to wait a few minutes (or as much as two days). Sorry, such is the nature of real production work. My experience is that I can do the following in 15 minutes without hassle:

1. Setup some special CNAME's on the DNS page for various Docker services which we'll be setting up: `api`, `traefik`, and `grafana` is a good enough start.

    ![docker dns](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/img/cloudflare-dns.jpg)

2. Use the "Full (Strict)" encryption mode, don't use automatic `http => https`, and don't use HSTS enforcement, otherwise you'll get into a redirect loop (we'll be using an origin certificate and Traefik will handle that enforcement/redirect).

3. Create a `.cert` and `.key` origin certificate pair and place them in `etc/certs` on the server (production for now, but you'll do this again for staging). The name / path here are used by the scripts so please double-check them:

    ```shell
    etc/certs/cloudflare.cert
    etc/certs/cloudflare.key
    ```

    ![docker certs](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/img/cloudflare-origin-certs.jpg)

**Note**: If you'd rather use a different path you just need to put it `Docker/traefik/config/tls.yaml`.

#### script/deploy

The final CI stage is deployment. This involves three scripts in total. The first is `ci_deploy` which the CI server uses to ssh into the production/staging server. The `bootstrap` and `deploy` scripts are run on the staging/production servers. `bootstrap` is mostly responsible for generating credentials and storing them in the `~/.lhd-env` file. It makes the first clone of your repo and starts the docker swarm (**Security note** that means it prints the `join token` to the CI runner log. You may want to `rotate` the join token after the first bootstrap: [join token docs](https://docs.docker.com/engine/reference/commandline/swarm_join-token/).). `deploy` checks out a named commit and pulls down an image for that commit. The next thing it does is deploy the stack and in order to do that it needs knowledge of two things:

```shell
export APP_DOMAIN='foobar.business'
export IP_ADDRESS='104.248.51.205'
```

So place these values in `.lhd-env` or in `~/.profile` as you like. `ci_deploy` uses a login shell so it will pick up `.profile` vars, then `bootstrap` and `deploy` `source` the `.lhd-env` file.

You'll see in the `bootstrap` script that the secrets are randomly generated, and the postgres password uses hex characters to avoid URL encoding. Also take note that an `ADMIN_PASSWORD` is generated for you which you'll need to log into Traefik, Grafana and others.

`script/deploy` by default runs in 'additive deploy' mode but we can pass a `-s` flag to use 'subtractive deploy' mode. The idea here is that we can choose to have each deployment only add or subtract columns from the database. The difference between the two is simply the order we migrate the database and update the code. If we added columns / tables, then we need to migrate the database before updating the code since the old code won't ask for columns that didn't exist before. The reverse is true if we take away columns / tables.

NOTE: The first deployment has to "update" code before migrating because that function gets the stack going (i.e. starts services). So on the very first deploy we'll be using `script/deploy -s <arg>` via a special commit message. (You'll see that below when we talk about the first commit + push.) The `arg` here is either `production` or `staging` to determine which IP address and ssh key to use in deployment.

Please do have a look at `docker-compose.prod.yml` and `docker-compose.swarm.yml`. You'll see again some of those env variables that are needed to get this started being passed into containers. You'll also see some `deploy` keys being used which start us off with just 1 replica of each service. If you have trouble with the first deploy, the issue may be resolved by double-checking that you understand these two files.

You'll notice that the `update_code` function (called from script/deploy) uses the following to deploy:

`docker stack deploy -c Docker/docker-compose.yml -c Docker/docker-compose.prod.yml -c Docker/docker-compose.swarm.yml SWARM_NAME --with-registry-auth` so you'll want to understand those files. Note also that `with-registry-auth` flag is there so that you can pull images from the registry. We'll get more into that in the CD section.

#### Traefik

Let's turn our attention to how it is we connect the wide world to our Lucky and GraphQL services. [Traefik](https://traefik.io) (pronounced the same as traffic) is a reverse proxy which routes requests to docker services based on request parameters. In the LHD example, if someone requests `api.foobar.business/v1/graphql` that request will go to Hasura and if it makes any other `api.foobar.business` request they'll go to Lucky.

There are two places to look for Traefik configuration, let's start with `docker-compose.swarm.yml`. This file defines some swarm-only keys like 'deploy' and the Traefik service. As we look through the YAML, the first thing we see is that it adds some `traefik` rules to the Hasura and Lucky services. You'll likely want to change these to suit your own tastes, so I recommend you read their docs, for example: [docs.traefik.io/routing/overview](https://docs.traefik.io/routing/overview/).

The next thing I want you to notice is the service called `traefik-docker-link`. This piece is needed to avoid a security issue which arises from Traefik needing access to the docker socket and that giving it potential admin privileges. The Traefik docs point to a lot of good resources on this issue: [docs.traefik.io/providers/docker](https://docs.traefik.io/providers/docker/#docker-api-access) if you want to dive in. One resource they point to is Docker's own docs: [docs.docker.com/engine/security/security/#docker-daemon-attack-surface](https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface).

The other place that Traefik config is stored is in `Docker/traefik`. Since Traefik 2.0 the static config is in `Docker/traefik/traefik.yml` while the dynamic config is in (1) service labels (in the docker-compose file) and (2) in `yml` files in `Docker/traefik/config`.

If you have any other questions about this aspect of things, try to read through and understand the docker-compose setup we have here. There's a lot going on and it took a long time to figure out with lots of debugging. Hopefully, for you, it'll just work.

## Health Checks

In deployment, we'll be using docker swarm so you may also notice the `script/docker/*healthcheck` files. These are little scripts that run every so often and make sure the services are healthy. You can read more about them here: [docs.docker.com/compose/compose-file/#healthcheck](https://docs.docker.com/compose/compose-file/#healthcheck).

LHD includes a health check for Lucky that makes sure it has a good DB connection. You might wonder why we don't just use `curl` for the health check and the answer is that we could. I chose to do a demo health check in Crystal because I want to open the door to a more meaningful health check. As your application logic gets more complex, you may have a more complex definition of 'healthy' beyond a simple 200 coming back somewhere. At any rate, the one I've included here relies on us creating a `version` route so we'll do that now.

First uncomment the healthcheck lines in `docker-compose.prod.yml` under the `lucky` service, then we'll create our first model: `version`. First, open a shell in the lucky container with `docker exec -it foo_bar_lucky /bin/bash` (or `up ssh`). And then run `lucky gen.model Version`. You should get something like

```shell
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

Next, we'll add a route to `GET` the current version. Put the following in `src/actions/version/get.cr`

```crystal
class Version::Get < ApiAction
  include Api::Auth::SkipRequireAuthToken
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
current_version = `git rev-parse --short=8 HEAD 2>&1`.rchop
current_version = "pre-first-commit" unless $?.success?
last_version = VersionQuery.last?
version_is_same = last_version && last_version == current_version
SaveVersion.create!(value: current_version) unless version_is_same
```

### Gitlab Variables

Let's head on over to "Settings > CI/CD" under the "Variables" heading. There you'll need to create two variables.

1. `GITLAB_PRODUCTION_KEY` contains the SSH private key of an ssh keypair where the public key is already in the production server's `/home/lhd/.ssh/authorized_keys` file. I recommend you generate a special key for this. This gives us ssh access for the deploy step. I added these as type 'var' and not file. Be sure to update `ci_deploy` to ssh as whatever user you you've set this up for. These examples are for an `lhd` user.

   ```shell
   ssh-keygen -t ed25519 -C “gitlab-ci@foo_bar_production” -f ~/.ssh/gitlab-ci
   ssh-copy-id -i ~/.ssh/gitlab-ci lhd@foobar.business
   # save the private key as the `GITLAB_PRODUCTION_KEY` Gitlab CI variable
   ```

2. The second variable is simply the IP address of the manager node where deployments are headed: `PRODUCTION_SERVER_IP`.

With those things in place, you'll be able to deploy to the server automatically whenever a commit lands in `master` (or `staging` once you do the above on a staging server). That is, of course, assuming you have your servers set up properly.

## First Push and Beyond

OK, we are finally ready to commit and push and see all these moving parts in action! Once a branch has been pushed to, that push will create a Pipeline on Gitlab.com which will run `script/build` and `script/test`. I recommend you study the `.gitlab-ci.yml` file and check your understanding of what this file is telling the pipeline to do.

(Note: any `scripts` you want to run here like `script/test` or `script/build` must either be a `sh`ell script (not bash) or you need to install bash on the docker image. If you fail to do this, you'll get a cryptic message `/bin/sh: eval: line 98: script/test: not found` which seems like it's saying 'file not found' but what it's really saying is '`sh` file not found' and it is unaware that you have a `bash` script in that exact location.)

The most unique thing here is perhaps the `tag` step where we tag an image both with a commit reference via the GitLab-provided variable `$CI_COMMIT_SHORT_SHA` as well as the branch name via `$CI_COMMIT_REF_NAME`. The result is that the most recent / current image is tagged by branch name and by commit reference. On the next build, that can be used as a cache reference to save build time. This idea and many other things are borrowed / adapted from [blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices](https://blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices/).

Anyways, let's get on with our first push. This one uses the `sub-deploy` keyword to trigger a `subtractive` deploy and hence start the docker stack before trying to run migrations.

```shell
git add .
git commit -m 'first commit [sub-deploy]'
git remote add origin <url>
git push -u origin master
```

You should expect to see your image get built and stored in your project's GitLab docker registry under two tags, one with the commit ref and another with the branch name. This will make it easy in the future to jump to any older image you had before as well as whatever the 'latest' image was to be built on a given branch.

If all went well, after a minute or two you can go to `api.foobar.business/version` and see the version JSON served. Or post GraphQL queries to `https://api.foobar.business/v1/graphql` (first you'll need a token by signing in `https://api.foobar.business/api/sign_ins`). If so then congratulations we're up and running!!

If not, you can check the status of your swarm from the production server. There are a lot of swarm commands and they are different than non-swarm commands so you might want to reference a [cheatsheet](https://www.google.com/search?q=docker+swarm+cheat+sheet). If you are getting any errors at all that could mean that these instructions don't match the versions you are using, or that you missed one of the steps described above. Be sure you are working from a tagged commit of this repo and feel free to open an issue to chat. Even (especially?) if it's a problem you were able to solve. I want a project created from this toolset to get up and running automatically on the first deploy!

It's great to have a real server up, right? But sometimes things go wrong between local development and production. I hate it when that happens so the following tools make solving those kinds of problems much easier. Let's now turn out attention to when things go wrong with the following features:

1. We can use commit messages to control which stages run in CI/CD.
2. We can test the CI image locally.
3. We can roll back changes if stuff goes wrong.
4. We can monitor our production swarm and get alerts

### Commit Message Flags

Each job in the `.gitlab-ci.yml` file has a property like this:

```shell
except:
  variables:
    - $CI_COMMIT_MESSAGE =~ /no-deploy/
    - $CI_COMMIT_MESSAGE =~ /build-only/
    - $CI_COMMIT_MESSAGE =~ /tag-only/
    - $CI_COMMIT_MESSAGE =~ /test-only/
```

That makes that stage the only one that runs when `*-only` is found in the commit message or the one that is skipped when `no-*` is found in the commit message. This can be useful, for example, when you're not changing the image but need a new build or deploy. Or when you just want to run tests on a previous build.

### Testing Production Images

You might notice that the test stage follows the build stage. The idea here is that we want to test our production image so we have to build it first. But if you have an unexpected test failure (remember, that a push to master or staging is a deploy, so you shouldn't push code you haven't tested locally anyways) you could get into a situation that is hard to debug, no one wants to debug a testing issue that only happens on CI!

The solution is to pass an argument to `script/test`. This will cause the test script to run in CI mode and will pull whatever image you like based on the tag name that you pass to `script/test`, so if you want to test the latest push to staging then

```shell
script/test staging
```

If your repo is private, then you'll need to log into the Gitlab repo in order to pull that image down locally. The first time you log in to the GitLab registry on that machine, the script will prompt you to enter your username and password or you can set up either an access or a deploy token see the [Gitlab registry docs](https://docs.gitlab.com/ee/user/packages/container_registry/#authenticating-to-the-gitlab-container-registry). Afterwards Docker will just reuse the credentials since it stores them.

### script/rollback

The rollback script requires one argument: the version you want to roll back to. Since our images are tagged by commit SHA that means providing the first 8 characters of the commit SHA you want to go back to. If you've checked out that commit in the terminal, this is just the output of `git rev-parse --short=8 HEAD`.

You can also provide the `-s` flag just like `deploy` to signal whether you want to reverse an additive change (default) or a subtractive one.

```shell
script/rollback -s 08f4ea31
```

This script will grab the image with the tag you specified and use it to determine which migrations to rollback. Then it'll roll those back and launch the image you named, with those two steps happening in either order based on the `-s` flag.

## Monitoring with swarmprom

I mentioned before that in addition to Traefik routing we can provide some monitoring with Prometheus. This is done with a separate swarm that is configured in the directory `prometheus-swarm`. For really excellent application monitoring you can either pay money or use this fairly complex docker swarm for free. I'm really glad that someone else already solved this problem: [github.com/stefanprodan/swarmprom](https://github.com/stefanprodan/swarmprom.git). In this repo, I've adapted that repo somewhat to fit the needs of this project.

This toolset can monitor your services, give you real-time graphs looking at memory usage, CPU usage, and much more across services and nodes, it can even send you Slack notifications when an alert is triggered (like memory getting too high). I think a good intro to this tool is the README:

[github.com/stefanprodan/swarmprom](https://github.com/stefanprodan/swarmprom)

Do give that a read (starting at the Traefik heading perhaps), at least you'll see some screenshots to give you an idea of what we're gaining by having this here. I see a lot of forks of that repo and some out of date connections. I don't intend right now for swarmprom to be a hard dependency, so consider my including it here simply a launching point for your own production monitoring services. Notice that in order to take full advantage you'll want some more CNAME's as their README suggests:

* grafana.foobar.business
* alertmanager.foobar.business
* unsee.foobar.business
* prometheus.foobar.business

Before we can start that Swarm, we might want to add some Slack vars to take advantage of an automatic Slack integration. We can of course instead just set these up in the Grafana dashboard later so it's up to you. If you do want to start now though you'll need to set up an incoming webhook: ([slack.com/intl/en-ca/help/articles/115005265063-Incoming-Webhooks-for-Slack](https://slack.com/intl/en-ca/help/articles/115005265063-Incoming-Webhooks-for-Slack)). Then paste the following into your `.lhd-env` file.

```shell
export SLACK_URL='https://hooks.slack.com/services/A61J43A7/AK9I23U17/qaGCB6TKZVF1HRng0WqTEaeX'
export SLACK_CHANNEL='lhd-demo'
export SLACK_USER='Prometheus'
```

Then you can just firs up the swarm:

```shell
cd ~/foo_bar/Docker/prometheus-swarm
docker stack deploy -c docker-compose.yml prometheus_swarm
```

Then to see how those services are doing (hopefully all 1/1 Replicas) you can run

```shell
docker stack services prometheus_swarm
```

For example. Once grafana is up, head on over to `grafana.foobar.business` and sign in with the username and password in `~/.lhd-env` (generated by the `bootstrap` phase of deploy, see above). You'll see some default dashboards and can play around! [Read their docs](https://grafana.com/docs/grafana/latest/getting-started/what-is-grafana/) and finish setting up your alerts as you like.

I feel like I should write more since there's a bunch going on under the hood here, but I'll let those interested read the `docker-compose` file, it has all the details. In production I have another CNAME record for `grafana.foobar.business` and I can do my monitoring from there.

Take note! Putting all of the above on one $5 box on Digital Ocean uses ~80% of the RAM. I would recommend leaving off the monitoring tools while developing and then once the big release day comes upgrading a few bucks a month or putting your monitoring tools on a different box (that box just has to join the swarm, your local box could join the swarm for example).

![Screenshot of Grafana Dashboard with foo_bar and prometheus swarms](https://github.com/KCErb/lucky-hasura-docker/blob/v0.2.0/img/grafana-dashboard.jpg)

## Conclusion

If you read through all of the above and it all worked perfectly: awesome! Let me know to motivate me to keep this project up to date.

I'm afraid it's quite likely though that somewhere along the way some bump came along that you just couldn't resolve or that proved me wrong. If so, please open an issue in this repository. I'd love to fix mistakes and improve on the write-up. I might not agree that a section needs to be written on how to do X, but I'm always happy to have links to documentation and other write-ups that explain some aspect or another in more detail.
