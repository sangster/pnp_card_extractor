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
        is_opaque = make_is_opaque_predicate(side, w, data)
        min_count = (w * min_ratio).to_i

        find_opaque_distance(is_opaque, min_count, iteration_params(side, w, h))
      end

      def make_is_opaque_predicate(side, w, data)
        case side
        when :left, :right then proc { |i, j| data[w * i + j][3].zero? }
        when :top, :bottom then proc { |i, j| data[w * j + i][3].zero? }
        end
      end

      # {#find_margin} can begin its scan at one of the 4 edges of the page, and
      # moves in towards the center. These parameters determine the direction
      # and limits of its iteration over the image data.
      #
      # @return [Array<Integer, Integer, Integer, Integer>] The limit of the
      #   outside loop; the start of the inside loop; -1 if the inside loop is
      #   moving up orleft or +1 if down or right; the limit of the inside loop.
      def iteration_params(side, w, h)
        case side
        when :left then [h, 0, 1, w]
        when :right then [h, w - 1, -1, -1]
        when :top then [w, 0, 1, h]
        when :bottom then [w, h - 1, -1, -1]
        end
      end

      def find_opaque_distance(is_opaque, min_opaque_pixels, params)
        limit_i, start_j, delta_j, limit_j = params

        (0...limit_i).each do |i|
          opaque = 0
          j = start_j
          while j != limit_j
            opaque += 1 unless is_opaque.call(i, j)
            return i if opaque >= min_opaque_pixels

            j += delta_j
          end
        end
      end
    end
  end
end
