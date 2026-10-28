# frozen_string_literal: true

require "digest/md5"
require "stringio"

module RecordingStudioUser
  module ProfileImage
    # Issues an Attachable direct-upload blob after upload authorization.
    module Blobs
      module_function

      def issued!(recording, io:, filename:, content_type:, actor:)
        authorize_upload!(recording, actor)
        bytes = io.read
        blob = prepared!(recording, actor, filename, content_type, bytes)
        blob.upload(StringIO.new(bytes), identify: false)
        blob
      end

      def authorize_upload!(recording, actor)
        RecordingStudioAttachable::Authorization.authorize!(
          action: :upload,
          actor: actor,
          recording: recording
        )
      end

      def prepared!(recording, actor, filename, content_type, bytes)
        RecordingStudioAttachable::DirectUpload.prepare!(
          recording: recording, actor: actor, filename: filename, content_type: content_type,
          byte_size: bytes.bytesize, checksum: Digest::MD5.base64digest(bytes)
        )
      end
    end
  end
end
