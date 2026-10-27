# frozen_string_literal: true

# Notifications 0.7 and Root Switchable 0.9 still pass keywords FlatPack removed.
module FlatPackPageNavLegacyKeywords
  def initialize(*args, **kwargs)
    href = kwargs.delete(:anchor_href) || kwargs.delete(:anchor_url)
    label = kwargs.delete(:anchor_label) || kwargs.delete(:anchor_tooltip)
    %i[
      anchor_icon anchor_style anchor_size
      back_href back_label back_tooltip back_icon back_style back_size
      show_back right_slot
    ].each { |key| kwargs.delete(key) }
    kwargs.delete_if { |key, _| key.to_s.start_with?("secondary_anchor") }
    super(*args, **kwargs)
    with_close(href: href, tooltip: label) if href.present?
  end
end

Rails.application.config.to_prepare do
  unless FlatPack::PageNav::Component.ancestors.include?(FlatPackPageNavLegacyKeywords)
    FlatPack::PageNav::Component.prepend(FlatPackPageNavLegacyKeywords)
  end
end

module FlatPackCardLegacyStyle
  def initialize(*args, style: nil, **kwargs)
    case style&.to_sym
    when :elevated
      kwargs[:shadow] ||= :md
    when :outlined
      kwargs[:border] ||= :default
    end
    super(*args, **kwargs)
  end
end

Rails.application.config.to_prepare do
  unless FlatPack::Card::Component.ancestors.include?(FlatPackCardLegacyStyle)
    FlatPack::Card::Component.prepend(FlatPackCardLegacyStyle)
  end
end
