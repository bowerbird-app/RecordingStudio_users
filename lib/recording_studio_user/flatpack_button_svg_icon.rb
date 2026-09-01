# frozen_string_literal: true

# Flatpack Button `icon:` only accepts Heroicon names. List::Item already accepts
# inline SVG strings. Continue-with provider logos need the same SVG branch on
# Button until Flatpack teaches Button#render_icon to mirror List::Item.
module RecordingStudioUser
  module FlatpackButtonSvgIcon
    def render_icon
      return unless @icon
      return render_svg_icon if svg_icon?

      render FlatPack::Shared::IconComponent.new(name: @icon, size: @size)
    end

    private

    def svg_icon?
      @icon.is_a?(String) && @icon.start_with?("<svg")
    end

    def render_svg_icon
      content_tag(
        :span,
        @icon.html_safe,
        class: "inline-flex h-5 w-5 shrink-0 items-center justify-center [&_svg]:h-full [&_svg]:w-full",
        "aria-hidden": true
      )
    end
  end
end
