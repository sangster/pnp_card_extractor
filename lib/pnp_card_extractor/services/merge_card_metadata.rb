# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # This service collects all metadata related to a card, by joining packs,
    # cycles, etc..
    class MergeCardMetadata
      PositionNotFoundError = Class.new(Error)

      attr_accessor :next_pdf_position
      attr_reader :options, :variants

      def initialize(options, next_position: 1)
        @options = options
        @next_pdf_position = next_position
        @variants = options.position_mapping.variant_pack_codes.to_h { [_1, 0] }
      end

      def call
        pdf_pos ||= next_pdf_position
        self.next_pdf_position += 1
        return { 'position' => pdf_pos } unless pack_code

        build_metadata(find_card(pdf_pos))
      end

      private

      def build_metadata(card)
        if card
          {}.merge(
            card.to_h,
            associated_metadata(card),
            variant_metadata(card)
          ).compact
        else
          { 'is_extra' => true, 'cycle' => cycle, 'pack' => pack }
        end
      end

      def find_card(pdf_pos)
        pack_pos = options.position_mapping.call(pdf_pos)
        return nil unless pack_pos # extra card

        cards.bsearch { _1.position >= pack_pos }.tap do |card|
          unless card
            pos = "(pdf_pos=#{pdf_pos}, pack_pos=#{pack_pos})"
            raise PositionNotFoundError,
                  "Could not find card #{pos} in pack metadata"
          end
        end
      end

      def cards
        return nil unless pack_code

        @cards ||= database.cards
                           .select { _1.pack_code == pack_code }
                           .sort_by(&:position)
      end

      def associated_metadata(card)
        {
          'cycle' => cycle,
          'faction' => database.factions.find { _1.code == card.faction_code },
          'pack' => pack,
          'side' => database.sides.find { _1.code == card.side_code },
          'type' => database.types.find { _1.code == card.type_code },
        }.compact
      end

      def pack
        @pack ||= database.packs.find { _1.code == pack_code } if pack_code
      end

      def pack_code
        options[:pack_code]
      end

      def cycle
        @cycle ||= database.cycle(pack.cycle_code) if pack
      end

      def variant_metadata(card)
        is_variant = variants.key?(card.position)
        return {} unless is_variant

        variants[card.position] += 1

        {
          'is_variant' => is_variant,
          'variant_position' => variants[card.position]
        }
      end

      def database
        options.database
      end
    end
  end
end
