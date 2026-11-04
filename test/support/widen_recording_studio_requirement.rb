# frozen_string_literal: true

# Sibling gemspecs still cap recording_studio below 6.1, or view_component below
# 4.14. Bundler evaluates those gemspecs in this process. Relax the requirement
# before resolution so the pinned sources can activate.
module WidenRecordingStudioRequirement
  RECORDING_STUDIO = "6.1.0"
  ADMIN = "2.6.2"
  VIEW_COMPONENT = "4.19.0"
  SKIP = %w[recording_studio recording_studio_user].freeze

  module SpecificationPatch
    def add_dependency(name, *requirements)
      super(name, *patched_requirements(name.to_s, requirements))
    end

    private

    def patched_requirements(name, requirements)
      return requirements if SKIP.include?(self.name.to_s)
      return requirements if requirements_allow?(requirements, target_version(name))

      case name
      when "recording_studio"
        [">= #{RECORDING_STUDIO}"]
      when "recording_studio_admin"
        [">= 2.0"]
      when "view_component"
        [">= 4.14", "< 5"]
      else
        requirements
      end
    end

    def target_version(name)
      case name
      when "recording_studio" then RECORDING_STUDIO
      when "recording_studio_admin" then ADMIN
      when "view_component" then VIEW_COMPONENT
      end
    end

    def requirements_allow?(requirements, version)
      return true if version.nil?

      Gem::Requirement.new(requirements).satisfied_by?(Gem::Version.new(version))
    end
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationPatch)
