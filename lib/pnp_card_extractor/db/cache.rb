# frozen_string_literal: true

require 'json'

module PnpCardExtractor
  module Db
    # The base class for cache services.
    class Cache
      include Logging

      DatabaseError = Class.new(Error)
      NotFoundError = Class.new(DatabaseError)

      attr_reader :logger, :source

      def initialize(source, logger:)
        @source = source
        @logger = logger
      end

      NetrunnerdbApi::INDEX_ROUTES.each do |route|
        define_method(route) do |*args, **kwargs, &blk|
          data = call(route, *args, **kwargs, &blk)
          unpack_cached_data(data, route)
        end
      end

      NetrunnerdbApi::GET_ROUTES.each do |route|
        define_method(route) do |id, *args, **kwargs, &blk|
          data = call(route, id, *args, **kwargs, &blk)
          unpack_cached_data(data, route, id)&.first
        end
      end

      protected

      def unpack_cached_data(data, route, *params)
        json = parse_data(data)
        unless json && json['success']
          raise NotFoundError,
                "Could not get '#{cache_id(route, *params)}' from database."
        end

        DslObject.wrap(json['data'])
      end

      def parse_data(data)
        case data
        when String then JSON.parse(data)
        when Net::HTTPResponse then parse_data(data.body)
        else
          data
        end
      end

      def cache_id(route, *params)
        params.inject(Pathname(route.to_s)) { _1 / _2.to_s }
      end
    end
  end
end
