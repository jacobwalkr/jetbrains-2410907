# Minimum Reproducible Example for Jetbrains ticket #2410907

https://intellij-support.jetbrains.com/hc/en-us/requests/2410907?page=1

## Assumes
- Rubymine 2019.3.2 preview
- Docker 19.03.4 and Docker Compose 1.24.1 (Docker Desktop (Mac) 2.1.0.4)
- macOS Mojave

## Setup
- `docker-compose build`
- `docker-compose up [-d]`
- `docker-compose exec app bundle exec rake db:setup`
- Open RubyMine
- Add remote Ruby SDK pointing to Docker Compose `app` service
