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

      # The constructor takes an `options` hash
      # @param options [Hash]
      # @option options print_failure_summary [Boolean] wether to print the errors at the bottom of the
      #   report or inline as they happen.
      #
      def initialize(options = {})
        super
        @print_failure_summary = options[:print_failure_summary]
      end

      def start
        test_count = Runnable.runnables.sum { |s| s.runnable_methods.count }
        payload = JSON.fast_generate(test_count: test_count)
        print "\\n|||NEW_MESSAGE|||RUNNING|||minitest_start|||\#{payload}|||\\n"
        super
        # puts('Started with run options %s' % options[:args])
        # puts
      end

      def get_output
        return if $stdout.pos == 0
        $stdout.rewind
        res = $stdout.read
        $stdout.flush
        $stdout.rewind
        return unless res
        res.strip.chomp if res.strip.chomp != ''
      end

      def before_test(test)
        super
        $stdout = StringIO.new()
        # print "\\n\#{test.class}#\#{test.name} " if options[:verbose]
      end

      def report
        super
        if @print_failure_summary
          failed_test_groups = tests.reject { |test| test.failures.empty? }
                                    .sort_by { |test| [test_class(test).to_s, test.name] }
                                    .group_by { |test| test_class(test).to_s }
          unless failed_test_groups.empty?
            print(red('Failures and errors:'))

            failed_test_groups.each { |name, tests| print_failure(name, tests) }
          end
        end

        # puts('Finished in %.5fs' % total_time)
        # print('%d tests, %d assertions, ' % [count, assertions])
        # color = failures.zero? && errors.zero? ? :green : :red
        # print(send(color) { '%d failures, %d errors, ' } % [failures, errors])
        # print(yellow { '%d skips' } % skips)
        # puts
      end

      def record(test)
        test_finished(test)
        super
        # record_print_status(test)
        # record_print_failures_if_any(test) unless @print_failure_summary
      end

      protected

      def before_suite(suite)
        # puts suite
      end

      def after_suite(_suite)
        # puts
      end

      def print_failure(name, tests)
        puts
        puts name
        tests.each do |test|
          record_print_status(test)
          print_info(test.failure, test.error?)
          puts
        end
      end

      def record_print_failures_if_any(test)
        if !test.skipped? && test.failure
          print_info(test.failure, test.error?)
          puts
        end
      end

      def record_print_status(test)
        test_name = test.name.gsub(/^test_: /, 'test:')
        print pad_test(test_name)
        print_colored_status(test)
        print(" (%.2fs)" % test.time) unless test.time.nil?
        puts
      end

      def screenshots_base64(output)
        return unless output
        img_path = output&.scan(/\\[Screenshot Image\\]: (.*)$/)&.flatten&.first&.strip&.chomp ||
          output&.scan(/\\[Screenshot\\]: (.*)$/)&.flatten&.first&.strip&.chomp

        if img_path && File.exist?(img_path)
          STDOUT.puts "SCREENSHOT!"
          Base64.strict_encode64(File.read(img_path))
        end


      end

      def test_finished(test)
        output = get_output

        location = if test.source_location.join(":").start_with?("/app")
                    test.source_location.join(":")
                   else
                    if (file = `cat /cache/bundle/minitest_cache_file | grep '\#{test.klass} => '`.split(' => ').last&.chomp)
                      file + ":"
                    else
                      file = `grep -rw '/app' -e '\#{test.klass} '`.split(':').first
                      `echo '\#{test.klass} => \#{file}' >> /cache/bundle/minitest_cache_file`
                      file + ":"
                    end
                   end

        fully_formatted = if test.failure
                            fully_formatted = "\\n" + test.failure.message.split("\n").first

                            test.failure.backtrace.each do |l|
                              if !l['/cache/']
                                fully_formatted << "\\n    " + cyan + l + "\\033[0m"
                              end
                            end

                            fully_formatted
                          end

                          output_inside = output&.split("\\n")&.select do |line|
                            !line['Screenshot']
                          end&.join('\\n')


        payload = JSON.fast_generate(
          test_class: test_class(test),
          test_name: test.name.gsub(/^test_\\d*/, '').gsub(/^test_: /, 'test:').gsub(/^_/, '').strip,
          assertions_count: test.assertions,
          location: location,
          status: status(test),
          run_time: test.time,
          fully_formatted: fully_formatted,
          output_inside: output_inside,
          screenshots_base64: [screenshots_base64(output)]
        )

        print "\\n|||NEW_MESSAGE|||RUNNING|||minitest_test_finished|||\#{payload}|||\\n"
      end

      def status(test)
        if test.passed?
          'passed'
        elsif test.error?
          'error'
        elsif test.skipped?
          'skipped'
        elsif test.failure
          'failed'
        else
          raise("Status not found")
        end
      end
    end
  end
end