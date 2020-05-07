# Basic Up and Going

1. Make sure you have `docker`, `lucky`, `ruby`, and `up`.
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
   echo '\n.docker-sync/\nup.cache' >> foo_bar/.gitignore
   # rsync contents of template dir into foo_bar
   rsync -avr lucky-hasura-docker/proj_template/ foo_bar
   cd foo_bar
   ```

5. In `config/server.cr` you should see a line that starts with `settings.secret_key_base =` (line 17). Replace `DEV_SECRET_KEY_BASE` in the project with the value you find there. (No `sed` one-liner here, too many potential regex chars in the key_base.)

6. Run the project to make sure it works

   ```shell
   script/up
   ```

## Seed Database, Test Lucky, Test Hasura

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

   # returns [{"email" => "user@foobar.business"}]
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

6. Run `script/test` to prove tests work as expected.

## Production Instructions

1. Provision a production server somewhere
2. Provision two deploy tokens from Gitlab `Settings > Repository`. Name one `gitlab-deploy-token`, it will be used in CI. Name the other whatever

   ```shell
   docker login registry.gitlab.com -u gitlab+deploy-token-#####
   ```

   Name the other whatever you like and store it in `.profile`.

   ```shell
   export GITLAB_USERNAME=gitlab+deploy-token-######
   export GITLAB_TOKEN=en3Z4e7GafxRp4i1Jx0
   ```

3. Ensure you also have the following variables in your environment. You'll have to generate them yourself. You can place them in `.profile`.

   ```shell
   export POSTGRES_USER=postgres_admin_foo_bar
   export POSTGRES_PASSWORD=JHMlT3pVyPdxezAssrMVlJKaU6wPHuximcPjkq1fvjfZl3fOA1InElfTL5
   export HASURA_GRAPHQL_ADMIN_SECRET=6wPux5JHMlT3pVyPd4xezAssrMalJKaU6wPHuPjkq1fvjfZl3BfO
   export POSTGRES_DB=foo_bar_production
   export APP_DOMAIN=foobar.business
   export SEND_GRID_KEY=SG.ALd_3xkHTRioKaeQ.APYYxwUdr00BJypHuximcjNBmOxET1gV8Q
   export SECRET_KEY_BASE=z8PNM2T3pVkLCa5pIMarEQBRhuKaU6waHL1Aw=
   ```

4. Change the last line of `.profile` from `mesg n || true` to `test -t 0 && mesg n`.

5. Put Docker in swarm mode on the production server (use your server's IP here not mine!)

   ```shell
   docker swarm init --advertise-addr 104.248.51.205
   ```

6. Add the following directory on the production server. This is where your database volume will live

   ```shell
   mkdir -p /home/docker/data
   ```

7. **Meanwhile, back in your git repo**
   Add the `version` route for health checks

   ```shell
   up ssh # ssh's into the lucky container
   # in container
   lucky gen.model Version
   ```

8. Add a table by replacing the contents of `src/models/version.cr` with:

   ```crystal
   class Version < BaseModel
     table :versions do
       column value : String
     end
   end
   ```

9. Update the corresponding migration by adding 1 line in the create block `add value : String`. My file looks like this:

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

10. Add a route to `GET` the current version. Put the following in `src/actions/version/get.cr`

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

11. Add some logic to `tasks/create_required_seeds.cr` so that each time the required seeds are created we make sure the latest version number is provided:

    ```crystal
    current_version = `git rev-parse --short=8 HEAD 2>&1`.rchop
    current_version = "pre-first-commit" unless $?.success?
    last_version = VersionQuery.last?
    version_is_same = last_version && last_version == current_version
    SaveVersion.create!(value: current_version) unless version_is_same
    ```

12. Migrate and test

    ```shell
    up ssh
    # in container
    lucky db.migrate && lucky db.create_required_seeds
    exit
    # back home
    curl localhost:5000/version
    ```

13. Generate keypair. Add private key to CI `GITLAB_PRODUCTION_KEY` and public key to server `~/.ssh/authorized_keys`

    ```shell
    ssh-keygen -t ed25519 -C “gitlab-ci@foo_bar_production”
    ```

## First push

1. No travis in this Gitlab project

   ```shell
   rm .travis.yml
   ```

2. The first push is no deploy, just build and tag and test.

   ```shell
   git add .
   git commit -m 'first commit [no-deploy]'
   git remote add origin <url>
   git push -u origin master
   ```

3. On the production server clone the repo in the home folder of root.

   ```shell
   ssh user@foo_bar_production_ip
   # On production server
   git clone https://$GITLAB_USERNAME:$GITLAB_TOKEN@gitlab.com/KCErb/foo_bar.git
   # git checkout staging if on staging server
   ```

4. Back on your local box, make a second commit

   ```shell
   git commit -am 'second commit [deploy-only][sub-deploy]'
   git push
   ```

5. After a minute or two, you can go to `api.foobar.business/version` and see the version JSON served. Or post GraphQL queries to `https://api.foobar.business/v1/graphql`

## Extras

### Monitoring with Swarmprom

1. Add some env vars (generate your own: `HASHED_PASSWORD` comes from `openssl passwd -apr1 $ADMIN_PASSWORD`)

   ```shell
   export ADMIN_USER=foo_bar_admin
   export ADMIN_PASSWORD=QIgvfT8folMq1Myvqq53kT3
   export HASHED_PASSWORD='$apr1$Vz7vV1p3$Ip0GEN62ah094Ehp2PFaq.'
   export SLACK_URL=https://hooks.slack.com/services/G11G430A7/AK9023U17/vaGCB6T6ZVF1HRng0WqTEaeX
   export SLACK_CHANNEL=lhd-demo
   export SLACK_USER=Prometheus
   ```

2. Start the swarm

   ```shell
   cd ~/foo_bar/Docker/prometheus-swarm
   docker stack deploy -c docker-compose.yml prometheus_swarm
   ```

3. Log in and play around, visit `grafana.foobar.business`.
