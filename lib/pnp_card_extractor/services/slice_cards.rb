# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # A service that detects the margins around the card images, and then
    # extracts a separate image for each card in the given image.
    class SliceCards
      include Logging

      attr_reader :cols, :options, :rows

      Dimensions = Struct.new(:x, :y, :w, :h) do
        def move(x, y)
          self.class.new(x, y, w, h)
        end

        def to_s
          "#{w}x#{h}+#{x}+#{y}"
        end
      end

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
        rect = make_rect(img, margins)

        (0...rows).flat_map do |j|
          (0...cols).filter_map do |i|
            subdivide_xy(img, i, j, rect.move(margins[:left] + i * w,
                                              margins[:top] + j * h))
          end
        end
      end

      def make_rect(img, margins)
        w = (img.width - margins[:left] - margins[:right]) / cols
        h = (img.height - margins[:top] - margins[:bottom]) / rows
        Dimensions.new(0, 0, w, h)
      end

      def subdivide_xy(img, i, j, dim)
        card = img.create_view(dim.x, dim.y, dim.w, dim.h)
        if card.blank?
          warn { "Card at #{j + 1}x#{i + 1} is blank" }
          nil
        else
          card
        end.tap do
          debug { "Image dimensions of card at #{j + 1}x#{i + 1}: #{dim}" }
        end
      end

      def logger
        options.logger
      end
    end
  end
end
