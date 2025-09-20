# frozen_string_literal: true

require 'logger'
require 'optparse'
require 'optparse/uri'

module PnpCardExtractor
  # Parses command-line options.
  class Options # rubocop:disable Metrics/ClassLength
    OptionsError = Class.new(Error)

    DEFAULTS = {
      card_order: '-',
      pages_str: '2-',
      filename_template: [
        '{cycle.position} {cycle.name}',
        '{pack.position} {pack.name}',
        '{code}{is_variant ? "-"}{is_variant ? variant_position} ' \
        '{stripped_title}.png',
      ].join('/').freeze,
      extra_template: [
        '{cycle.position} {cycle.name}',
        '{pack.position} {pack.name}',
        'extra-cards',
        'Page {page_number} Card {card_number}.png',
      ].join('/').freeze,
      directory: './',
      api_uri: Db::NetrunnerdbApi::DEFAULT_HOST,
      extra_start: 0,
      extra_end: 0,
      log_level: Logging::LEVELS[:warn],
    }.freeze

    attr_reader :pdf_path, :values

    def self.call(...)
      new.tap { _1.call(...) }
    end

    def initialize
      @pdf_path = nil
      @values = {}
    end

    def call(args)
      parse!(args.dup)
      @pdf_path = wrap_pdf_path(pdf_path) unless self[:run_mode]

      [pdf_path, values]
    end

    def parse!(args)
      @pdf_path, *rest = parser.parse(args.dup)
      raise OptionsError, 'Too many arguments given.' if rest.any?

      @values = DEFAULTS.merge(@values)
    end

    def [](key)
      values[key]
    end

    def fetch(...)
      values.fetch(...)
    end

    def database
      @database ||= begin
        db_api = self[:offline] ? nil : api
        source =
          if self[:disable_cache]
            db_api
          else
            Db::DiskCache.new(cache_dir, db_api, logger:)
          end
        Db::MemoryCache.new(source, logger:)
      end
    end

    # @return {Logger} A logger based on runtime options.
    def logger
      @logger ||= self[:silent] ? Logging.nil_logger : build_logger
    end

    def cache_dir
      @cache_dir ||=
        if self[:cache_dir]
          Pathname(self[:cache_dir])
        else
          cache_home = Pathname(ENV.fetch('XDG_CACHE_HOME', '~/.cache'))
          (cache_home / 'pnp_card_extractor').expand_path
        end
    end

    def api
      @api ||=
        Db::NetrunnerdbApi.new(fetch(:api_uri, DEFAULTS[:api_uri]), logger:)
    end

    def find_margins
      @find_margins ||=
        if self[:margins]
          Services::FindMargins::Given.new(self[:margins], logger:)
        elsif self[:measure_all_margins]
          Services::FindMargins.new(logger:)
        else
          Services::FindMargins::FindOnce.new(logger:)
        end
    end

    def position_mapping
      @position_mapping ||= Services::MapPdfOrderToCardPositions.new(self)
    end

    def inspect
      format('#<%<class>s pdf_path=%<pdf_path>p, %<values>p>',
             class: self.class, pdf_path:, values:)
    end

    private

    def parser
      @parser ||=
        OptionParser.new("Usage: #{$PROGRAM_NAME} [OPTIONS] PDF_FILE") do |op|
          common_options(op)
          metadata_options(op)
          other_run_modes(op)
          section_descriptions(op)
        end
    end

    def common_options(op) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      op.separator "\nOPTIONS\n\n"
      op.on('-p', '--pages=NUMBERS',
            'The pages to extract cards from. ' \
            "See NUMBERS section. #{def_str :pages_str}") do |str|
        values[:pages_str] = str
      end
      op.on('-f', '--force', 'Overwrite existing files.') do
        values[:force] = true
      end
      op.on('-d', '--directory=DIRECTORY',
            'Directory to export cards into. Will be ignored if ' \
            '--filename-template ',
            "defines an absolute path. #{def_str :directory}") do |str|
        values[:directory] = str
      end
      op.on('-m', '--margins=MARGINS',
            'Use the given margins ("top,right,bottom,left"), ' \
            'instead of measuring.') do |str|
        margins = str.split(/\s*,\s*/).map(&:to_i)
        unless margins.size == 4
          raise OptionsError, 'Expected margins to be 4, comma-separated ' \
                              "numbers, but got '#{str}'"
        end
        top, right, bottom, left = margins
        values[:margins] = { top:, right:, bottom:, left: }
      end
      op.on('-M', '--measure-all-margins',
            'Instead of assuming they\'re all equal, measure each margin ' \
            'on every page.') do
        values[:measure_all_margins] = true
      end
      op.on('-s', '--silent', 'Do not print any logging messages.') do
        values[:silent] = true
      end
      op.on('-v', '--verbose [LEVEL]',
            'Increase verbosity (can be repeated)',
            "or set to one of #{Logging::LEVELS.keys.join(', ')}") do |level|
        id =
          if level
            Logging::LEVELS.fetch(level.downcase.to_sym) do
              raise OptionsError, "unknown log level '#{level}'"
            end
          else
            values.fetch(:verbosity, DEFAULTS[:log_level]) - 1
          end
        values[:verbosity] = id.clamp(*Logging::LEVELS.values.minmax)
      end
    end

    def metadata_options(op) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      op.separator "\nMETADATA\n\n"
      op.on('-a', '--api=URI', URI, 'NetrunnerDB API to fetch metadata from.',
            def_str(:api_uri)) do |uri|
        values[:api_uri] = uri
      end
      op.on('-c', '--pack-code=CODE', 'NetrunnerDB card pack code.') do |str|
        values[:pack_code] = str
      end
      op.on('-o', '--card-order=NUMBERS',
            'The order of card number in the PDF. See NUMBERS and CARD ' \
            'ORDER sections.',
            def_str(:card_order)) do |num_str|
        values[:card_order] = num_str
      end
      op.on('-e', '--extra-start=NUM', OptionParser::DecimalInteger,
            'Extra, non-playing cards at the start of the PDF.',
            "See EXTRA CARDS section. #{def_str :extra_start}") do |n|
        values[:extra_start] = n
      end
      op.on('-E', '--extra-end=NUM', OptionParser::DecimalInteger,
            'Extra, non-playing cards at the end of the PDF.',
            "See EXTRA CARDS section. #{def_str :extra_end}") do |n|
        values[:extra_end] = n
      end
      op.on('-t', '--card-template=TEMPLATE',
            'The filename template for extracted card PNG files.',
            'See FILENAME TEMPLATE section.') do |str|
        values[:filename_template] = str
      end
      op.on('-T', '--extra-template=TEMPLATE',
            'The filename template for extracted non-playing-card PNG files.',
            'See FILENAME TEMPLATE section.') do |str|
        values[:extra_template] = str
      end
      op.on('-C', '--cache-directory=CODE',
            'Directory to store cached metadata in.',
            '(Default: $XDG_CACHE_HOME/pnp_card_extractor/ or ' \
            '~/.cache/pnp_card_extractor/)') do |str|
        values[:cache_dir] = str
      end
      op.on('--no-disk-cache', 'Do not use disk cache.') do
        values[:disable_cache] = true
      end
      op.on('--offline', 'Do not use NetrunnerDB API.') do
        values[:offline] = true
      end
    end

    def other_run_modes(op)
      op.separator "\nOTHER RUN-MODES\n"
      op.on('--list-card-packs', 'Print the available card packs and quit.') do
        values[:run_mode] = :list_card_packs
      end
    end

    def section_descriptions(op) # rubocop:disable Metrics/MethodLength
      op.separator ''
      op.separator(<<~SECTIONS)
        NUMBERS

        Some command-line arguments ask for a list of numbers. You can provide
        a list of "items," separated by either commas or spaces. Each item in
        the list must be either an integer, or a range: two integers separated
        by a dash. Both integers in a range are optional. If the left integer
        is missing, the beginning of the range will be used; if the right is
        missing, the end of the range will be used.

        Example ranges (excluding quotation marks):

          "-10,15,16,20-"
          "1 2 3 10-20 21"
          "10-"
          "-20"
          "-"

        FILENAME TEMPLATE

        If Netrunner metadata is available, either cached or from the
        NetrunnerDB API, you can use that metadata in the filenames of
        exported card images. To use a variable, justs put the variable name
        inside of curly braces. You can use dot-notation for nested variables.

        For this feature to work, you need to set --pack-code, to identify the
        pack. Also, if the cards in the PDF don't start with Card #1 from that
        pack, use --card-offset.

        If metadata is available, the default template for playing cards will be:

          {cycle.position} {cycle.name}/{pack.position} {pack.name}/{code}{is_variant ? "-"}{is_variant ? variant_position} {stripped_title}.png

        If metadata is available, the default template for extra cards will be:

          {cycle.position} {cycle.name}/{pack.position} {pack.name}/extra-cards/Page {page_number} Card {card_number}.png

        If metadata isn't available, the default template will be:

          Page {page_number}/Card {card_number}.png

        The metadata available depends on what data is returned from the
        Netrunner API, but here are some examples:

          {base_link} :: The base link of an identity.
          {code} :: A unique identifier for the card.
          {cycle.code} :: A unique identifier for the card's cycle.
          {cycle.name} :: The name of the card's cycle.
          {cycle.size} :: The number of sets in the cycle.
          {deck_limit} :: The max number per deck.
          {faction.code} :: A unique identifier for the card's faction.
          {faction.color} :: A color (hex-format) identifying the faction.
          {faction.is_mini} :: Is it a mini-faction?
          {faction.is_neutral} :: Is it a neutral card?
          {faction.name} :: The name of the card's faction.
          {flavor} :: Flavor text on the card.
          {illustrator} :: Who drew the card art.
          {influence_limit} :: The card's influence limit.
          {is_variant} :: If there are multiple versions of this card.
          {keywords} :: The cards keywords, separated by dashes.
          {minimum_deck_size} :: The identity's minimum deck size.
          {pack.code} :: A unique identifier for the card's pack.
          {pack.date_released} :: When the pack was published.
          {pack.name} :: The name of the pack.
          {pack.size} :: The number of cards in the pack.
          {position} :: The card's position in its pack.
          {quantity} :: The number of copies included in the card's pack.
          {side.code} :: A unique identifier for the card's side
          {side.name} :: Either "Runner" or "Corp"
          {stripped_text} :: Same as {text} without formatting tags.
          {stripped_title} :: Same as {title} without formatting tags.
          {text} :: The text written in the card's body.
          {title} :: The text at the top of the card.
          {type.code} :: A unique identifier for the card's type.
          {type.is_subtype} :: If it's a subtype.
          {type.name} :: The name of the card's type
          {uniqueness} :: If only one instance can be in play at once.
          {variant_position} :: The card's position among its own variants.

        CARD ORDER

        Every card in each cycle is uniquely numbered and in most PDFs, the
        first card is numbered 1 and each card that follows is subsequently
        numbered. That isn't always true though. Some cycles include multiple
        packs, so a PDF will begin with a card greater than 1. Moreover, some
        PDFs include variations on a single card, and other PDFs aren't
        ordered sequentially.

        EXTRA CARDS

        Some PDF include extra cards at the beginning and/or end of the PDF.
        These aren't playing cards, but may include information about new
        rules or game characters. They can still be exported, but will have
        access to less metadata. For instance, they don't have titles or other
        card-specific data.
      SECTIONS
    end

    def def_str(key)
      "(Default: #{DEFAULTS[key]})"
    end

    def wrap_pdf_path(str)
      Pathname(str).tap do |path|
        raise OptionsError, "Unreadable: #{path}" unless path.readable?
      end
    rescue TypeError
      raise OptionsError, 'No PDF file given.'
    end

    def build_logger
      level = fetch(:verbosity, DEFAULTS[:log_level])
      Logging.wrap_logger(Logger.new($stderr, level:).tap do |log|
        log.formatter = proc do |sev, time, name, msg|
          trim_log_fields(time, sev, name).join('  ').concat(": #{msg}\n")
        end
      end)
    end

    def trim_log_fields(time, sev, name)
      [
        time.strftime('%Y-%m-%d %H:%M:%S'),
        sev[...5].ljust(5),
        name.to_s.split('::', 2).last,
      ]
    end
  end
end
