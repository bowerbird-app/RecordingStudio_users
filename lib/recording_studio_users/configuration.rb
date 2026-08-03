# frozen_string_literal: true

require_relative "hooks"

module RecordingStudioUsers
  class Configuration
    attr_accessor :current_actor_resolver, :current_root_resolver, :user_scope_resolver,
                  :user_resolver, :user_label_resolver, :layout, :authorizer,
                  :user_class_name, :provisioning_actor_resolver
    attr_reader :hooks

    def initialize
      @current_actor_resolver = method(:default_current_actor)
      @current_root_resolver = method(:default_current_root)
      @user_scope_resolver = method(:default_user_scope)
      @user_resolver = method(:default_user_resolver)
      @user_label_resolver = method(:default_user_label)
      @layout = "application"
      @authorizer = method(:default_authorizer)
      @user_class_name = "User"
      @provisioning_actor_resolver = method(:default_provisioning_actor)
      @hooks = Hooks.new
    end

    def to_h
      {
        layout: layout,
        user_class_name: user_class_name,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    def current_actor_for(controller:) = call(current_actor_resolver, controller: controller)
    def current_root_for(controller:) = call(current_root_resolver, controller: controller)
    def users_for(controller:) = call(user_scope_resolver, controller: controller)
    def user_for(controller:, email:) = call(user_resolver, controller: controller, email: email)
    def user_label_for(user:) = call(user_label_resolver, user: user)
    def provisioning_actor_for(user:, controller: nil) =
      call(provisioning_actor_resolver, user: user, controller: controller)
    def authorized?(controller:, actor:, root_recording:) =
      !!call(authorizer, controller: controller, actor: actor, root_recording: root_recording)

    def user_class
      user_class_name.to_s.constantize
    rescue NameError
      raise ArgumentError, "Configured user_class_name '#{user_class_name}' could not be constantized"
    end

    def layout_for(controller:)
      layout.respond_to?(:call) ? call(layout, controller: controller) : layout
    end

    private

    def default_current_actor(controller:)
      return Current.actor if defined?(Current) && Current.respond_to?(:actor) && Current.actor

      controller.send(:current_user) if controller.respond_to?(:current_user, true)
    end

    def default_current_root(controller:)
      if controller.respond_to?(:current_root_recording, true)
        root_recording = controller.send(:current_root_recording)
        return root_recording if root_recording
      end
      return RecordingStudio::RootSwitchable.current_root_recording if
        defined?(RecordingStudio::RootSwitchable) &&
        RecordingStudio::RootSwitchable.respond_to?(:current_root_recording)
    end

    def default_user_scope(controller:)
      _controller = controller
      defined?(::User) ? ::User.all : []
    end

    def default_user_resolver(controller:, email:)
      scope = users_for(controller: controller)
      normalized_email = email.to_s.strip.downcase
      return if normalized_email.blank? || !scope.respond_to?(:where)

      scope.where("LOWER(email) = ?", normalized_email).first
    end

    def default_user_label(user:)
      user.respond_to?(:name) && user.name.present? ? user.name : (user&.email || "Deleted user")
    end

    def default_authorizer(controller:, actor:, root_recording:)
      _controller = controller
      actor && root_recording &&
        RecordingStudioAccessible.authorized?(actor: actor, recording: root_recording, role: :admin)
    end

    def default_provisioning_actor(user:, controller:)
      _controller = controller
      user
    end

    def call(callable, **arguments)
      return unless callable

      parameters = callable.parameters
      return callable.call(**arguments) if parameters.any? { |type, _| type == :keyrest }

      accepted = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
      callable.call(**arguments.slice(*accepted))
    end
  end
end
