# frozen_string_literal: true

require 'json'

module PnpCardExtractor
  module Db
    # A {Hash} wrapper for data returned from the NetrunnerDB API.
    class DslObject
      include Enumerable

      def self.wrap(obj)
        case obj
        when Hash then new(obj)
        when Array then obj.map { new(_1) }
        else
          obj
        end
      end

      def initialize(data)
        @data = data
      end

      def to_h
        @data
      end

      def [](key)
        self.class.wrap(@data[key.to_s])
      end

      def dig(...)
        self.class.wrap(@data.dig(...))
      end

      def each(...)
        @data.each(...)
      end

      def values_at(...)
        @data.values_at(...)
      end

      def method_missing(name, ...)
        return super unless respond_to_missing?(name)

        str = name.to_s
        if str.end_with?('?')
          @data.key?(str[...-1])
        else
          self.class.wrap(@data.fetch(str))
        end
      end

      def respond_to_missing?(name, include_private = false)
        str = name.to_s
        str.end_with?('?') || @data.key?(str) || super
      end
    end
  end
end
