# frozen_string_literal: true

require "test_helper"

class TailwindGemSourcesTest < ActiveSupport::TestCase
  test "resolves FlatPack and engine directories for Tailwind" do
    directories = Dummy::TailwindGemSources.source_directories

    assert(directories.any? { |path| path.include?("flatpack") || path.include?("flat_pack") })
    assert(directories.any? { |path| path.include?("app/views") })
  end

  test "emits @source lines for each resolved directory" do
    css = Dummy::TailwindGemSources.css

    assert_includes css, "@source"
    assert_match(/flatpack|flat_pack/, css)
  end
end
