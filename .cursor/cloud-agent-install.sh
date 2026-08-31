#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "== Installing system packages =="
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential git libpq-dev libyaml-dev pkg-config \
  libvips42 libvips-dev postgresql postgresql-contrib \
  curl nodejs npm

echo "== Installing Ruby 3.3 via rbenv =="
if [[ ! -d "${HOME}/.rbenv" ]]; then
  git clone --depth 1 https://github.com/rbenv/rbenv.git "${HOME}/.rbenv"
  git clone --depth 1 https://github.com/rbenv/ruby-build.git "${HOME}/.rbenv/plugins/ruby-build"
fi

export PATH="${HOME}/.rbenv/bin:${HOME}/.rbenv/shims:${PATH}"
# shellcheck disable=SC1091
eval "$(rbenv init - bash)"
rbenv install -s 3.3.6
rbenv global 3.3.6
gem install bundler --no-document

echo "== Starting PostgreSQL =="
sudo service postgresql start || true
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" 2>/dev/null || true

echo "== Bundling dummy app =="
cd /workspace/test/dummy
bundle config set --local path vendor/bundle
bundle install
bundle exec rails db:prepare db:seed tailwindcss:build

echo "== Install complete =="
