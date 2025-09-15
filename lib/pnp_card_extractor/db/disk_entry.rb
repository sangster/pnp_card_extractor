# frozen_string_literal: true

require 'time'

module PnpCardExtractor
  module Db
    # An adapter for an on-disk cache entry. The ctime stat is used as the cache
    # entry's creation time and the mtime stat is set to the "last-modified"
    # HTTP header returned by the API.
    class DiskEntry
      include Logging

      CacheError = Class.new(Error)
      LastModifiedMissing = Class.new(CacheError)
      WriteError = Class.new(CacheError)

      attr_reader :logger, :path

      # @return [DiskEntry, nil] A named cache entry, if it exists.
      def self.fetch(cache_root, route, logger:)
        return nil unless cache_root

        path = cache_root / "#{route}.json"
        new(path, logger:) if path.exist?
      end

      def initialize(path, logger:)
        @path = path
        @logger = logger
      end

      # @return [Time] The last-modified timestamp returned by the API.
      def modified_at
        @modified_at ||= path.stat.mtime
      end

      # @return [Time] When the data was last cached.
      def cached_at
        @cached_at ||= path.stat.ctime
      end

      def older_than?(sec)
        cached_at + sec.to_i < Time.now
      end

      def read
        @read ||= path.read
      end

      # Store the given HTTP response into this cache entry.
      def store(res)
        @read = res.body
        @modified_at = last_modified(res)
        touch

        info { "Stored #{@read.size} bytes into #{path} (last-modified: #{@modified_at})" }
        read
      end

      # Recreate the file to update ctime and mtime.
      def touch
        body = read
        server_time = modified_at
        path.dirname.mkpath
        path.unlink if path.exist?
        path.write(body)
        path.utime(Time.now, server_time)
      rescue Errno::EACCES => e
        raise WriteError, e
      end

      private

      def last_modified(res)
        Time.parse(res.fetch('last-modified'))
      rescue ArgumentError
        raise LastModifiedMissing
      end
    end
  end
end
