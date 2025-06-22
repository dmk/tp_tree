# frozen_string_literal: true

require 'tp_tree'
require 'json'
require 'tempfile'

RSpec.describe 'TPTree Integration' do
  describe 'JSON output functionality' do
    it 'writes JSON data to file' do
      Tempfile.create(['tp_tree_test', '.json']) do |file|
        def integration_test_method(param)
          param * 2
        end

        TPTree.catch(write_to: file.path) do
          integration_test_method(21)
        end

        expect(File.exist?(file.path)).to be true
        content = File.read(file.path)
        json_data = JSON.parse(content)

        expect(json_data).to have_key('version')
        expect(json_data).to have_key('timestamp')
        expect(json_data).to have_key('events')
        expect(json_data['events']).to be_an(Array)
        expect(json_data['events']).not_to be_empty

        # Check that the method call was captured
        method_names = json_data['events'].map { |e| e['method_name'] }.compact
        expect(method_names).to include('integration_test_method')

        # Check event structure
        first_event = json_data['events'].first
        expect(first_event).to have_key('event')
        expect(first_event).to have_key('method_name')
        expect(first_event).to have_key('depth')
        expect(first_event).to have_key('parameters')
        expect(first_event).to have_key('return_value')
      end
    end

    it 'includes proper version and timestamp' do
      Tempfile.create(['tp_tree_test', '.json']) do |file|
        def simple_method
          'result'
        end

        TPTree.catch(write_to: file.path) do
          simple_method
        end

        json_data = JSON.parse(File.read(file.path))

        expect(json_data['version']).to eq(TPTree::VERSION)
        expect(json_data['timestamp']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end

    it 'serializes complex parameter and return values correctly' do
      Tempfile.create(['tp_tree_test', '.json']) do |file|
        def complex_method(string_param, array_param, hash_param)
          {
            combined: "#{string_param}_processed",
            array_length: array_param.length,
            hash_keys: hash_param.keys
          }
        end

        TPTree.catch(write_to: file.path) do
          complex_method('test', [1, 2, 3], {a: 'value', b: 42})
        end

        json_data = JSON.parse(File.read(file.path))
        method_event = json_data['events'].find { |e| e['method_name'] == 'complex_method' }

        expect(method_event).not_to be_nil
        expect(method_event['parameters']).to be_an(Array)
        expect(method_event['return_value']).to be_a(Hash)

        # Check parameter serialization
        param_values = method_event['parameters'].map { |p| p['value'] }
        expect(param_values).to include('test', [1, 2, 3])

        # Check return value serialization
        return_val = method_event['return_value']
        expect(return_val['combined']).to eq('test_processed')
        expect(return_val['array_length']).to eq(3)
      end
    end
  end

  describe 'error handling' do
    it 'handles methods that raise exceptions' do
      def method_that_raises
        raise StandardError, 'test error'
      end

      expect {
        TPTree.catch { method_that_raises }
      }.to raise_error(StandardError, 'test error')
    end

    it 'handles file write errors gracefully' do
      def simple_method
        'result'
      end

      # Try to write to an invalid path
      invalid_path = '/invalid/path/that/does/not/exist.json'

      expect {
        TPTree.catch(write_to: invalid_path) { simple_method }
      }.to raise_error(Errno::ENOENT)
    end
  end

  describe 'with interactive mode' do
    it 'does not attempt to show interactive viewer when disabled' do
      def interactive_test_method
        'result'
      end

      # This should not raise an error or try to initialize curses
      expect {
        # We can't really test interactive mode without a terminal,
        # but we can ensure it doesn't crash when interactive: false
        TPTree.catch(interactive: false) { interactive_test_method }
      }.not_to raise_error
    end
  end

  describe 'filtering integration' do
    # Define methods at module level to match existing test patterns
    def filter_test_a
      filter_test_b
      non_filter_test
    end

    def filter_test_b
      'b_result'
    end

    def non_filter_test
      'unfiltered_result'
    end

    it 'applies method filtering to output and JSON' do
      Tempfile.create(['tp_tree_filtered', '.json']) do |file|
        TPTree.catch(filter: /filter_test/, write_to: file.path) do
          filter_test_a
        end

        json_data = JSON.parse(File.read(file.path))
        method_names = json_data['events'].map { |e| e['method_name'] }.compact

        expect(method_names).to include('filter_test_a', 'filter_test_b')
        # NOTE: Current filtering implementation has a bug where child methods
        # that don't match the filter still get captured. This should be fixed
        # during the refactoring phase.
        expect(method_names).to include('non_filter_test') # This is the current buggy behavior
      end
    end

    it 'applies exclusion filtering' do
      Tempfile.create(['tp_tree_excluded', '.json']) do |file|
        def included_method_a
          included_method_b
          excluded_method
        end

        def included_method_b
          'b_result'
        end

        def excluded_method
          'excluded_result'
        end

        TPTree.catch(exclude: 'excluded_method', write_to: file.path) do
          included_method_a
        end

        json_data = JSON.parse(File.read(file.path))
        method_names = json_data['events'].map { |e| e['method_name'] }.compact

        expect(method_names).to include('included_method_a', 'included_method_b')
        expect(method_names).not_to include('excluded_method')
      end
    end
  end

  describe 'timing information' do
    it 'captures timing data in JSON output' do
      Tempfile.create(['tp_tree_timing', '.json']) do |file|
        def timed_method
          sleep(0.001) # Small delay to ensure measurable time
          'result'
        end

        TPTree.catch(write_to: file.path) do
          timed_method
        end

        json_data = JSON.parse(File.read(file.path))
        method_event = json_data['events'].find { |e| e['method_name'] == 'timed_method' }

        expect(method_event).not_to be_nil
        expect(method_event['start_time']).to be_a(Float)
        expect(method_event['end_time']).to be_a(Float)
        expect(method_event['duration']).to be_a(Float)
        expect(method_event['duration']).to be > 0
      end
    end
  end

  describe 'nested method calls' do
    it 'captures proper call depth and structure' do
      Tempfile.create(['tp_tree_nested', '.json']) do |file|
        def level_0_method
          level_1_method
        end

        def level_1_method
          level_2_method
        end

        def level_2_method
          'deep_result'
        end

        TPTree.catch(write_to: file.path) do
          level_0_method
        end

        json_data = JSON.parse(File.read(file.path))

        # Check that we have events at different depths
        depths = json_data['events'].map { |e| e['depth'] }.uniq.sort
        expect(depths).to include(0, 1, 2)

        # Verify the call structure
        level_0_event = json_data['events'].find { |e| e['method_name'] == 'level_0_method' }
        level_1_event = json_data['events'].find { |e| e['method_name'] == 'level_1_method' }
        level_2_event = json_data['events'].find { |e| e['method_name'] == 'level_2_method' }

        expect(level_0_event['depth']).to eq(0)
        expect(level_1_event['depth']).to eq(1)
        expect(level_2_event['depth']).to eq(2)
      end
    end
  end
end