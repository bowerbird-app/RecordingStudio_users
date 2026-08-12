# frozen_string_literal: true

require "test_helper"

class RenameVerificationTest < Minitest::Test
  def test_public_engine_files_use_recording_studio_user_namespace
    assert File.exist?(File.expand_path("../lib/recording_studio_user.rb", __dir__))
    assert File.exist?(File.expand_path("../recording_studio_user.gemspec", __dir__))
    refute File.exist?(File.expand_path("../gem_template.gemspec", __dir__))
  end
end
