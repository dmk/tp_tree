# frozen_string_literal: true

require 'tp_tree'

RSpec.describe TPTree::TreeNode do
  let(:simple_node) do
    TPTree::TreeNode.new(
      :call_return,
      :test_method,
      [[:req, :param, 'value']],
      'return_value',
      1,
      Object,
      '/test/path.rb',
      42,
      Time.now - 0.5,
      Time.now
    )
  end

  describe '#initialize' do
    it 'sets all attributes correctly' do
      start_time = Time.now - 1
      end_time = Time.now

      node = TPTree::TreeNode.new(
        :call,
        :method_name,
        [[:req, :param1, 'value1']],
        'return_val',
        2,
        String,
        '/path/to/file.rb',
        123,
        start_time,
        end_time
      )

      expect(node.event).to eq(:call)
      expect(node.method_name).to eq(:method_name)
      expect(node.parameters).to eq([[:req, :param1, 'value1']])
      expect(node.return_value).to eq('return_val')
      expect(node.depth).to eq(2)
      expect(node.defined_class).to eq(String)
      expect(node.path).to eq('/path/to/file.rb')
      expect(node.lineno).to eq(123)
      expect(node.start_time).to eq(start_time)
      expect(node.end_time).to eq(end_time)
    end
  end

  describe '#duration' do
    it 'calculates duration when both times are present' do
      start_time = Time.now - 0.5
      end_time = Time.now

      node = TPTree::TreeNode.new(
        :call_return, :test, nil, nil, 0, nil, nil, nil,
        start_time, end_time
      )

      expect(node.duration).to be_within(0.1).of(0.5)
    end

    it 'returns nil when start_time is missing' do
      node = TPTree::TreeNode.new(:call_return, :test, nil, nil, 0, nil, nil, nil, nil, Time.now)
      expect(node.duration).to be_nil
    end

    it 'returns nil when end_time is missing' do
      node = TPTree::TreeNode.new(:call_return, :test, nil, nil, 0, nil, nil, nil, Time.now, nil)
      expect(node.duration).to be_nil
    end
  end

  describe '#to_hash' do
    it 'serializes all data correctly' do
      hash = simple_node.to_hash

      expect(hash[:event]).to eq(:call_return)
      expect(hash[:method_name]).to eq(:test_method)
      expect(hash[:parameters]).to be_an(Array)
      expect(hash[:return_value]).to eq('return_value')
      expect(hash[:depth]).to eq(1)
      expect(hash[:defined_class]).to eq('Object')
      expect(hash[:path]).to eq('/test/path.rb')
      expect(hash[:lineno]).to eq(42)
      expect(hash[:start_time]).to be_a(Float)
      expect(hash[:end_time]).to be_a(Float)
      expect(hash[:duration]).to be_a(Float)
    end

    it 'handles nil values gracefully' do
      node = TPTree::TreeNode.new(:call, :test, nil, nil, 0)
      hash = node.to_hash

      expect(hash[:parameters]).to be_nil
      expect(hash[:return_value]).to be_nil
      expect(hash[:defined_class]).to be_nil
      expect(hash[:path]).to be_nil
      expect(hash[:lineno]).to be_nil
      expect(hash[:start_time]).to be_nil
      expect(hash[:end_time]).to be_nil
      expect(hash[:duration]).to be_nil
    end

    it 'serializes complex parameter types' do
      complex_params = [
        [:req, :string_param, 'hello'],
        [:opt, :array_param, [1, 2, 3]],
        [:key, :hash_param, {key: 'value'}],
        [:rest, :splat_param, nil],
        [:block, :block_param, nil]
      ]

      node = TPTree::TreeNode.new(:call, :complex_method, complex_params, nil, 0)
      hash = node.to_hash

      expect(hash[:parameters]).to be_an(Array)
      expect(hash[:parameters].length).to eq(5)

      # Check parameter serialization
      param_names = hash[:parameters].map { |p| p[:name] }
      expect(param_names).to include(:string_param, :array_param, :hash_param, :splat_param, :block_param)
    end
  end

  describe '#to_s' do
    it 'formats call_return events correctly' do
      node = TPTree::TreeNode.new(
        :call_return, :test_method, [[:req, :param, 'value']], 'result', 0
      )

      output = node.to_s
      expect(output).to include('test_method')
      expect(output).to include('param = "value"')
      expect(output).to include('→')
      expect(output).to include('result')
    end

    it 'formats call events correctly' do
      node = TPTree::TreeNode.new(
        :call, :test_method, [[:req, :param, 'value']], nil, 1
      )

      output = node.to_s
      expect(output).to include('test_method')
      expect(output).to include('param = "value"')
      expect(output).not_to include('→')
    end

    it 'formats return events correctly' do
      node = TPTree::TreeNode.new(
        :return, :test_method, nil, 'result', 1
      )

      output = node.to_s
      expect(output).to include('result')
      expect(output).not_to include('test_method')
    end

    it 'includes depth-based prefixes' do
      shallow_node = TPTree::TreeNode.new(:call_return, :shallow, nil, nil, 0)
      deep_node = TPTree::TreeNode.new(:call_return, :deep, nil, nil, 2)

      shallow_output = shallow_node.to_s
      deep_output = deep_node.to_s

      # Deep node should have more indentation
      expect(deep_output.scan('│').length).to be > shallow_output.scan('│').length
    end

    it 'includes timing information when available' do
      start_time = Time.now - 0.001
      end_time = Time.now

      node = TPTree::TreeNode.new(
        :call_return, :timed_method, nil, nil, 0, nil, nil, nil,
        start_time, end_time
      )

      output = node.to_s
      expect(output).to match(/\[\d+\.\d+[μms]+\]/)
    end
  end

  describe '#to_parts' do
    it 'returns prefix parts and content separately' do
      node = TPTree::TreeNode.new(:call_return, :test, nil, nil, 1)

      prefix_parts, content = node.to_parts

      expect(prefix_parts).to be_an(Array)
      expect(content).to be_a(String)
      expect(content).to include('test')
    end

    it 'returns correct prefix parts for different depths' do
      deep_node = TPTree::TreeNode.new(:call_return, :deep, nil, nil, 3)

      prefix_parts, _ = deep_node.to_parts

      expect(prefix_parts.length).to eq(3) # Should have parts for each depth level
    end
  end

  describe 'parameter formatting' do
    it 'formats different parameter types correctly' do
      params = [
        [:req, :required_param, 'required_value'],
        [:opt, :optional_param, 'optional_value'],
        [:keyreq, :required_keyword, 'keyword_value'],
        [:key, :optional_keyword, nil],
        [:rest, :splat_args, nil],
        [:keyrest, :keyword_splat, nil],
        [:block, :block_param, nil]
      ]

      node = TPTree::TreeNode.new(:call, :complex_method, params, nil, 0)
      output = node.to_s

      expect(output).to include('required_param = "required_value"')
      expect(output).to include('optional_param = "optional_value"')
      expect(output).to include('required_keyword = "keyword_value"')
      expect(output).to include('optional_keyword:')
      expect(output).to include('*splat_args')
      expect(output).to include('**keyword_splat')
      expect(output).to include('&block_param')
    end
  end

  describe 'return value formatting' do
    it 'formats different return value types' do
      test_cases = [
        ['string', '"string"'],
        [42, '42'],
        [nil, 'nil'],
        [true, 'true'],
        [false, 'false'],
        [:symbol, ':symbol'],
        [[1, 2, 3], '[1, 2, 3]'],
        [{key: 'value'}, '{:key => "value"}']
      ]

      test_cases.each do |value, expected_format|
        node = TPTree::TreeNode.new(:call_return, :test, nil, value, 0)
        output = node.to_s
        expect(output).to include(expected_format)
      end
    end
  end
end