# frozen_string_literal: true

require "test_helper"

class SearchContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_search_escapes_wildcards_and_bounds_results
    source = File.read(File.join(ROOT, "lib/recording_studio_users/services/search_users.rb"))

    assert_includes source, "sanitize_sql_like"
    assert_includes source, ".limit(effective_limit)"
    assert_includes source, ".clamp(1, 100)"
    assert_includes source, "where.not(id: exclude_ids)"
  end

  def test_invalid_root_identifier_cannot_fall_back_to_site_search
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_users/users_controller.rb"))

    assert_includes source, "unscoped.find(params[:root_recording_id])"
    refute_includes source, "find_by(id: params[:root_recording_id])"
  end

  def test_picker_marks_configured_users_disabled
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_users/users_controller.rb"))

    assert_includes source, "item[:disabled] = true"
    assert_includes source, "params[:disabled]"
  end
end
