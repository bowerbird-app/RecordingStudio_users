# frozen_string_literal: true

module RecordingStudioUsers
  class Configuration
    attr_accessor :after_role_switch_redirect,
                  :authentication_redirect,
                  :current_actor_resolver,
                  :invitation_url_resolver,
                  :layout,
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
      @current_actor_resolver = lambda { |controller:|
        controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
      }
      @invitation_url_resolver = lambda do |token:, **|
        RecordingStudioUsers::Engine.routes.url_helpers.accept_invitation_path(token: token)
      end
      @layout = "application"
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
