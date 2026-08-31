# frozen_string_literal: true

module RecordingStudioUser
  module Omniauth
    # Default SVG marks for Flatpack List::Item `icon:` on Sign-in methods rows.
    module ProviderLogos
      GOOGLE = <<~SVG.squish.freeze
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="32" height="32" aria-hidden="true">
          <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
          <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.6 8.3 6.3 14.7z"/>
          <path fill="#4CAF50" d="M24 44c5.2 0 10-2 13.6-5.2l-6.3-5.3C29.3 35.3 26.8 36 24 36c-5.3 0-9.7-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/>
          <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.1-4 5.5l.1.1 6.3 5.3C39.2 37.3 44 32 44 24c0-1.2-.1-2.4-.4-3.5z"/>
        </svg>
      SVG

      MICROSOFT = <<~SVG.squish.freeze
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 23 23" width="32" height="32" aria-hidden="true">
          <path fill="#f35325" d="M1 1h10v10H1z"/>
          <path fill="#81bc06" d="M12 1h10v10H12z"/>
          <path fill="#05a6f0" d="M1 12h10v10H1z"/>
          <path fill="#ffba08" d="M12 12h10v10H12z"/>
        </svg>
      SVG

      APPLE = <<~SVG.squish.freeze
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true" fill="currentColor">
          <path d="M16.4 12.6c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.7-1.3-.1-2.5.8-3.1.8-.6 0-1.6-.7-2.7-.7-1.4 0-2.7.8-3.4 2.1-1.5 2.5-.4 6.3 1 8.4.7 1 1.5 2.2 2.6 2.1 1 0 1.4-.7 2.7-.7s1.6.7 2.7.7c1.1 0 1.9-1 2.6-2 .8-1.1 1.1-2.2 1.1-2.3-.1 0-2.1-.8-2.1-3.3zM14.5 5.9c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.6.6-1.1 1.7-.9 2.6 1 .1 1.9-.5 2.5-1.2z"/>
        </svg>
      SVG

      LINKEDIN = <<~SVG.squish.freeze
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true">
          <path fill="#0A66C2" d="M20.5 2h-17A1.5 1.5 0 002 3.5v17A1.5 1.5 0 003.5 22h17a1.5 1.5 0 001.5-1.5v-17A1.5 1.5 0 0020.5 2zM8 19H5v-9h3zM6.5 8.3A1.8 1.8 0 116.5 4.7a1.8 1.8 0 010 3.6zM19 19h-3v-4.7c0-1.1 0-2.6-1.6-2.6s-1.8 1.2-1.8 2.5V19h-3v-9h2.9v1.2h.1c.4-.8 1.4-1.6 2.9-1.6 3.1 0 3.7 2 3.7 4.7V19z"/>
        </svg>
      SVG

      INSTAGRAM = <<~SVG.squish.freeze
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32" aria-hidden="true">
          <linearGradient id="ig" x1="0%" y1="100%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#fdf497"/>
            <stop offset="50%" stop-color="#fd5949"/>
            <stop offset="100%" stop-color="#d6249f"/>
          </linearGradient>
          <path fill="url(#ig)" d="M7 2h10a5 5 0 015 5v10a5 5 0 01-5 5H7a5 5 0 01-5-5V7a5 5 0 015-5zm5 5a5 5 0 100 10 5 5 0 000-10zm6.5-.9a1.1 1.1 0 11-2.2 0 1.1 1.1 0 012.2 0zM12 9a3 3 0 110 6 3 3 0 010-6z"/>
        </svg>
      SVG

      BY_PROVIDER = {
        google_oauth2: GOOGLE,
        microsoft_graph: MICROSOFT,
        apple: APPLE,
        linkedin: LINKEDIN,
        instagram: INSTAGRAM
      }.freeze
    end
  end
end
