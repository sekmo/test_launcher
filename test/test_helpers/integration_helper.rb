require "test_launcher/search/git"
require "test_launcher/shell/runner"

require "test_launcher/cli"
require "test_helpers/mocks"
require "test_launcher/shell/history_runner"

module TestLauncher
  module IntegrationHelper
    include DefaultMocks

    class IntegrationShell < MockShell
      def exec(string)
        raise "Cannot exec twice!" if @exec
        @exec = string
      end

      def recall_exec
        @exec
      end

      def reset
        @exec = nil
      end
    end

    private

    def shell_mock
      @shell_mock ||= IntegrationShell.new
    end
  end
end
