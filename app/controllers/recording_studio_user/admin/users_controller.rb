# frozen_string_literal: true

module RecordingStudioUser
  module Admin
    class UsersController < ApplicationController
      include RecordingStudioAdmin::AdminActionAuditing

      rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden
      rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_forbidden

      before_action :authenticate_user!
      before_action :authorize_users_admin!
      before_action :set_user, only: %i[show edit update]
      before_action :authorize_users_admin_action!, only: %i[show edit update]

      def index
        redirect_to RecordingStudioAdmin::Engine.routes.url_helpers.screen_path("recording_studio_users")
      end

      def show; end

      def edit; end

      def update
        if perform_recording_studio_admin_action!("recording_studio_users", :edit, @user, audit_action: :update) do
          @user.update(admin_user_params)
        end
          redirect_to admin_user_path(@user), notice: "User updated."
        else
          render :edit, status: :unprocessable_entity
        end
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

      def set_user
        @user = RecordingStudioUser.config.user_class.find(params[:id])
      end

      def authorize_users_admin_action!
        resource_action = action_name == "update" ? :edit : action_name

        RecordingStudioAdmin.authorize_resource!(
          key: "recording_studio_users",
          action: resource_action,
          context: recording_studio_admin_context,
          record: @user,
          audit: true,
          audit_action: action_name
        )
      end

      def admin_user_params
        params.require(:user).permit(:first_name, :last_name, :time_zone)
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

      alias recording_studio_admin_context authorization_context
    end
  end
end
