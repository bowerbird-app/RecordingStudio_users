# frozen_string_literal: true

source "https://rubygems.org"

gem "recording_studio", github: "bowerbird-app/RecordingStudio",
                        ref: "7667687155bf05ab41b66dfccae330dc3834c39c"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible",
                                   ref: "7fb3e8ed73a3f5254cf686dc7111f47236c75711"
gem "flat_pack", github: "bowerbird-app/flatpack",
                 ref: "063e835c21f92166acf832f0162636f392fb8dfa"

gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "devise"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
