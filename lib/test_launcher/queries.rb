module TestLauncher
  module Queries
    class BaseQuery
      attr_reader :shell, :searcher, :request
      def initialize(request:)
        @request = request
      end

      def command
        raise NotImplementedError
      end

      private

      def test_cases
        raise NotImplementedError
      end

      def runner
        request.runner
      end

      def shell
        request.shell
      end

      def searcher
        request.searcher
      end

      def one_file?
         file_count == 1
      end

      def file_count
        @file_count ||= test_cases.map {|tc| tc.file }.uniq.size
      end

      def most_recently_edited_test_case
        @most_recently_edited_test_case ||= test_cases.sort_by {|tc| File.mtime(tc.file)}.last
      end

      def build_query(klass)
        klass.new(
          request: request
        )
      end

      def pluralize(count, singular)
        phrase = "#{count} #{singular}"
        if count == 1
          phrase
        else
          "#{phrase}s"
        end
      end
    end

    class NamedQuery < BaseQuery
      def command
        return unless file

        shell.notify("Found matching test.")
        runner.single_example(test_case, exact_match: true)
      end

      def test_case
        request.test_case(
          file: file,
          example: request.example_name,
          request: request,
        )
      end

      def file
        if potential_files.size == 0
          shell.warn("Could not locate file: #{request.search_string}")
        elsif potential_files.size > 1
          shell.warn("Too many files matched: #{request.search_string}")
        else
          potential_files.first
        end
      end

      def potential_files
        @potential_files ||= searcher.test_files(request.search_string)
      end
    end

    class MultiTermQuery < BaseQuery
      def command
        return if test_cases.empty?

        shell.notify("Found #{pluralize(file_count, "file")}.")
        runner.multiple_files(test_cases)
      end

      def test_cases
        @test_cases ||= files.map { |file_path|
          request.test_case(
            file: file_path,
            request: request,
          )
        }
      end

      def files
        if found_files.any? {|files_array| files_array.empty? }
          shell.warn("It looks like you're searching for multiple files, but we couldn't identify them all.")
          []
        else
          found_files.flatten.uniq
        end
      end

      def found_files
        @found_files ||= queries.map {|query|
          searcher.test_files(query)
        }
      end

      def queries
        @queries ||= request.search_string.split(" ")
      end
    end

    class PathQuery < BaseQuery
      def command
        return if test_cases.empty?

        if one_file?
          shell.notify "Found #{pluralize(file_count, "file")}."
          runner.single_file(test_cases.first)
        elsif request.run_all?
          shell.notify "Found #{pluralize(file_count, "file")}."
          runner.multiple_files(test_cases)
        else
          shell.notify "Found #{pluralize(file_count, "file")}."
          shell.notify "Running most recently edited. Run with '--all' to run all the tests."
          runner.single_file(most_recently_edited_test_case)
        end
      end

      def test_cases
        @test_cases ||= files_found_by_path.map { |file_path|
          request.test_case(file: file_path, request: request)
        }
      end

      def files_found_by_path
        @files_found_by_path ||= searcher.test_files(request.search_string)
      end
    end

    class ExampleNameQuery < BaseQuery
      def command
        return if test_cases.empty?

        if one_example?
          shell.notify("Found 1 method in 1 file")
          runner.single_example(test_cases.first, exact_match: true)
        elsif one_file?
          shell.notify("Found #{test_cases.size} methods in 1 file")
          runner.single_example(test_cases.first) # it will regex with the query
        elsif request.run_all?
          shell.notify "Found #{pluralize(test_cases, "method")} in #{pluralize(file_count, "file")}."
          runner.multiple_files(test_cases)
        else
          shell.notify "Found #{pluralize(test_cases, "method")} in #{pluralize(file_count, "file")}."
          shell.notify "Running most recently edited. Run with '--all' to run all the tests."
          runner.single_example(most_recently_edited_test_case) # let it regex the query
        end
      end

      def test_cases
        @test_cases ||=
          examples_found_by_name.map { |grep_result|
            request.test_case(
              file: grep_result[:file],
              example: request.search_string,
              request: request
            )
          }
      end

      def examples_found_by_name
        @examples_found_by_name ||= searcher.examples(request.search_string)
      end

      def one_example?
        test_cases.size == 1
      end
    end

    class FullRegexQuery < BaseQuery
      def command
        return if test_cases.empty?

        if one_file?
          shell.notify "Found #{pluralize(file_count, "file")}."
          runner.single_file(test_cases.first)
        elsif request.run_all?
          shell.notify "Found #{pluralize(file_count, "file")}."
          runner.multiple_files(test_cases)
        else
          shell.notify "Found #{pluralize(file_count, "file")}."
          shell.notify "Running most recently edited. Run with '--all' to run all the tests."
          runner.single_file(most_recently_edited_test_case)
        end
      end

      def test_cases
        @test_cases ||=
          files_found_by_full_regex.map { |grep_result|
            request.test_case(
              file: grep_result[:file],
              request: request
            )
          }
      end

      def files_found_by_full_regex
        @files_found_by_full_regex ||= searcher.grep(request.search_string)
      end
    end

    class SingleTermQuery < BaseQuery
      def command
        [
          path_query,
          example_name_query,
          full_regex_query,
        ]
          .each { |query|
            command = query.command
            return command if command
          }
        nil
      end

      def path_query
        build_query(PathQuery)
      end

      def example_name_query
        build_query(ExampleNameQuery)
      end

      def full_regex_query
        build_query(FullRegexQuery)
      end
    end

    class SearchQuery < BaseQuery
      def command
        _command = multi_term_query.command if request.search_string.split(" ").size > 1
        return _command if _command

        single_term_query.command
      end

      def single_term_query
        build_query(SingleTermQuery)
      end

      def multi_term_query
        build_query(MultiTermQuery)
      end
    end

    class GenericQuery < BaseQuery
      def command
        if request.example_name
          named_query.command
        else
          search_query.command
        end
      end

      def named_query
        build_query(NamedQuery)
      end

      def search_query
        build_query(SearchQuery)
      end
    end
  end
end
