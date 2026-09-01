Rails.application.routes.draw do
  devise_for :users,
             skip: %i[sessions registrations passwords],
             controllers: { omniauth_callbacks: "recording_studio_user/omniauth_callbacks" }

  scope module: "recording_studio_user/auth", path: "users" do
    get "sign_up", to: "registrations#new", as: :new_user_registration
    get "sign_up/password", to: "registrations#password"
    post "sign_up", to: "registrations#create_password", as: :user_registration
    post "sign_up/password", to: "registrations#create_password"
    get "sign_up/otp", to: "registrations#otp"
    post "sign_up/otp", to: "registrations#create_otp"
    get "sign_up/verify", to: "registrations#verify", as: :verify_user_registration
    post "sign_up/verify", to: "registrations#submit_verify"
    post "sign_up/resend", to: "registrations#resend", as: :resend_user_registration

    get "sign_in", to: "sessions#new", as: :new_user_session
    get "sign_in/password", to: "sessions#password"
    post "sign_in", to: "sessions#create_password", as: :user_session
    post "sign_in/password", to: "sessions#create_password"
    get "sign_in/otp", to: "sessions#otp"
    post "sign_in/otp", to: "sessions#create_otp"
    get "sign_in/verify", to: "sessions#verify", as: :verify_user_session
    post "sign_in/verify", to: "sessions#submit_verify"
    post "sign_in/resend", to: "sessions#resend", as: :resend_user_session
  end

  devise_scope :user do
    delete "users/sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
    get "users/password/new", to: "recording_studio_user/auth/passwords#new", as: :new_user_password
    post "users/password", to: "recording_studio_user/auth/passwords#create", as: :user_password
  end

  # RecordingStudio engine is data/API-focused and has no browser root route.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  recording_studio_admin_for :admin, at: "/admin", root_section: :root
  mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users

  get "up" => "rails/health#show", as: :rails_health_check

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config
  get "docs/recordable_types", to: "docs#recordable_types", as: :docs_recordable_types
  get "docs/recordings_tree", to: "docs#recordings_tree", as: :docs_recordings_tree
  get "docs/gem_views", to: "docs#gem_views", as: :docs_gem_views
  get "docs/methods", to: "docs#methods", as: :docs_methods

  root "home#index"
end
