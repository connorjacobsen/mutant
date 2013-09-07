# encoding: utf-8

require 'optparse'

module Mutant

  # Comandline parser
  class CLI
    include Adamantium::Flat, Equalizer.new(:config)

    # Error raised when CLI argv is invalid
    Error = Class.new(RuntimeError)

    EXIT_FAILURE = 1
    EXIT_SUCCESS = 0

    # Run cli with arguments
    #
    # @param [Array<String>] arguments
    #
    # @return [Fixnum]
    #   returns exit status
    #
    # @api private
    #
    def self.run(arguments)
      config = new(arguments).config
      runner = Runner::Config.run(config)
      runner.success? ? EXIT_SUCCESS : EXIT_FAILURE
    rescue Error => exception
      $stderr.puts(exception.message)
      EXIT_FAILURE
    end

    # Initialize objecct
    #
    # @param [Array<String>]
    #
    # @return [undefined]
    #
    # @api private
    #
    def initialize(arguments = [])
      @filters, @matchers = [], []
      @debug = @fail_fast = @zombie = false
      @cache = Mutant::Cache.new
      @strategy_builder = nil

      parse(arguments)
      config # trigger lazyness
    end

    # Return config
    #
    # @return [Config]
    #
    # @api private
    #
    def config
      Config.new(
        cache:     @cache,
        zombie:    @zombie,
        debug:     debug?,
        matcher:   matcher,
        filter:    filter,
        fail_fast: @fail_fast,
        strategy:  strategy,
        reporter:  reporter
      )
    end
    memoize :config

  private

    # Test for running in debug mode
    #
    # @return [true]
    #   if debug mode is active
    #
    # @return [false]
    #   otherwise
    #
    # @api private
    #
    def debug?
      @debug
    end

    # Return mutation filter
    #
    # @return [Mutant::Matcher]
    #
    # @api private
    #
    def filter
      if @filters.empty?
        Filter::ALL
      else
        Filter::Whitelist.new(@filters)
      end
    end

    # Return stratety
    #
    # @return [Strategy]
    #
    # @api private
    #
    def strategy
      unless @strategy_builder
        raise(Error, 'No strategy was set!')
      end
      @strategy_builder.strategy
    end

    # Return reporter
    #
    # @return [Mutant::Reporter::CLI]
    #
    # @api private
    #
    def reporter
      Reporter::CLI.new($stdout)
    end

    # Return matcher
    #
    # @return [Mutant::Matcher]
    #
    # @raise [CLI::Error]
    #   raises error when matcher is not given
    #
    # @api private
    #
    def matcher
      if @matchers.empty?
        raise(Error, 'No matchers given')
      end

      Matcher::Chain.build(@matchers)
    end

    # Add mutation filter
    #
    # @param [Class<Filter>] klass
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_filter(klass, *arguments)
      @filters << klass.new(*arguments)
    end

    # Parse the command-line options
    #
    # @param [Array<String>] arguments
    #   Command-line options and arguments to be parsed.
    #
    # @raise [Error]
    #   An error occurred while parsing the options.
    #
    # @return [undefined]
    #
    # @api private
    #
    def parse(arguments)
      opts = OptionParser.new do |builder|
        builder.banner = 'usage: mutant STRATEGY [options] MATCHERS ...'
        builder.separator('')
        add_strategies(builder)
        add_environmental_options(builder)
        add_options(builder)
      end

      matchers =
        begin
          opts.parse!(arguments)
        rescue OptionParser::ParseError => error
          raise(Error, error.message, error.backtrace)
        end

      parse_matchers(matchers)
    end

    # Parse matchers
    #
    # @param [Enumerable<String>] patterns
    #
    # @return [undefined]
    #
    # @api private
    #
    def parse_matchers(patterns)
      patterns.each do |pattern|
        matcher = Classifier.build(@cache, pattern)
        @matchers << matcher if matcher
      end
    end

    # Add strategies
    #
    # @param [OptionParser] parser
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_strategies(parser)
      parser.separator(EMPTY_STRING)
      parser.separator('Strategies:')

      writer = lambda do |builder|
        @strategy_builder = builder
      end

      [
        Builder::Rspec
      ].each do |builder|
        builder.add_options(parser, &writer)
      end
    end

    # Add environmental options
    #
    # @param [Object] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_environmental_options(opts)
      opts.on('--zombie', 'Run mutant zombified') do
        @zombie = true
      end.on('-I', 'Add directory to $LOAD_PATH') do |directory|
        $LOAD_PATH << directory
      end.on('-r', '--require NAME', 'Require file with NAME') do |name|
        require(name)
      end
    end

    # Add options
    #
    # @param [Object] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_options(opts)
      opts.separator ''
      opts.separator 'Options:'

      opts.on('--version', 'Print mutants version') do |name|
        puts("mutant-#{Mutant::VERSION}")
        Kernel.exit(0)
      end.on('--code FILTER', 'Adds a code filter') do |filter|
        add_filter(Filter::Attribute, :code, filter)
      end.on('--fail-fast', 'Fail fast') do
        @fail_fast = true
      end.on('-d', '--debug', 'Enable debugging output') do
        @debug = true
      end.on_tail('-h', '--help', 'Show this message') do
        puts(opts)
        exit
      end
    end
  end # CLI
end # Mutant
