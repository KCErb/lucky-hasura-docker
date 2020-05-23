# TL;DR

The guide is quite long! If you want to just get a proof of concept running go ahead with these instructions.

## Basic Up and Going

1. Make sure you have `docker`, [`lucky`](https://github.com/luckyframework/lucky_cli), and [`up`](https://github.com/paulcsmith/up) commands.

   ```shell
   docker -v # => 19.03.8
   lucky -v  # => 0.21.0
   up -v     # => 0.1.7
   ```

2. Do the following

   ```shell
   mkdir lhd-test
   cd lhd-test
   git clone https://github.com/KCErb/lucky-hasura-docker
   lucky init.custom foo_bar --api
   cd lucky-hasura-docker
   ```

3. Replace project variables. `sed` is different on Linux and macOS :(

   **Linux**

   ```shell
   git grep -l 'GITLAB_USER' | xargs sed -i 's/GITLAB_USER/kcerb/g'
   git grep -l 'GITLAB_REPO_NAME' | xargs sed -i 's/GITLAB_REPO_NAME/foo_bar/g'
   git grep -l 'PROJECT_NAME' | xargs sed -i 's/PROJECT_NAME/foo_bar/g'
   git grep -l 'SWARM_NAME' | xargs sed -i 's/SWARM_NAME/foo_bar/g'
   ```

   **macOS**

   ```shell
   git grep -l 'GITLAB_USER' | xargs sed -i '' -e 's/GITLAB_USER/kcerb/g'
   git grep -l 'GITLAB_REPO_NAME' | xargs sed -i '' -e 's/GITLAB_REPO_NAME/foo_bar/g'
   git grep -l 'PROJECT_NAME' | xargs sed -i '' -e 's/PROJECT_NAME/foo_bar/g'
   git grep -l 'SWARM_NAME' | xargs sed -i '' -e 's/SWARM_NAME/foo_bar/g'
   ```

4. Do the following

   ```shell
   cd ..
   # modify foo_bar a bit
   rm -rf foo_bar/script
   rm foo_bar/Procfile
   rm foo_bar/Procfile.dev
   echo '\nup.cache' >> foo_bar/.gitignore
   # rsync contents of template dir into foo_bar
   rsync -avr lucky-hasura-docker/proj_template/ foo_bar
   cd foo_bar
   ```

5. In `config/server.cr` you should see a line that starts with `settings.secret_key_base =` (line 17). Replace it with `lucky_hasura_32_character_secret`.

6. Now you can start developing with

   ```shell
   script/up
   ```

## Production Instructions

1. Provision a production server somewhere.
   * Ensure that ports 80 and 443 are available to the public.
   * Save the SSL `.cert` and `.key` files as `/etc/certs/cloudflare.cert` and `/etc/certs/cloudflare.key`.
   * Create a non-root user (`lhd` for example) and make sure you can ssh into the server as that user.

     ```shell
     ssh lhd@foobar.business
     ```

2. Provision two deploy tokens from Gitlab `Settings > Repository`. Name one `gitlab-deploy-token`, it will be used in CI so you don't need to save its username or password. Name the other whatever you like, give it at least both read scopes, and be sure to copy the username and password for step 4.

3. Create an account/API key on [SendGrid](https://app.sendgrid.com), copy the value for the next step.

4. Create a `.lhd-env` file in your home dir and place the Gitlab credentials and SendGrid API key (`chmod 600` this file to add a layer of security):

   ```shell
   export DEPLOY_USERNAME='gitlab+deploy-token-170337'
   export DEPLOY_TOKEN='8yQesUWt4MaHJ8T4d6hc'
   export SEND_GRID_KEY='SG.ALd_3xkHTRioKaeQ.APYYxwUdr00BJypHuximcjNBmOxET1gV8Q'
   ```

5. Add the following variables to your environment using your own values. You can use `.lhd-env` or `.profile` since the CI runner uses a login shell.

   ```shell
   export APP_DOMAIN='foobar.business'
   export IP_ADDRESS='104.248.51.205'
   ```

6. On Gitlab also save that IP address as a variable under `Settings > CI/CD` with the name `PRODUCTION_SERVER_IP`.

7. Generate a keypair.

    ```shell
    ssh-keygen -t ed25519 -C “gitlab-ci@foo_bar_production” -f ~/.ssh/gitlab-ci
    ```

8. Add the private key to the CI env as `GITLAB_PRODUCTION_KEY`.

9. Copy the public key to the server

    ```shell
    ssh-copy-id -i ~/.ssh/gitlab-ci lhd@foobar.business
    ```

## First Push

1. No travis in this Gitlab project

   ```shell
   rm .travis.yml
   ```

2. Add everything, commit, and push. The `sub-deploy` keyword runs the `deploy` script functions in the required order for the first push.

   ```shell
   git remote add origin git@gitlab.com:KCErb/foo_bar.git
   git add .
   git commit -m "first commit [sub-deploy]"
   git push -u origin master
   ```

3. Once the deploy stage has passed CI, you can log in to the server and see progress with `docker service ls`. You should see `1/1` for all replicas once everything is online. It might take a minute the first time.

**Security Note** - You may want to `rotate` the join token after the first bootstrap since it is printed to the Gitlab CI history. [Read more about join tokens](https://docs.docker.com/engine/reference/commandline/swarm_join-token/).

## Extras

### Monitoring with Swarmprom

1. (Optional) Add slack credentials for automatic slack alerts to `.lhd-env`.

   ```shell
   export SLACK_URL='https://hooks.slack.com/services/G11G430A7/AK9023U17/vaGCB6T6ZVF1HRng0WqTEaeX'
   export SLACK_CHANNEL='lhd-demo'
   export SLACK_USER='Prometheus'
   ```

2. Start the swarm (be sure that `APP_DOMAIN` is defined via `source ~/.profile` if you haven't logged out yet):

   ```shell
   source ~/.lhd-env
   cd ~/GITLAB_REPO_NAME/Docker/prometheus-swarm
   docker stack deploy -c docker-compose.yml prometheus_swarm
   ```

3. Once the services are up, log in and play around, visit `grafana.foobar.business`. The password was generated by the `bootstrap` script and is stored in `~/.lhd-env` as `ADMIN_PASSWORD`. The username is `PROJECT_NAME_admin`.

### Seed Database, Test Lucky, Test Hasura

1. Add this to the `call` method of `tasks/create_required_seeds` (WARNING: if you don't want these in production add them to `create_sample_seeds` instead)

   ```crystal
   %w{admin buzz}.each do |name|
     email = name + "@foobar.business"
     user = UserQuery.new.email(email).first?
     UserBox.create &.email(email) unless user
   end
   ```

2. Replace `payload` variable in `src/models/user_token.cr` in the `self.generate` method with

   ```crystal
   # (demo ONLY, not a good way to assign roles!!!!)
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

3. Add `user` role in Hasura dashboard [localhost:9695](http://localhost:9695/) with permission to select their own email.

4. Add `spec/requests/graphql/users/query_spec.cr` file with contents

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

   # returns [{"email" => "user@example.com"}]
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

5. While we're messing with tests, this file is basically harmless but not needed, so delete

   ```shell
   rm spec/setup/setup_database.cr
   ```

6. Run `script/test` to start a shell session in a special test environment.

### Healthcheck

1. Uncomment the `healthcheck` lines in `docker-compose.swarm.yml` under the `lucky` service.

2. Add the `version` route for health checks by running the following in the `lucky` container.

   ```shell
   lucky gen.model Version
   ```

3. Add a table by replacing the contents of `src/models/version.cr` with:

    ```crystal
    class Version < BaseModel
     table :versions do
       column value : String
     end
    end
    ```

4. Update the corresponding migration by adding 1 line in the create block `add value : String`. My file looks like this:

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

5. Migrate and seed in the `lucky` container.

    ```shell
    lucky db.migrate && lucky db.create_required_seeds
    ```

6. Add a route to `GET` the current version. Put the following in `src/actions/version/get.cr`

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

7. Add some logic to `tasks/create_required_seeds.cr` so that each time the required seeds are created we make sure the latest version number is provided:

    ```crystal
    current_version = `git rev-parse --short=8 HEAD 2>&1`.rchop
    current_version = "pre-first-commit" unless $?.success?
    last_version = VersionQuery.last?
    version_is_same = last_version && last_version == current_version
    SaveVersion.create!(value: current_version) unless version_is_same
    ```

8. Test from the host

   ```shell
   curl localhost:5000/version
   ```

### Rollback/Deploy to version

Rollback and Deploy scripts are provided. To rollback to a certain image you just need to provide the tag of the image (first 8 characters of commit sha where that image was built)

```shell
script/rollback 53c086ec
```

If you want to fast-forward to a later commit, you can give its short-sha (first 8 characters) to the deploy script

```shell
script/deploy 8d9b3d0c
```

In both cases the `-s` flag can be passed to signal `subtractive` mode as described in the guide.
