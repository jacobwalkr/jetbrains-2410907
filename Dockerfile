FROM ruby:2.5.3
LABEL maintainer="Jacob Walker <jacob.walker@sheffield.ac.uk>"

# apt packages
RUN apt-get update && \
    apt-get install -y mariadb-client locales xvfb unzip ldap-utils

# ensure that we're using a UTF-8 locale
RUN sed -i '/en_GB\.UTF-8.*/s/^# *//' /etc/locale.gen && \
    locale-gen

ENV LANG=en_GB.UTF-8

# /app is intended to be a volume to the code in the context dir
RUN mkdir /app && ln -s /app /opt/project
WORKDIR /app

# install dependency managers - bundler
# TODO: remove when we upgrade to/past 2.6.x again
RUN gem install bundler -v '~> 2.1'

# need a newer version of yarn than what's in the repos, which requires updating node too
RUN curl -sL https://deb.nodesource.com/setup_11.x | bash - && \
    apt-get install -y nodejs && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -y yarn

# Install Chrome
# adapted from https://christopher.su/2015/selenium-chromedriver-ubuntu/
# using this because I want Chrome specifically (not Chromium, for consistency with dev)
# starts by creating an empty repository to stop auto-updates (hopefully)
RUN touch /etc/default/google-chrome && \
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
  (dpkg -i google-chrome-stable_current_amd64.deb || :) && \
  apt-get install -fy

# Tell our config we want to use the headless gem and xvfb to run tests in Chrome
ENV RAILS_TEST_HEADLESS=true

# install Ruby and JS dependencies
COPY Gemfile Gemfile.lock package.json yarn.lock ./
RUN bundle install

# really just cache building, because it's nuked as soon as /app is set as a directory
RUN yarn install --frozen-lockfile --non-interactive

# anything in the scripts dir is placed at the root, dirs preserved
ADD scripts /
RUN chmod +x /entrypoint.sh

EXPOSE 3000
VOLUME /app

# unless overridden, any arguments to `run app` will be arguments to this
ENTRYPOINT ["/entrypoint.sh"]

# using `run app` with no arguments or `up` will pass this by default
CMD ["dev"]
