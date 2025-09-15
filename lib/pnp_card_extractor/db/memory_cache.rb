# frozen_string_literal: true

require 'json'

module PnpCardExtractor
  module Db
    # A simple cache that stores results in-memory.
    class MemoryCache < Cache
      attr_reader :hash_cache

      def initialize(...)
        super
        @hash_cache = {}
      end

      def call(route, *params)
        id = cache_id(route, *params)
        debug { "Cache #{hash_cache[id] ? 'hit' : 'miss'}: #{id}" }

        if !hash_cache[id]
          hash_cache[id] = parse_data(source&.call(route, *params))
        end
        hash_cache[id]
      end
    end
  end
end
