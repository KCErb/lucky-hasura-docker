# Changelog

## Changes in v0.3.0

* Lucky now uses `DB_URL` instead of `DATABASE_URL`.
* Bumped `lucky-crystal` image and Hasura versions.
* Add `shard.lock` to repo after images are built now.

## Changes in v0.2.0

* Removed docker-sync dependency.
* Reduced image size by 73% by switching to Crystal+Lucky-Alpine image.
* Reduced build time by 30% by reusing built images in CI.
* Reorganized guides to get up and running first with improvements to follow.
* Increased security by using non-root user in Docker and Production environments.
* Increased security by auto-generating secrets in `bootstrap` script and moving them out of shell startup files.

## v0.1.0

Initial release
