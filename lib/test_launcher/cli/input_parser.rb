require "optparse"
# This could use some love

class InputParser
  ParseError = Class.new(RuntimeError)

  BANNER = <<-DESC
Find tests and run them by trying to match an individual test or the name of a test file(s).

See full README: https://github.com/petekinnecom/test_launcher

Usage: `test_launcher "search string" [--all]`

  DESC

  def initialize(args)
    @query = args
    @options = {}
    option_parser.parse!(args)
  rescue OptionParser::ParseError
    puts "Invalid arguments"
    puts "----"
    puts option_parser
    exit
  end

  def query
    if @query.size == 0
      puts option_parser
      exit
    elsif @query.size > 1
      puts "Concatenating args to single string. (see https://github.com/petekinnecom/test_launcher)"
    end

    @query.join(" ")
  end

  def options
    @options
  end

  private

  def option_parser
    OptionParser.new do |opts|
      opts.banner = BANNER

      opts.on("-a", "--all", "Run all matching tests. Defaults to false.") do
        options[:run_all] = true
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end

      opts.on("-f", "--framework framework", "The testing framework being used. Valid options: ['minitest', 'rspec', 'guess']. Defaults to 'guess'") do |framework|
        options[:framework] = framework
      end
    end
  end
end