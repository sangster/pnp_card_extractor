# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # Save PNG images to the disk. Card info fetched from NetrunneDB can be used
    # to create the filename and also be written as metadata to the saved files.
    class WriteImages
      include Logging

      DEFAULT_PREFIX = 'netrunner:'
      DEFAULT_METADATA = %w[
        code cost deck_limit faction_cost flavor illustrator position quantity
        stripped_text stripped_title text title uniqueness

        is_variant variant_position

        page_number card_number
        cycle.code cycle.name
        faction.code faction.color faction.name
        pack.code pack.name pack.date_release pack.size
        side.code side.name
        type.code type.name type.is_subtype
      ].freeze

      attr_reader :options, :png_metadata, :png_metadata_prefix

      # @param options [Options]
      def initialize(options, png_metadata: DEFAULT_METADATA,
                     png_metadata_prefix: DEFAULT_PREFIX)
        @options = options
        @png_metadata = png_metadata
        @png_metadata_prefix = png_metadata_prefix
      end

      # @param card [Image]
      def call(card, page_number, card_number)
        meta = card_metadata(page_number, card_number)
        path = card_filename(meta)
        if path.exist?
          if options[:force]
            warn { "Will replace existing file: #{path}" }
          else
            warn { "Skipping existing file: #{path}" }
            return
          end
        end

        info { "Writing page #{page_number} card #{card_number} to #{path}" }
        path.dirname.mkpath
        save_pdf_with_metadata(card, meta, path).tap { debug { 'Done.' } }
      end

      private

      def card_metadata(page_number, card_number)
        metadata.call.merge({ 'page_number' => page_number,
                              'card_number' => card_number })
      end

      def card_filename(meta)
        template = meta['is_extra'] ? extra_template : filename_template
        (Pathname(options[:directory]) / template.call(meta))
      end

      def metadata
        @metadata ||= MergeCardMetadata.new(options)
      end

      def filename_template
        @filename_template ||=
          if options[:pack_code]
            FilenameTemplate.new(options[:filename_template])
          else
            FilenameTemplate.new('Page {page_number}/Card {card_number}.png')
          end
      end

      def extra_template
        @extra_template ||= FilenameTemplate.new(options[:extra_template])
      end

      def save_pdf_with_metadata(card, meta, path)
        debug { 'Converting cairo surface to ChunkyPNG...' }
        chunky = card.to_chunky

        debug { 'Adding metadata to ChunkyPNG...' }
        add_png_metadata(chunky, meta)

        debug { "Saving ChunkyPNG to #{path}" }
        chunky.save(path)
        chunky
      end

      def add_png_metadata(chunky, meta)
        png_metadata.each do |key|
          val = meta.dig(*key.split('.'))
          next if val.nil?

          key = png_metadata_prefix + key
          chunky.metadata[key] = val.to_s
          debug { "  -> #{key}: #{val}" }
        end
      end

      def logger
        options.logger
      end
    end
  end
end
