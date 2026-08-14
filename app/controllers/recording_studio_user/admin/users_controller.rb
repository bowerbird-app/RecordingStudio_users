# frozen_string_literal: true

module RecordingStudioUser
  module Admin
    class UsersController < ApplicationController
      rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden

      before_action :authenticate_user!
      before_action :authorize_users_admin!

      def index
        redirect_to RecordingStudioAdmin::Engine.routes.url_helpers.screen_path("recording_studio_users")
      end

      def show
        @user = RecordingStudioUser.config.user_class.find(params[:id])
      end

      private

      def render_forbidden
        head :forbidden
      end

      def authorize_users_admin!
        context = authorization_context

        RecordingStudioAdmin::Authorization.authorize!(context)
        RecordingStudioAdmin::BlastRadius.authorize!(
          RecordingStudioUser::Admin::UsersSection,
          context: context,
          label: "Users administration"
        )
      end

      def authorization_context
        RecordingStudioAdmin::Context.new(
          params: params.to_unsafe_h,
          current_actor: current_user,
          controller: self,
          routes: main_app,
          view_context: view_context
        )
      end
    end
  end
end
