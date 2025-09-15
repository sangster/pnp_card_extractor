# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # A service that detects the margins around the card images, and then
    # extracts a separate image for each card in the given image.
    class SliceCards
      include Logging

      attr_reader :cols, :options, :rows

      def initialize(options, rows = 3, cols = 3)
        @options = options
        @rows = rows
        @cols = cols
      end

      def call(img)
        debug { 'Slicing...' }
        subdivide(img, options.find_margins.call(img)).tap do |cards|
          debug { "Sliced #{cards.size} image(s)." }
        end
      end

      private

      def subdivide(img, margins)
        w = (img.width - margins[:left] - margins[:right]) / cols
        h = (img.height - margins[:top] - margins[:bottom]) / rows

        (0...rows).flat_map do |j|
          (0...cols).filter_map do |i|
            x = margins[:left] + i * w
            y = margins[:top] + j * h
            subdivide_xy(img, i, j, x, y, w, h)
          end
        end
      end

      def subdivide_xy(img, i, j, x, y, w, h)
        card = img.create_view(x, y, w, h)
        if card.blank?
          warn { "Card at #{j+1}x#{i+1} is blank" }
          nil
        else
          card
        end.tap do
          debug do
            "Image dimensions of card at #{j+1}x#{i+1}: #{w}x#{h}+#{x}+#{y}"
          end
        end
      end

      def logger
        options.logger
      end
    end
  end
end
