module Minitest
  module Reporters
    # Turn-like reporter that reads like a spec.
    #
    # Based upon TwP's turn (MIT License) and paydro's monkey-patch.
    #
    # @see https://github.com/TwP/turn turn
    # @see https://gist.github.com/356945 paydro's monkey-patch
    class SpecReporter < BaseReporter
      include ANSI::Code
      include RelativePosition

      def start
        super
        puts('Started with run options %s' % options[:args])
        puts
      end

      def report
        super
        failed_tests = tests.select { |test| !test.failures.empty? }
        unless failed_tests.empty?
          print(red 'Failures and errors:')
          failed_tests.each { |test| print_failure(test) }
        end
        puts('Finished in %.5fs' % total_time)
        print('%d tests, %d assertions, ' % [count, assertions])
        color = failures.zero? && errors.zero? ? :green : :red
        print(send(color) { '%d failures, %d errors, ' } % [failures, errors])
        print(yellow { '%d skips' } % skips)
        puts
      end

      def record(test)
        super
        record_print_status(test)
      end

      protected

      def before_suite(suite)
        puts suite
      end

      def after_suite(_suite)
        puts
      end

      def print_failure(test)
        puts
        record_print_status(test)
        print_info(test.failure, test.error?)
        puts "Location:\n\t #{test.source_location.join(':')}"
        puts
      end

      def record_print_status(test)
        test_name = test.name.gsub(/^test_: /, 'test:')
        print pad_test(test_name)
        print_colored_status(test)
        print(" (%.2fs)" % test.time) unless test.time.nil?
        puts
      end
    end
  end
end
