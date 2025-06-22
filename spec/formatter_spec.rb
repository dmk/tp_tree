# frozen_string_literal: true

require 'tp_tree'

# Test class to include the Formatter module
class TestFormatter
  include TPTree::Formatter
end

RSpec.describe TPTree::Formatter do
  let(:formatter) { TestFormatter.new }

  describe '#colorize' do
    it 'applies ANSI color codes' do
      result = formatter.colorize('test', :red)
      expect(result).to eq("\e[31mtest\e[0m")
    end

    it 'handles different colors' do
      colors = {
        black: 30, red: 31, green: 32, yellow: 33,
        blue: 34, magenta: 35, cyan: 36, white: 37
      }

      colors.each do |color, code|
        result = formatter.colorize('text', color)
        expect(result).to eq("\e[#{code}mtext\e[0m")
      end
    end

    it 'defaults to white for unknown colors' do
      result = formatter.colorize('test', :unknown)
      expect(result).to eq("\e[37mtest\e[0m")
    end
  end

  describe '#format_timing' do
    it 'returns empty string for nil duration' do
      expect(formatter.format_timing(nil)).to eq('')
    end

    it 'formats microseconds for very short durations' do
      result = formatter.format_timing(0.0005)
      expect(result).to include('500.0μs')
      expect(result).to include('[')
      expect(result).to include(']')
    end

    it 'formats milliseconds for short durations' do
      result = formatter.format_timing(0.5)
      expect(result).to include('500.0ms')
    end

    it 'formats seconds for long durations' do
      result = formatter.format_timing(2.5)
      expect(result).to include('2.5s')
    end

    it 'applies cyan color to timing info' do
      result = formatter.format_timing(0.001)
      expect(result).to include("\e[36m") # cyan color code
    end
  end

  describe '#format_parameters' do
    it 'returns empty string for nil parameters' do
      expect(formatter.format_parameters(nil)).to eq('')
    end

    it 'returns empty string for empty parameters' do
      expect(formatter.format_parameters([])).to eq('')
    end

    it 'formats required parameters' do
      params = [[:req, :param1, 'value1']]
      result = formatter.format_parameters(params)
      expect(result).to eq('param1 = "value1"')
    end

    it 'formats optional parameters' do
      params = [[:opt, :param1, 'default']]
      result = formatter.format_parameters(params)
      expect(result).to eq('param1 = "default"')
    end

    it 'formats required keyword parameters' do
      params = [[:keyreq, :keyword, 'value']]
      result = formatter.format_parameters(params)
      expect(result).to eq('keyword = "value"')
    end

    it 'formats optional keyword parameters with values' do
      params = [[:key, :keyword, 'value']]
      result = formatter.format_parameters(params)
      expect(result).to eq('keyword = "value"')
    end

    it 'formats optional keyword parameters without values' do
      params = [[:key, :keyword, nil]]
      result = formatter.format_parameters(params)
      expect(result).to eq('keyword:')
    end

    it 'formats rest parameters' do
      params = [[:rest, :args, nil]]
      result = formatter.format_parameters(params)
      expect(result).to eq('*args')
    end

    it 'formats keyrest parameters' do
      params = [[:keyrest, :kwargs, nil]]
      result = formatter.format_parameters(params)
      expect(result).to eq('**kwargs')
    end

    it 'formats block parameters' do
      params = [[:block, :block, nil]]
      result = formatter.format_parameters(params)
      expect(result).to eq('&block')
    end

    it 'formats unknown parameter types' do
      params = [[:unknown, :param, nil]]
      result = formatter.format_parameters(params)
      expect(result).to eq('param')
    end

    it 'formats multiple parameters' do
      params = [
        [:req, :param1, 'value1'],
        [:opt, :param2, 'value2'],
        [:key, :keyword, 'kwvalue']
      ]
      result = formatter.format_parameters(params)
      expect(result).to eq('param1 = "value1", param2 = "value2", keyword = "kwvalue"')
    end
  end

  describe '#format_value' do
    it 'formats strings with quotes' do
      expect(formatter.format_value('hello')).to eq('"hello"')
    end

    it 'formats symbols with colon prefix' do
      expect(formatter.format_value(:symbol)).to eq(':symbol')
    end

    it 'formats nil' do
      expect(formatter.format_value(nil)).to eq('nil')
    end

    it 'formats booleans' do
      expect(formatter.format_value(true)).to eq('true')
      expect(formatter.format_value(false)).to eq('false')
    end

    it 'formats numbers' do
      expect(formatter.format_value(42)).to eq('42')
      expect(formatter.format_value(3.14)).to eq('3.14')
    end

    it 'formats arrays' do
      expect(formatter.format_value([1, 2, 3])).to eq('[1, 2, 3]')
    end

    it 'formats nested arrays' do
      expect(formatter.format_value([1, [2, 3]])).to eq('[1, [2, 3]]')
    end

    it 'formats hashes' do
      result = formatter.format_value({a: 1, b: 2})
      expect(result).to eq('{:a => 1, :b => 2}')
    end

    it 'formats nested hashes' do
      result = formatter.format_value({outer: {inner: 'value'}})
      expect(result).to eq('{:outer => {:inner => "value"}}')
    end

    it 'formats Proc objects' do
      proc_obj = proc { "test" }
      expect(formatter.format_value(proc_obj)).to eq('Proc')
    end

    it 'formats other objects with inspect' do
      object = Object.new
      expect(formatter.format_value(object)).to eq(object.inspect)
    end
  end

  describe '#format_return_value' do
    it 'delegates to format_value' do
      expect(formatter.format_return_value('test')).to eq('"test"')
    end
  end

  describe '#color_for_depth' do
    it 'cycles through depth colors' do
      colors = TPTree::Formatter::DEPTH_COLORS

      colors.each_with_index do |color, depth|
        expect(formatter.color_for_depth(depth)).to eq(color)
      end
    end

    it 'cycles back to first color after exhausting all colors' do
      colors = TPTree::Formatter::DEPTH_COLORS
      overflow_depth = colors.length

      expect(formatter.color_for_depth(overflow_depth)).to eq(colors[0])
      expect(formatter.color_for_depth(overflow_depth + 1)).to eq(colors[1])
    end

    it 'handles negative depths gracefully' do
      # Ruby's modulo handles negative numbers correctly
      expect(formatter.color_for_depth(-1)).to eq(TPTree::Formatter::DEPTH_COLORS[-1])
    end
  end

  describe 'DEPTH_COLORS constant' do
    it 'contains expected colors' do
      expected_colors = [:green, :blue, :yellow, :magenta, :cyan, :red]
      expect(TPTree::Formatter::DEPTH_COLORS).to eq(expected_colors)
    end

    it 'is frozen' do
      expect(TPTree::Formatter::DEPTH_COLORS).to be_frozen
    end
  end
end