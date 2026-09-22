# frozen_string_literal: true

module Dummy
  # Dummy Agree screen only. Released TnC 0.6.2 ships py-5 around the
  # checkbox; that gap is too tall once the "Terms updated" alert is gone.
  module TighterTermsAgree
    def recording_studio_terms_agree_fields(terms_list, _inside_form, link_terms: false)
      checkbox_id = "agreed_#{SecureRandom.hex(4)}"

      content_tag(:div, class: "pt-2") do
        recording_studio_terms_agree_labeled_box(terms_list, checkbox_id, link_terms)
      end
    end
  end
end
