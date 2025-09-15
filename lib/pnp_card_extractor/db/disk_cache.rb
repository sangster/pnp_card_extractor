# frozen_string_literal: true

module PnpCardExtractor
  module Db
    # A cache that store API responses on the disk.
    class DiskCache < Cache
      CACHE_FRESHNESS_SEC = 24 * 60 * 60

      attr_reader :cache_root

      # @param source [NetrunnerdbApi, nil]
      def initialize(cache_root, ...)
        super(...)
        @cache_root = Pathname(cache_root) if cache_root
      end

      def call(route, *params)
        id = cache_id(route, *params)
        cache = DiskEntry.fetch(cache_root, id, logger:)
        debug { "Cache #{cache ? 'hit' : 'miss'}: #{id}" }

        source ? refresh_cache_entry(route, params, id, cache) : cache&.read
      end

      private

      def refresh_cache_entry(route, args, id, cache)
        unless !cache || cache.older_than?(CACHE_FRESHNESS_SEC)
          debug { "Cache fresh: #{id}" }
          return cache.read
        end

        res = source.call(route.to_sym, *args,
                          modified_since: cache&.modified_at)
        if res.is_a?(Net::HTTPNotModified)
          info { "Cache up-to-date: #{id}" }
          cache.touch
          cache.read
        else
          cache_response(id, res)
        end
      end

      def cache_response(id, res)
        return res.body unless cache_root && res['last-modified']

        DiskEntry.new(cache_root / "#{id}.json", logger:).store(res)
      rescue DiskEntry::CacheError => e
        error { "Couldn't store response '#{id}': #{e}" }
        res.body
      end
    end
  end
end
