### Sensible build
FROM --platform=linux/amd64 ruby:3.2-slim-bullseye as assetsgenerator
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /app
COPY ["Gemfile", "Gemfile.lock", "/app/"]
COPY lib/gemfile_helper.rb /app/lib/
COPY vendor/gems/ /app/vendor/gems/
COPY .env.example .env
COPY ./ /app/
RUN apt update && \
    apt install -y --no-install-recommends build-essential checkinstall git-core \
    zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses-dev libffi-dev libxml2-dev libxslt-dev curl libcurl4-openssl-dev libicu-dev libpq-dev libsqlite3-dev \
    graphviz libmariadb-dev libpq-dev libsqlite3-dev locales tzdata shared-mime-info iputils-ping jq && \
    git init && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local path vendor/bundle && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local without 'test development' && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local deployment 'true'&& \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local frozen 'true' && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle install --jobs=$(nproc) && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle exec rake assets:clean assets:precompile

### Sensible build
FROM ruby:3.2-slim-bullseye as geminstall
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /app
COPY ["Gemfile", "Gemfile.lock", "/app/"]
COPY lib/gemfile_helper.rb /app/lib/
COPY vendor/gems/ /app/vendor/gems/
COPY ./ /app/
RUN apt update && \
    apt install -y --no-install-recommends build-essential checkinstall git-core \
                                           zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses-dev libffi-dev libxml2-dev libxslt-dev curl libcurl4-openssl-dev \
                                           libicu-dev graphviz libmariadb-dev libpq-dev libsqlite3-dev locales tzdata shared-mime-info iputils-ping jq && \
    git init && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local path vendor/bundle && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local without 'test development' && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local deployment 'true'&& \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle config set --local frozen 'true' && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production bundle install --jobs=$(nproc)


FROM ruby:3.2-slim-bullseye
ENV LC_ALL=en_US.UTF-8 \
    RAILS_ENV=production \
    USE_GRAPHVIZ_DOT=dot \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    IP="0.0.0.0" PORT=3000 \
    DATABASE_URL=sqlite3:/data/huginn.db \
    APP_SECRET_TOKEN=changeme 
ARG USER=debian
RUN apt update && \
    apt install -y --no-install-recommends libmariadb3 tini supervisor git-core locales shared-mime-info iputils-ping jq libffi7 libxml2 libncurses6 \
                                           libreadline8 libssl1.1 libgdbm-compat4 libyaml-0-2 zlib1g libpq5 libsqlite3-0 && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -u 1000 -U -d /home/$USER -s /bin/bash -p $(echo $USER | openssl passwd -1 -stdin) $USER -m -d /home/$USER

### Install nginx
COPY nginx/99nginx /etc/apt/preferences.d/99nginx
RUN apt update && \
    apt install -y --no-install-recommends curl gnupg2 ca-certificates lsb-release debian-archive-keyring && \
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list && \
    apt update && \
    apt install -y nginx && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/www/html && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /run/nginx/ && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    touch /run/nginx/nginx.pid && \
    chown -R $USER:$USER /var/www/html /run/nginx/nginx.pid /var/cache/nginx/ /var/log/nginx/
COPY --chown=$USER:$USER nginx/huginn-default.conf /etc/nginx/conf.d/default.conf
COPY --chown=$USER:$USER nginx/nginx.conf /etc/nginx/nginx.conf
COPY --chown=$USER:$USER supervisor /supervisor
COPY --from=geminstall --chown=$USER:$USER /app /app
COPY --from=assetsgenerator --chown=$USER:$USER /app/public/assets /app/public/assets
EXPOSE 3000
USER $USER
WORKDIR /app
COPY ["docker/scripts/setup_env", "docker/single-process/scripts/init", "/scripts/"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["supervisord","-c","/supervisor/supervisord.conf"]
