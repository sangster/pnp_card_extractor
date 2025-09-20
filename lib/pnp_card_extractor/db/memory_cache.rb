# frozen_string_literal: true

require 'json'

module PnpCardExtractor
  module Db
    # A simple cache that stores results in-memory.
    class MemoryCache < Cache
      attr_reader :data

      def initialize(...)
        super
        @data = {}
      end

      def call(route, *params)
        id = cache_id(route, *params)
        debug { "Cache #{data[id] ? 'hit' : 'miss'}: #{id}" }

        data[id] ||= parse_data(source&.call(route, *params))
      end
    end
  end
end
