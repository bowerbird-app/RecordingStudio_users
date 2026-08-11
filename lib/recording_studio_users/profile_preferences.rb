# frozen_string_literal: true

module RecordingStudioUsers
  module ProfilePreferences
    module_function

    def locale_options
      I18n.available_locales
          .map { |locale| locale.to_s.tr("_", "-") }
          .uniq
          .sort
          .map { |locale| [locale, locale] }
    end

    def time_zone_options(at: Time.current)
      options = TZInfo::Timezone.all_identifiers.filter_map do |identifier|
        time_zone_option(identifier, at:)
      rescue TZInfo::PeriodNotFound
        nil
      end

      options.sort_by { |label, value, offset| [offset, label, value] }
             .map { |label, value, _offset| [label, value] }
    end

    def with_legacy_value(options, value)
      value = value.to_s
      return options if value.blank? || options.any? { |_label, option_value| option_value == value }

      [*options, ["#{value.tr('_', ' ')} (saved value)", value]]
    end

    def time_zone_option(identifier, at:)
      offset = TZInfo::Timezone.get(identifier).period_for_utc(at).utc_total_offset
      ["(UTC#{formatted_offset(offset)}) #{identifier.tr('_', ' ')}", identifier, offset]
    end
    private_class_method :time_zone_option

    def formatted_offset(offset)
      sign = offset.negative? ? "-" : "+"
      hours, remaining_seconds = offset.abs.divmod(3600)
      minutes = remaining_seconds / 60
      format("%<sign>s%<hours>02d:%<minutes>02d", sign:, hours:, minutes:)
    end
    private_class_method :formatted_offset
  end
end
