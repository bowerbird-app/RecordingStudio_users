# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "yaml"

class EngineConfigurationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioUsers.configuration
    RecordingStudioUsers.instance_variable_set(:@configuration, RecordingStudioUsers::Configuration.new)
  end

  def teardown
    RecordingStudioUsers.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_does_not_load_missing_optional_yaml_configuration
    Dir.mktmpdir do |directory|
      app = application_for(directory) { |_name| flunk "config_for should not be called without YAML" }

      run_configuration_initializer(app)

      assert_equal 20, RecordingStudioUsers.configuration.picker_limit
    end
  end

  def test_loads_existing_yaml_configuration
    Dir.mktmpdir do |directory|
      configuration_file = File.join(directory, "recording_studio_users.yml")
      File.write(configuration_file, "test:\n  picker_limit: 12\n")
      app = application_for(directory) do |name|
        raise "unexpected configuration name" unless name == :recording_studio_users

        YAML.load_file(configuration_file).fetch("test")
      end

      run_configuration_initializer(app)

      assert_equal 12, RecordingStudioUsers.configuration.picker_limit
    end
  end

  private

  def application_for(directory, &config_for)
    config = Struct.new(:paths, :x).new({ "config" => [directory] }, Object.new)
    Struct.new(:config) do
      define_method(:config_for, &config_for)
    end.new(config)
  end

  def run_configuration_initializer(app)
    initializer = RecordingStudioUsers::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_users.load_config"
    end

    RecordingStudioUsers::ProvisioningAuthorization.stub(:install!, true) do
      initializer.block.call(app)
    end
  end
end
