# frozen_string_literal: true

require 'chunky_png'
require 'stringio'

module PnpCardExtractor
  # A more convenient wrapper around {Cairo::ImageSurface}.
  class Image
    attr_reader :height, :offset_x, :offset_y, :pixel_data_height,
                :pixel_data_width, :surface, :width

    class << self
      def from_page(page)
        page
          .image_mapping
          .sort_by { [_1.area.y1, _1.area.x1] }
          .map { from_cairo_surface(_1.image) }
      end

      def from_cairo_surface(surface)
        new(surface, surface.width, surface.height)
      end
    end

    def initialize(surface, width, height, offset_x: 0, offset_y: 0)
      @surface = surface
      @width = width
      @height = height
      @offset_x = offset_x
      @offset_y = offset_y
      @pixel_data_width = surface.width
      @pixel_data_height = surface.height
    end

    def pixel_data
      @pixel_data ||= surface.data.bytes.each_slice(pixel_width).to_a
    end

    def format_code
      @format_code ||= surface.format
    end

    def pixel_width
      return 4 if format_code == Cairo::FORMAT_ARGB32

      raise Error, "Unexpected format: #{format_code}"
    end

    # Create another {Image} using the same {#pixel_data} as this one.
    def create_view(x, y, w, h)
      self.class.new(surface.sub_rectangle_surface(x, y, w, h),
                     w, h, offset_x: x, offset_y: y).tap do |view|
        view.copy_pixels(pixel_data, pixel_data_width, pixel_data_height,
                         format_code)
      end
    end

    def copy_pixels(data, width, height, code)
      @pixel_data = data
      @pixel_data_width = width
      @pixel_data_height = height
      @format_code = code
    end

    # The last page may not have the full number of cards. Those missing cards
    # will have transparent pixels in their center.
    def blank?
      center_pixel_data.last.zero?
    end

    def center_pixel_data
      idx = (offset_y + height / 2) * pixel_data_width + offset_x + width / 2
      pixel_data[idx]
    end

    def to_chunky
      io = StringIO.new(''.b)
      surface.write_to_png(io)
      io.rewind
      ChunkyPNG::Image.from_io(io)
    end

    def inspect
      format('#<%<class>s %<width>dx%<height>d+%<offset_x>d+%<offset_y>d>',
             class: self.class,
             width:,
             height:,
             offset_x:,
             offset_y:)
    end
  end
end
