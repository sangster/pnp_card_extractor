#
# This script includes convenience methods for `rake console`.
#
require_relative '../lib/pnp_card_extractor'

module Kernel
  def options
    @options ||= PnpCardExtractor::Options.new.tap do
      _1.parse!(%w[--verbose=debug])
    end
  end

  def database
    options.database
  end
end
