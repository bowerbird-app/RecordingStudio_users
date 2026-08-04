# frozen_string_literal: true

namespace :recording_studio_users do
  desc "Provision private Profile roots for existing Users"
  task backfill_profiles: :environment do
    batch_size = Integer(ENV.fetch("BATCH_SIZE", "100"))
    counts = Hash.new(0)

    RecordingStudioUsers.user_class.find_each(batch_size:) do |user|
      if RecordingStudioUsers.provisioned?(user)
        counts[:skipped] += 1
        puts "SKIP #{user.class.name}##{user.id}: already provisioned"
        next
      end

      result = RecordingStudioUsers.provision(user)
      if result.success?
        counts[:success] += 1
        puts "OK #{user.class.name}##{user.id}"
      else
        counts[:failure] += 1
        warn "FAIL #{user.class.name}##{user.id}: #{result.error}"
      end
    end

    puts "RecordingStudioUsers backfill: #{counts[:success]} succeeded, " \
         "#{counts[:skipped]} skipped, #{counts[:failure]} failed"
    abort "RecordingStudioUsers backfill completed with failures" if counts[:failure].positive?
  end
end
