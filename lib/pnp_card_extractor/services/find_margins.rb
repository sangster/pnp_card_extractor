# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # This service calculates the length of the page margins, on the outside of
    # the card images. The given PDF files include cutting-guides, in the
    # margins: thin black lines to align your scissors. This service tries to
    # ignore those lines to find the true margins.
    class FindMargins
      include Logging

      MARGIN_SIDES = %i[left right top bottom].freeze

      # Instead of measuring, the margins are provided by the user.
      class Given < FindMargins
        def initialize(margins, ...)
          super(...)
          @margins = margins
        end

        def find_margin_side(side, _)
          @margins.fetch(side)
        end
      end

      # Instead of measuring every margin of every page, this subclass assumes
      # all the margins are the same and only measures one.
      class FindOnce < FindMargins
        def find_margin_side(...)
          @find_margin_side ||= super
        end
      end

      attr_reader :logger, :min_ratio

      def initialize(min_ratio: 0.25, logger: nil)
        @min_ratio = min_ratio
        @logger = logger
      end

      # @param img [Image]
      def call(img)
        debug { 'Finding margins...' }
        MARGIN_SIDES
          .to_h { [_1, find_margin_side(_1, img)] }
          .tap do |margins|
            debug do
              "Found margins: #{margins.map { [_1, _2].join('=') }.join(', ')}"
            end
          end
      end

      protected

      def find_margin_side(side, img)
        find_margin(img.width, img.height, img.pixel_data, side:)
      end

      private

      def find_margin(w, h, data, side: :left)
        min_count = (w * min_ratio).to_i

        case side
        when :left
          limit_i = h

          start_j = 0
          delta_j = 1
          limit_j = w
        when :right
          limit_i = h

          start_j = w - 1
          delta_j = -1
          limit_j = -1
        when :top
          limit_i = w

          start_j = 0
          delta_j = 1
          limit_j = h
        when :bottom
          limit_i = w

          start_j = h - 1
          delta_j = -1
          limit_j = -1
        end

        is_opaque =
          case side
          when :left, :right then proc { |i, j| data[w * i + j][3].zero? }
          when :top, :bottom then proc { |i, j| data[w * j + i][3].zero? }
          end

        (0...limit_i).each do |i|
          opaque = 0
          j = start_j
          while j != limit_j
            opaque += 1 unless is_opaque.call(i, j)
            return i if opaque >= min_count

            j += delta_j
          end
        end
      end
    end
  end
end
