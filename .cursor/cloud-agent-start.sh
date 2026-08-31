#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.rbenv/bin:${HOME}/.rbenv/shims:${PATH}"
# shellcheck disable=SC1091
eval "$(rbenv init - bash)"

sudo service postgresql start 2>/dev/null || true

cd /workspace/test/dummy
export OMNIAUTH_TEST_MODE=1
export PORT=3000
export RAILS_ENV=development

echo "Starting Rails on 0.0.0.0:3000 (OMNIAUTH_TEST_MODE=1)"
exec bundle exec rails server -b 0.0.0.0 -p 3000
