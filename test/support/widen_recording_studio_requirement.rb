# frozen_string_literal: true

# Sibling gemspecs still cap recording_studio below 6.1, or view_component below
# 4.14. Bundler evaluates those gemspecs in this process. Relax the requirement
# before resolution so the pinned sources can activate.
module WidenRecordingStudioRequirement
  RECORDING_STUDIO = "6.1.0"
  ADMIN = "2.6.2"
  VIEW_COMPONENT = "4.19.0"
  CACHE = "0.6.2"
  SITE_SETTINGS = "0.5.2"
  SKIP = %w[recording_studio recording_studio_user].freeze
  TARGET_VERSIONS = {
    "recording_studio" => RECORDING_STUDIO,
    "recording_studio_admin" => ADMIN,
    "recording_studio_cache" => CACHE,
    "recording_studio_site_settings" => SITE_SETTINGS,
    "view_component" => VIEW_COMPONENT
  }.freeze
  REPLACED_REQUIREMENTS = {
    "recording_studio" => [">= #{RECORDING_STUDIO}"],
    "recording_studio_admin" => [">= 2.0"],
    "recording_studio_cache" => [">= 0.5", "< 1"],
    "recording_studio_site_settings" => [">= 0.2"],
    "view_component" => [">= 4.14", "< 5"]
  }.freeze

  module SpecificationPatch
    def add_dependency(name, *requirements)
      super(name, *patched_requirements(name.to_s, requirements))
    end

    private

    def patched_requirements(name, requirements)
      return requirements if SKIP.include?(self.name.to_s)
      return requirements if requirements_allow?(requirements, TARGET_VERSIONS[name])

      REPLACED_REQUIREMENTS.fetch(name, requirements)
    end

    def requirements_allow?(requirements, version)
      return true if version.nil?

      Gem::Requirement.new(requirements).satisfied_by?(Gem::Version.new(version))
    end
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationPatch)
