# frozen_string_literal: true

require Rails.root.join("lib/dummy/locale")

Rails.application.config.middleware.insert_after Warden::Manager, Dummy::LocaleMiddleware
