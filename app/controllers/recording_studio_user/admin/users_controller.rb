# frozen_string_literal: true

require "pagy"

module RecordingStudioUser
  module Admin
    class UsersController < ApplicationController
      include Pagy::Backend

      helper Pagy::Frontend

      before_action :authenticate_user!
      before_action :authorize_users_admin!

      def index
        users = RecordingStudioUser.config.user_class.order(created_at: :desc)
        @total_users = users.count
        @user_creation_series = RecordingStudioUser::Admin.user_creation_series(chart_users(users))
        @pagy, @users = pagy(users, limit: 50)
      end

      private

      def chart_users(users)
        users.where(created_at: 90.days.ago..Time.current)
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
