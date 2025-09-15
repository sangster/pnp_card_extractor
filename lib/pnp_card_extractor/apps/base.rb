# frozen_string_literal: true

require 'poppler'

module PnpCardExtractor
  module Apps
    # Base class for applications.
    class Base
      include Logging

      attr_reader :options

      def self.call(...)
        new(...).tap(&:call)
      end

      def initialize(options)
        @options = options
      end

      def logger
        options.logger
      end
    end
  end
end
