# frozen_string_literal: true

module ProfileImageTestHelper
  def profile_photo_fixture_path
    Rails.root.join("test/fixtures/files/profile.png")
  end

  def attach_profile_photo!(user, filename: "profile.png")
    File.open(profile_photo_fixture_path, "rb") do |io|
      RecordingStudioUser.attach_profile_image!(
        user,
        io: io,
        filename: filename,
        content_type: "image/png",
        actor: user,
        name: "Profile"
      )
    end
  end
end
