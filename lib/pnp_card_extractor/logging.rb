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

    class FakeLogger
      LEVELS.each_key do |name|
        define_method(name) { |*_| nil }
      end
    end

    class << self
      def wrap_logger(logger)
        logger || fake_logger
      end

      def fake_logger
        @fake_logger ||= FakeLogger.new
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
