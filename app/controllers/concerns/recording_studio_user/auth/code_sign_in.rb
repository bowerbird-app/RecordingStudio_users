# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    module CodeSignIn
      extend ActiveSupport::Concern

      SESSION_KEY = :code_sign_in_token

      def code_sign_in
        return exchange_code_sign_in_token if params[:code_sign_in_token].present?

        present_code_sign_in(open_code_sign_in(session[SESSION_KEY]))
      end

      def leave_code_sign_in
        token = session[SESSION_KEY]
        sign_out(:user)
        session[SESSION_KEY] = token if token.present?
        redirect_to request.path, status: :see_other
      end

      private

      def present_code_sign_in(outcome)
        case outcome[:kind]
        when :other_account
          @masked_email = OtpCodeForm.mask(outcome[:user].email)
          render :code_sign_in
        when :continue
          continue_code_sign_in!(outcome)
        else
          reject_code_sign_in!
        end
      end

      def continue_code_sign_in!(outcome)
        return redirect_current_code_sign_in!(outcome) if outcome[:same_session]

        start_code_sign_in!(outcome)
      end

      def exchange_code_sign_in_token
        token = params[:code_sign_in_token].to_s
        if CodeSignInToken.read(token)
          session[SESSION_KEY] = token
          redirect_to request.path, status: :see_other
        else
          reject_code_sign_in!(status: :see_other)
        end
      end

      def open_code_sign_in(token)
        Services::OpenCodeSignIn.call(token: token, current_user: current_user).value
      end

      def start_code_sign_in!(outcome)
        user = outcome[:user]
        store_pending_auth_email!(user.email)
        ReturnTo.remember(session, outcome[:return_to])
        issued = request_sign_in_code!(user.email)
        if issued.respond_to?(:throttled?) && issued.throttled?
          redirect_to otp_session_verify_path, alert: I18n.t("recording_studio_user.auth.wait_for_code")
        else
          redirect_to otp_session_verify_path, notice: generic_login_notice
        end
      end

      def redirect_current_code_sign_in!(outcome)
        session.delete(SESSION_KEY)
        destination = ReturnTo.accept(outcome[:return_to]) || after_auth_path_for(outcome[:user])
        redirect_to destination
      end

      def reject_code_sign_in!(status: :found)
        session.delete(SESSION_KEY)
        redirect_to auth_sign_in_path, status: status,
                                       alert: I18n.t("recording_studio_user.auth.code_sign_in.invalid")
      end
    end
  end
end
