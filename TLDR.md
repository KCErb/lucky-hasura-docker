# Basic Up and Going

1. Make sure you have `docker` `ruby` and `up`.
2. Do the following

```
mkdir lhd-test
cd lhd-test
git clone https://github.com/KCErb/lucky-hasura-docker
lucky init.custom foo_bar --api
cd lucky-hasura-docker
```

3. Replace project variables. `sed` is different on linux and macOS :(

**Linux**
```
git grep -l 'GITLAB_USER' | xargs sed -i 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i 's/SWARM_NAME/foo_bar/g'
```

**macOS**
```
git grep -l 'GITLAB_USER' | xargs sed -i '' -e 's/GITLAB_USER/kcerb/g'
git grep -l 'GITLAB_REPO_NAME' | xargs sed -i '' -e 's/GITLAB_REPO_NAME/foo_bar/g'
git grep -l 'PROJECT_NAME' | xargs sed -i '' -e 's/PROJECT_NAME/foo_bar/g'
git grep -l 'SWARM_NAME' | xargs sed -i '' -e 's/SWARM_NAME/foo_bar/g'
```

4. Do the following

```
cd ..
rm -rf foo_bar/script
rm foo_bar/Procfile
rm foo_bar/Procfile.dev
rsync -avr --exclude='.git' --exclude='TLDR.md' --exclude='README.template' --exclude='img' lucky-hasura-docker/ foo_bar
mv lucky-hasura-docker/README.template foo_bar/README.md
echo '\n.docker-sync/\nup.cache' >> foo_bar/.gitignore
cd foo_bar
```

5. In `config/server.cr` you should see a line that starts with `settings.secret_key_base =` (line 17). Replace `DEV_SECRET_KEY_BASE` in the project with the value you find there. (No `sed` one-liner here, too many potential regex chars in the key_base.)

6. Run the project to make sure it works

```
script/up
```

# Seed Database, Test Hasura, Lucky Healthcheck

1. Add this to the `call` method of `tasks/create_required_seeds`

```crystal
%w{admin buzz}.each do |name|
  email = name + "@foo_bar.business"
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

3. Add `user` role in Hasura dashboard (http://localhost:9695/) with permission to select their own email.

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

# returns [{"email" => "user@foo_bar.business"}]
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

```
rm spec/setup/setup_database.cr
```

6. Run `script/test` to prove tests work as expected.

7. Add the `version` route for healthchecks

```
up ssh
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

```
up ssh
# in container
lucky db.migrate && lucky db.create_required_seeds
exit
# back home
curl localhost:5000/version
```

# Production Instructions

1. No travis in this Gitlab project

```
rm .travis.yml
```

2. Commit this all and push without deploy to trigger a build stage

```
git add .
git commit -m 'first commit no-deploy'
git remote add origin <url>
git push -u origin master
```

3. On the production server clone the repo and run docker swarm to pull the image you built...

```
??? script/deploy ???
```