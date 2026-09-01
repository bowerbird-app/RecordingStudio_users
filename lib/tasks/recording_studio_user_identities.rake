# frozen_string_literal: true

namespace :recording_studio_user do
  desc "Delete provider identities for providers that are no longer configured"
  task prune_unconfigured_identities: :environment do
    configured = RecordingStudioUser.config.omniauth_provider_names.map(&:to_s)
    stale = RecordingStudioUser::Identity.where.not(provider: configured)
    grouped = stale.group(:provider).count

    if grouped.empty?
      puts "No identities found for unconfigured providers."
      next
    end

    grouped.sort.each { |provider, count| puts "#{provider}: #{count}" }
    deleted = stale.delete_all
    puts "Deleted #{deleted} identities for unconfigured providers."
  end
end
