# frozen_string_literal: true

require 'tp_tree'

RSpec.describe TPTree::TreeBuilder do
  describe '#build' do
    it 'builds a tree from method calls without filter' do
      def test_method_a
        test_method_b
      end

      def test_method_b
        42
      end

      builder = TPTree::TreeBuilder.new do
        test_method_a
      end

      events = builder.build

      expect(events).not_to be_empty
      expect(events.first).to be_a(TPTree::TreeNode)
      expect(events.first.method_name).to eq(:test_method_a)
      expect(events.first.depth).to eq(0)
    end

    it 'tracks call depth correctly' do
      def deep_method_a
        deep_method_b
      end

      def deep_method_b
        deep_method_c
      end

      def deep_method_c
        'result'
      end

      builder = TPTree::TreeBuilder.new do
        deep_method_a
      end

      events = builder.build

      # Should have calls at different depths
      depths = events.map(&:depth).uniq.sort
      expect(depths).to include(0, 1, 2)
    end

    it 'distinguishes between call, return, and call_return events' do
      def parent_method
        child_method
      end

      def child_method
        'simple_result'
      end

      builder = TPTree::TreeBuilder.new do
        parent_method
      end

      events = builder.build

      event_types = events.map(&:event).uniq
      expect(event_types).to include(:call_return)
    end

    it 'captures method parameters' do
      def method_with_params(a, b = 'default')
        a + b
      end

      builder = TPTree::TreeBuilder.new do
        method_with_params('hello', 'world')
      end

      events = builder.build

      method_event = events.find { |e| e.method_name == :method_with_params }
      expect(method_event).not_to be_nil
      expect(method_event.parameters).not_to be_empty

      # Check parameter capture
      param_names = method_event.parameters.map { |_, name, _| name }
      expect(param_names).to include(:a, :b)
    end

    it 'captures return values' do
      def method_with_return
        'expected_return'
      end

      builder = TPTree::TreeBuilder.new do
        method_with_return
      end

      events = builder.build

      method_event = events.find { |e| e.method_name == :method_with_return }
      expect(method_event).not_to be_nil
      expect(method_event.return_value).to eq('expected_return')
    end

    it 'works with method filter' do
      filter = TPTree::MethodFilter.new(filter: 'filtered_method')

      def filtered_method
        'filtered'
      end

      def unfiltered_method
        'unfiltered'
      end

      builder = TPTree::TreeBuilder.new(method_filter: filter) do
        filtered_method
        unfiltered_method
      end

      events = builder.build

      method_names = events.map(&:method_name)
      expect(method_names).to include(:filtered_method)
      expect(method_names).not_to include(:unfiltered_method)
    end

    it 'handles empty block' do
      builder = TPTree::TreeBuilder.new do
        # empty block
      end

      events = builder.build
      expect(events).to be_empty
    end

    it 'captures timing information' do
      def slow_method
        sleep(0.001) # Small sleep to ensure measurable time
        'done'
      end

      builder = TPTree::TreeBuilder.new do
        slow_method
      end

      events = builder.build

      method_event = events.find { |e| e.method_name == :slow_method }
      expect(method_event).not_to be_nil
      expect(method_event.start_time).not_to be_nil
      expect(method_event.end_time).not_to be_nil
      expect(method_event.duration).to be > 0
    end
  end
end