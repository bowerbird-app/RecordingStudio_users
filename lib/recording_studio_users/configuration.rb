# frozen_string_literal: true

require "uri"

module RecordingStudioUsers
  class Configuration
    attr_accessor :after_role_switch_redirect,
                  :authentication_redirect,
                  :authentication_scope,
                  :current_actor_resolver,
                  :invitation_url_resolver,
                  :layout,
                  :mailer_sender,
                  :root_creator,
                  :root_scope_key,
                  :user_email_resolver,
                  :user_finder

    def initialize
      @after_role_switch_redirect = lambda { |controller:|
        controller.respond_to?(:main_app) ? controller.main_app.root_path : "/"
      }
      @authentication_redirect = lambda { |controller:|
        controller.respond_to?(:main_app) ? controller.main_app.root_path : "/"
      }
      @authentication_scope = :user
      @current_actor_resolver = lambda { |controller:|
        controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
      }
      @invitation_url_resolver = lambda do |token:, **|
        url_options = Rails.application.config.action_mailer.default_url_options
        mount_url = Rails.application.routes.url_helpers.recording_studio_users_url(**url_options)
        accept_path = RecordingStudioUsers::Engine.routes.url_helpers.accept_invitation_path(token: token)
        mount_uri = URI.parse(mount_url)
        mount_path = mount_uri.path.chomp("/")

        if accept_path.start_with?("#{mount_path}/")
          mount_uri.path = accept_path
          mount_uri.to_s
        else
          "#{mount_url.chomp('/')}#{accept_path}"
        end
      end
      @layout = "application"
      @mailer_sender = "no-reply@example.com"
      @root_creator = nil
      @root_scope_key = "workspaces"
      @user_email_resolver = ->(actor:) { actor.respond_to?(:email) ? actor.email : nil }
      @user_finder = ->(email:) { "User".safe_constantize&.find_by(email: email.to_s.strip.downcase) }
    end

    def current_actor_for(controller:)
      call(current_actor_resolver, controller: controller)
    end

    def find_user(email:)
      call(user_finder, email: email)
    end

    def email_for(actor:)
      call(user_email_resolver, actor: actor).to_s.strip.downcase
    end

    def create_root(name:, actor:)
      raise ConfigurationError, "Configure root_creator before creating a workspace" unless root_creator

      call(root_creator, name: name, actor: actor)
    end

    def invitation_url_for(invitation:, token:)
      call(invitation_url_resolver, invitation: invitation, token: token)
    end

    def authentication_path_for(controller:)
      call(authentication_redirect, controller: controller)
    end

    def after_role_switch_path_for(controller:)
      call(after_role_switch_redirect, controller: controller)
    end

    private

    def call(callable, **arguments)
      parameters = callable.parameters
      accepts_keyrest = parameters.any? { |type, _| type == :keyrest }
      accepted = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
      callable.call(**(accepts_keyrest ? arguments : arguments.slice(*accepted)))
    end
  end

  class ConfigurationError < StandardError; end
end
