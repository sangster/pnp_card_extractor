# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
if ENV['DEBUG']
  loader.enable_reloading
  Kernel.define_method(:reload) { loader.reload }
end
loader.setup

module PnpCardExtractor
  Error = Class.new(StandardError)
end
