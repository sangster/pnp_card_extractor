# frozen_string_literal: true

require_relative '../lib/pnp_card_extractor'

# This script includes convenience methods for `rake console`.
module Kernel
  def options
    @options ||=
      PnpCardExtractor::Options.new.tap { _1.parse!(%w[--verbose=debug]) }
  end

  def database
    options.database
  end
end
