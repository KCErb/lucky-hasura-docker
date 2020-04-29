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

Now you are ready to `script/up`, `script/down`, and `script/test`. Though in testing I recommend

```
rm spec/setup/setup_database.cr
```

# Seed Database and Test Hasura

1. Add this to the `call` method of `tasks/create_required_seeds`

```crystal
%w{admin buzz}.each do |name|
  email = name + "@foo_bar.business"
  user = UserQuery.new.email(email).first?
  UserBox.create &.email(email) unless user
end
```

2. Replace `payload` variable in `src/models/user_token.cr` with

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

3. Add `user` role in Hasura dashboard with permission to select their own email.

3. Add `spec/requests/graphql/users/query_spec.cr` file with contents

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

# Production Instructions

1. No travis in this Gitlab project

```
rm .travis.yml
```

2. Commit this all and push without deploy to trigger a build stage

```
git commit -am 'first commit no-deploy'
git push
```

3. On the production server

```
??? script/deploy ???
```