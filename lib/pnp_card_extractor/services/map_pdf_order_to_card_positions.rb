# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # This services maps the card order, in the PDF file, to card pack
    # positions. In ideal circumstances, this would be a 1-to-1 mapping, but it
    # can be affected by multiple factors:
    #
    #  - Some PDFs have extra non-playing cards at the start.
    #  - Some PDFs have multiple variants of the same card.
    #  - Some PDFs are intentionally out-of-order, like placing all the
    #    identities at the beginning.
    class MapPdfOrderToCardPositions
      attr_reader :options

      OutOfRangeError = Class.new(Error)

      def initialize(options)
        @options = options
      end

      # @return [Array<Integer, Integer>,nil] The "cycle position" and "pack
      #   position" of the card at the given "PDF position" or +nil+, if the
      #   card at this position is an "extra card."
      # @raises [OutOfRangeError] If the given number doesn't map to any card.
      def call(pdf_pos)
        assert_range!(pdf_pos)
        extra_card_pos?(pdf_pos) ? nil : pdf_order[pdf_pos - extra_start - 1]
      end

      # @return [Array<Integer>] Every "pack position" in {#pdf_order} that
      #   appears more than once.
      def variant_pack_codes
        pdf_order.select { variant?(_1) }
      end

      private

      def assert_range!(pdf_pos)
        max_val = extra_start + pdf_order.size + extra_end
        return unless pdf_pos < 1 || pdf_pos > max_val

        raise OutOfRangeError, "Card position #{pdf_pos} is outside of the " \
                               "expected range 1-#{max_val}"
      end

      def extra_start
        options.fetch(:extra_start, 0)
      end

      def extra_end
        options.fetch(:extra_end, 0)
      end

      def extra_card_pos?(pdf_pos)
        pdf_pos <= extra_start ||
          pdf_pos > extra_start + pdf_order.size + extra_end
      end

      def pdf_order
        @pdf_order ||= SelectNumbers.new(options[:card_order],
                                         min: first_cycle_pos_in_pack,
                                         max: last_cycle_pos_in_pack)
      end

      def first_cycle_pos_in_pack
        @first_cycle_pos_in_pack ||=
          if !pack || pack.position == 1
            1
          else
            earlier_packs.inject(0) { _1 + _2.size } + 1
          end
      end

      def last_cycle_pos_in_pack
        first_cycle_pos_in_pack + pack.size - 1
      end

      def pack
        @pack ||= database.pack(options[:pack_code]) if options[:pack_code]
      end

      def cycle
        @cycle ||= database.cycle(pack.cycle_code) if pack
      end

      def earlier_packs
        return [] unless pack

        @earlier_packs ||=
          database.packs.select do |other_pack|
            other_pack.position < pack.position &&
              other_pack.cycle_code == cycle.code &&
              !other_pack.name.match?(/booster pack/i)
          end
      end

      def database
        options.database
      end

      # @return [Boolean] If the given pack position appears in {#pdf_order}
      #   more than once.
      def variant?(pack_pos)
        count = 0
        pdf_order.each do |pos|
          count += 1 if pos == pack_pos
          return true if count > 1
        end
        false
      end
    end
  end
end
