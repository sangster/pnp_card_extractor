# frozen_string_literal: true

require 'net/http'
require 'uri'

module PnpCardExtractor
  module Db
    # https://netrunnerdb.com/api/doc
    class NetrunnerdbApi
      include Logging

      ApiError = Class.new(Error)
      NotFoundError = Class.new(ApiError)

      DEFAULT_HOST = 'https://netrunnerdb.com/api/2.0/public/'
      INDEX_ROUTES = %i[cards cycles factions packs sides types].freeze
      GET_ROUTES = %i[card cycle faction pack side type].freeze

      attr_reader :host, :logger

      def initialize(host, logger: nil)
        @host = URI(host)
        @logger = logger
      end

      INDEX_ROUTES.each do |route|
        define_method(route) { |**kwargs| http_get(uri(route), **kwargs) }
      end

      GET_ROUTES.each do |route|
        define_method(route) { |id, **kwargs| http_get(uri(route, id), **kwargs) }
      end

      def call(route, ...)
        public_send(route, ...)
      end

      private

      def uri(*parts)
        URI.join(host, *parts.map(&:to_s).join('/'))
      end

      def http_get(uri, modified_since: nil)
        info { "GET #{uri}#{modified_since ? " (modified_since: #{modified_since})" : ''}" }

        req = Net::HTTP::Get.new(uri)
        req['If-Modified-Since'] = rfc2822(modified_since) if modified_since

        res = start_http(uri) { _1.request(req) }
        debug { " -> #{res}" }

        case res
        when Net::HTTPNotFound
          raise NotFoundError, uri
        else
          res
        end
      end

      def start_http(uri, &blk)
        use_ssl = uri.scheme == 'https'
        Net::HTTP.start(uri.hostname, uri.port, use_ssl:, &blk)
      end

      def rfc2822(time)
        if time.respond_to?(:strftime)
          time.strftime('%a, %-d %b %Y %T %z')
        else
          time.to_s
        end
      end
    end
  end
end
