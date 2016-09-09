require "test_launcher/utils/path"

module TestLauncher
  module Frameworks
    module Minitest
      module Wrappers
        class SingleRoot

          attr_reader :files

          def initialize(files)
            @files = files.map {|f| f.is_a?(SingleFile) ? f : SingleFile.new(f)}
          end

          def to_s
            %{cd #{app_root} && ruby -I test -e 'ARGV.each { |file| require(Dir.pwd + "/" + file) }' #{files.map(&:relative_test_path).join(" ")}}
          end

          def app_root
            files.first.app_root
          end
        end
      end
    end
  end
end