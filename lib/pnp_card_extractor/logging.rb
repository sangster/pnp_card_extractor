# frozen_string_literal: true

require 'logger'
require 'net/http'
require 'uri'

module PnpCardExtractor
  # A logging concern that converts logging methods into no-ops, if no {Logger}
  # instance is given.
  module Logging
    LEVELS =
      %i[debug info warn error fatal unknown]
        .to_h { [_1, Logger::Severity.const_get(_1.to_s.upcase.to_sym)] }
        .freeze

    # A silent logger that ignores all messages.
    class NilLogger
      LEVELS.each_key do |name|
        define_method(name) { |*_| nil }
      end
    end

    class << self
      def wrap_logger(logger)
        logger || nil_logger
      end

      def nil_logger
        @nil_logger ||= NilLogger.new
      end
    end

    protected

    LEVELS.each_key do |name|
      define_method(name) do |*args, **kwargs, &blk|
        Logging
          .wrap_logger(logger)
          .send(name, self.class, *args, **kwargs, &blk)
      end
    end
  end
end
