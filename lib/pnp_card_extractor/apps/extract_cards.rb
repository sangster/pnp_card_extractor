# frozen_string_literal: true

require 'poppler'

module PnpCardExtractor
  module Apps
    # The primary application which extracts card PNG images from a given PDF.
    class ExtractCards < Base
      attr_reader :cols, :rows

      def initialize(options, rows = 3, cols = 3)
        super(options)
        @rows = rows
        @cols = cols
      end

      def call
        debug { 'Starting...' }
        sliced_cards do |page_number, card_number, card|
          image_writer.call(card, page_number, card_number)
        end
        debug { 'Done.' }
      end

      private

      def sliced_cards(&blk)
        selected_pages.each do |page_number, page|
          info { "Extracting cards from Page #{page_number} of #{num_pages}..." }
          card_number = 0
          slice_cards(page).each do |card|
            blk.call(page_number, card_number += 1, card)
          end
          info { "Extracted #{card_number} card(s) from Page #{page_number}." }
        end
      end

      def selected_pages
        @selected_pages ||= begin
          debug { 'Reading PDF pages...' }
          pages = document.to_a
          selected_page_numbers
            .to_h { [_1, pages[_1 - 1]] }
            .tap { debug { "Read #{pages.size} PDF page(s)." } }
        end
      end

      def document
        @document ||= Poppler::Document.new(path: options.pdf_path)
      end

      def selected_page_numbers
        Services::SelectNumbers.new(options[:pages_str].to_s,
                                    max: num_pages, unique: true)
      end

      def num_pages
        document.count
      end

      def slice_cards(page)
        images = load_images(page)

        if images_need_to_be_sliced?
          Services::SliceCards.new(options, rows, cols).call(images.first)
        else
          images
        end
      end

      # It seems that PDFs come in two sorts:
      #
      #   1. Each card, on each page, is its own separate image.
      #   2. On each page, all cards are part of a single image.
      #
      # We assume that any PDFs that have any pages with multiple images are of
      # the former type. For PDFs of the latter type, the singular images need
      # to be cut up into the separate card images.
      def images_need_to_be_sliced?
        @images_need_to_be_sliced ||=
          document.map(&:image_mapping).none? { _1.size > 1 }
      end

      def load_images(page)
        debug { 'Loading images from Cairo surface...' }
        Image.from_page(page).tap do |images|
          debug { "Loaded #{images.size} image(s):" }
          images.each do |img|
            debug { "  -> #{img.width}x#{img.height} image" }
          end
        end
      end

      def image_writer
        @image_writer ||= Services::WriteImages.new(options)
      end
    end
  end
end
