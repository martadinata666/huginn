### Sensible build
FROM ruby:3.2-slim-bullseye as tukang
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /app
COPY ["Gemfile", "Gemfile.lock", "/app/"]
COPY lib/gemfile_helper.rb /app/lib/
COPY vendor/gems/ /app/vendor/gems/
COPY ./ /app/
#    gem update --system 3.3.20 --no-document && \
RUN apt update && \
    apt install -y --no-install-recommends build-essential checkinstall git-core \
    zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses-dev libffi-dev libxml2-dev libxslt-dev curl libcurl4-openssl-dev libicu-dev \
    graphviz libmariadb-dev libpq-dev libsqlite3-dev locales tzdata shared-mime-info iputils-ping jq && \
    gem update bundler --conservative --no-document && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle config set --local path vendor/bundle && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle config set --local without 'test development' && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle install -j 4 && \
    LC_ALL=en_US.UTF-8 RAILS_ENV=production APP_SECRET_TOKEN=secret DATABASE_ADAPTER=mysql2 ON_HEROKU=true bundle exec rake assets:clean assets:precompile && \
    git init 

FROM ruby:3.2-slim-bullseye
ARG USER=debian
RUN apt update && \
    apt install -y --no-install-recommends libmariadb3 tini supervisor git-core locales shared-mime-info iputils-ping jq libffi7 libxml2 libncurses6 libreadline8 libssl1.1 libgdbm-compat4 libyaml-0-2 zlib1g && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -u 1000 -U -d /home/$USER -s /bin/bash -p $(echo $USER | openssl passwd -1 -stdin) $USER -m -d /home/$USER

### Install nginx
#  gem install bundler:2.4.7 && \
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
COPY --chown=$USER:$USER supervisor /home/$USER/supervisor
COPY --from=tukang --chown=$USER:$USER /app /app
EXPOSE 3000
USER $USER
WORKDIR /app
COPY ["docker/scripts/setup_env", "docker/single-process/scripts/init", "/scripts/"]
#CMD ["/scripts/init"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["supervisord","-c","/home/debian/supervisor/supervisord.conf"]
