#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.rbenv/bin:${HOME}/.rbenv/shims:${PATH}"
# shellcheck disable=SC1091
eval "$(rbenv init - bash)"

cd /workspace/test/dummy
exec bundle exec rails "tailwindcss:watch[always]"
