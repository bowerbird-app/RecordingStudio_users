# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_users/version"
require "recording_studio_users/errors"
require "recording_studio_users/result"
require "recording_studio_users/configuration"
require "recording_studio_users/execution_context"
require "recording_studio_users/provisioning_authorization"
require "recording_studio_users/avatar_authorization"
require "recording_studio_users/avatar"
require "recording_studio_users/user"
require "recording_studio_users/user_information_loader"
require "recording_studio_users/services/provision"
require "recording_studio_users/services/revise_profile"
require "recording_studio_users/services/avatar_mutation"
require "recording_studio_users/services/log_user_event"
require "recording_studio_users/services/search_users"
require "recording_studio_users/engine"

module RecordingStudioUsers
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration.validate!
      ProvisioningAuthorization.install!
      configuration
    end

    def user_class = configuration.user_class

    def provision(user, actor: nil) = Services::Provision.call(user: user, actor: actor)

    def provisioned?(user)
      validate_user_profile!(user)
      true
    rescue TopologyError, ArgumentError, ActiveRecord::RecordNotFound
      false
    end

    def user_root_for(user)
      lookup_user_root(user)
    end

    def user_root_recording_for(user)
      root = lookup_user_root(user)
      unique_recording_for(recordable: root, parent_recording_id: nil, label: "UserRoot")
    end

    def profile_recording_for(user)
      root_recording = user_root_recording_for(user)
      unique_child_recording(
        parent_recording: root_recording,
        recordable_type: "RecordingStudioUsers::Profile",
        label: "Profile"
      )
    end

    def profile_for(user) = profile_recording_for(user).recordable

    def avatar_recording_for(user)
      recordings = active_avatar_recordings(profile_recording_for(user)).to_a
      raise TopologyError, "Profile has more than one active avatar" if recordings.many?

      recordings.first
    end

    def validate_user_profile!(user)
      raise ArgumentError, "User must be persisted" unless persisted_record?(user)

      root = lookup_user_root(user)
      root_recording = user_root_recording_for(user)
      profile_recording = profile_recording_for(user)
      unless profile_recording.root_recording_id == root_recording.id
        raise TopologyError, "Profile recording is outside the private root"
      end

      validate_self_admin_grant!(RecordingStudioAccessible.access_recordings_for(root_recording).to_a, user)
      avatar_recording_for(user)
      root
    end

    def revise_profile(user:, actor:, attributes:, impersonator: nil)
      Services::ReviseProfile.call(user:, actor:, attributes:, impersonator:)
    end

    def upload_avatar(user:, signed_blob_id:, actor:, impersonator: nil)
      Services::AvatarMutation.call(operation: :upload, user:, signed_blob_id:, actor:, impersonator:)
    end

    def replace_avatar(user:, signed_blob_id:, actor:, impersonator: nil)
      Services::AvatarMutation.call(operation: :replace, user:, signed_blob_id:, actor:, impersonator:)
    end

    def remove_avatar(user:, actor:, impersonator: nil)
      Services::AvatarMutation.call(operation: :remove, user:, actor:, impersonator:)
    end

    def log_user_event(user:, action:, actor:, impersonator: nil, metadata: {}, idempotency_key: nil)
      Services::LogUserEvent.call(user:, action:, actor:, impersonator:, metadata:, idempotency_key:)
    end

    def identity_visible?(user, actor: nil, context: nil)
      policy_allowed?(:identity_visibility_policy, user:, actor:, context:)
    end

    def email_visible?(user, actor: nil, context: nil)
      policy_allowed?(:email_visibility_policy, user:, actor:, context:)
    end

    def profile_visible?(user, actor: nil, context: nil)
      policy_allowed?(:profile_visibility_policy, user:, actor:, context:)
    end

    def profile_editable?(user, actor:, context: nil)
      policy_allowed?(:profile_edit_policy, user:, actor:, context:)
    end

    def stored_avatar_visible?(user, actor: nil, context: nil)
      policy_allowed?(:stored_avatar_delivery_policy, user:, actor:, context:)
    end

    def display_name(user, context: nil)
      actor = actor_from_context(context)
      return "User" unless identity_visible?(user, actor:, context:)

      profile_name = information_for(user, context:)&.profile&.display_name if
        profile_visible?(user, actor:, context:)
      user_label = call_configured(configuration.user_label, user:, context:)
      email_label = email_local_part(user) if email_visible?(user, actor:, context:)
      normalize_label(profile_name) || normalize_label(user_label) || normalize_label(email_label) || "User"
    end

    def initials(user, context: nil)
      parts = display_name(user, context:).scan(/\p{L}[\p{L}\p{M}'’-]*/u)
      return "U" if parts.empty?

      selected = parts.length > 1 ? [parts.first, parts.last] : [parts.first]
      selected.filter_map { |part| part.scan(/\X/).first }.join.upcase
    end

    def avatar_for(user, size: :medium, context: nil)
      size = size.to_sym
      variant = configuration.avatar_variant_mapping.fetch(size) do
        raise ArgumentError, "Unknown avatar size: #{size}"
      end
      actor = actor_from_context(context)
      information = information_for(user, context:)
      path = if information&.avatar_recording && stored_avatar_visible?(user, actor:, context:)
               avatar_preview_path(information.avatar_recording, variant)
             end
      external = call_configured(configuration.external_avatar_resolver, user:, size:, context:)
      dimension = configuration.avatar_dimensions.fetch(size)

      Avatar.new(
        image_path: path.presence || external.to_s.presence,
        initials: initials(user, context:),
        alt_text: "#{display_name(user, context:)} avatar",
        width: dimension,
        height: dimension
      )
    end

    def profile_path_for(user, actor: nil, context: nil)
      return unless user == actor
      return unless profile_visible?(user, actor:, context:)

      Engine.routes.url_helpers.profile_path
    end

    def profile_complete?(user)
      information_for(user)&.profile&.display_name.to_s.squish.present?
    rescue TopologyError, ActiveRecord::RecordNotFound
      false
    end

    def preload_user_information(users, include: %i[profile avatar], context: nil)
      UserInformationLoader.new(users, include:, context:).call
    end

    def prepare_admin_rows(context)
      rows = context&.table_result&.rows
      return unless rows

      marker = [context.object_id, %i[profile avatar]].freeze
      prepared = ActiveSupport::IsolatedExecutionState[:recording_studio_users_admin_preloads] ||= {}
      return rows if prepared[marker]

      preload_user_information(rows, context:)
      prepared[marker] = true
      rows
    end

    def search_users(query:, actor:, scope: nil, root_recording: nil, limit: nil, exclude_ids: [], context: nil)
      Services::SearchUsers.call(query:, actor:, scope:, root_recording:, limit:, exclude_ids:, context:)
    end

    def current_actor(controller = nil)
      call_configured(configuration.current_actor, controller:)
    end

    def current_impersonator(controller = nil)
      call_configured(configuration.current_impersonator, controller:)
    end

    def active_avatar_recordings(profile_recording)
      RecordingStudio::Recording.unscoped.where(
        parent_recording_id: profile_recording.id,
        recordable_type: "RecordingStudioAttachable::Attachment",
        trashed_at: nil
      ).reorder(:id)
    end

    def call_configured(callable, **kwargs)
      return callable unless callable.respond_to?(:call)

      parameters = callable.parameters
      return callable.call(**kwargs) if parameters.any? { |type, _| %i[key keyreq keyrest].include?(type) }

      callable.arity.zero? ? callable.call : callable.call(*kwargs.values.first(callable.arity.abs))
    rescue StandardError
      nil
    end

    private

    def lookup_user_root(user)
      raise ArgumentError, "User must be persisted" unless persisted_record?(user)

      roots = UserRoot.where(user_type: user.class.base_class.name, user_id: user.id).limit(2).to_a
      raise ActiveRecord::RecordNotFound, "User profile root not found" if roots.empty?
      raise TopologyError, "User has more than one UserRoot" if roots.many?

      roots.first
    end

    def unique_recording_for(recordable:, parent_recording_id:, label:)
      recordings = RecordingStudio::Recording.unscoped.where(
        recordable_type: recordable.class.base_class.name,
        recordable_id: recordable.id,
        parent_recording_id:
      ).limit(2).to_a
      raise ActiveRecord::RecordNotFound, "#{label} recording not found" if recordings.empty?
      raise TopologyError, "User has more than one #{label} recording" if recordings.many?

      recordings.first
    end

    def unique_child_recording(parent_recording:, recordable_type:, label:)
      recordings = RecordingStudio::Recording.unscoped.where(
        root_recording_id: parent_recording.id,
        parent_recording_id: parent_recording.id,
        recordable_type:,
        trashed_at: nil
      ).reorder(:id).limit(2).to_a
      raise ActiveRecord::RecordNotFound, "#{label} recording not found" if recordings.empty?
      raise TopologyError, "User has more than one active #{label} recording" if recordings.many?

      recordings.first
    end

    def validate_self_admin_grant!(grants, user)
      raise TopologyError, "Private root must have exactly one active direct grant" unless grants.one?

      access = grants.first.recordable
      return if access&.actor == user && access.role.to_s == "admin"

      raise TopologyError, "Private root grant must belong to its User with admin role"
    end

    def persisted_record?(record) = record.respond_to?(:persisted?) && record.persisted?

    def policy_allowed?(name, **)
      !!call_configured(configuration.public_send(name), **)
    end

    def actor_from_context(context)
      return context.actor if context.respond_to?(:actor)
      return context[:actor] if context.respond_to?(:[]) && context[:actor]

      current_actor
    end

    def information_for(user, context: nil)
      UserInformationLoader.cached(user, context:) || begin
        preload_user_information([user], context:)
        UserInformationLoader.cached(user, context:)
      end
    end

    def normalize_label(value) = value.to_s.squish.presence

    def email_local_part(user)
      return unless user.respond_to?(:email)

      user.email.to_s.split("@", 2).first.to_s.tr("._-", " ")
    end

    def avatar_preview_path(recording, variant)
      RecordingStudioAttachable::Engine.routes.url_helpers.attachment_preview_file_path(
        recording.id,
        variant_name: variant
      )
    end
  end
end
