# frozen_string_literal: true

require 'tp_tree'
require_relative '../lib/tp_tree/formatters/xml_formatter'

# Also need the regular formatter for comparison tests
class TestFormatter
  include TPTree::Formatter
end

RSpec.describe TPTree::Formatters::XmlFormatter do
  let(:formatter) { TPTree::Formatters::XmlFormatter.new }

  describe '#colorize' do
    it 'wraps text in XML tags' do
      result = formatter.colorize('test', :red)
      expect(result).to eq('<red>test</red>')
    end

    it 'handles different colors as XML tags' do
      colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

      colors.each do |color|
        result = formatter.colorize('text', color)
        expect(result).to eq("<#{color}>text</#{color}>")
      end
    end
  end

  describe '#format_timing' do
    it 'returns empty string for nil duration' do
      expect(formatter.format_timing(nil)).to eq('')
    end

    it 'formats microseconds for very short durations' do
      result = formatter.format_timing(0.0005)
      expect(result).to include('500.0μs')
      expect(result).to include('<cyan>')
      expect(result).to include('</cyan>')
    end

    it 'formats milliseconds for short durations' do
      result = formatter.format_timing(0.5)
      expect(result).to include('500.0ms')
      expect(result).to include('<cyan>')
      expect(result).to include('</cyan>')
    end

    it 'formats seconds for long durations' do
      result = formatter.format_timing(2.5)
      expect(result).to include('2.5s')
      expect(result).to include('<cyan>')
      expect(result).to include('</cyan>')
    end

    it 'wraps timing info in XML cyan tags' do
      result = formatter.format_timing(0.001)
      expect(result).to eq('<cyan> [1.0ms]</cyan>')
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

    it 'formats hashes' do
      result = formatter.format_value({a: 1, b: 2})
      expect(result).to eq('{:a => 1, :b => 2}')
    end

    it 'formats Proc objects' do
      proc_obj = proc { "test" }
      expect(formatter.format_value(proc_obj)).to eq('Proc')
    end
  end

  describe '#format_return_value' do
    it 'delegates to format_value' do
      expect(formatter.format_return_value('test')).to eq('"test"')
    end
  end

  describe '#color_for_depth' do
    it 'cycles through depth colors' do
      colors = TPTree::Formatters::BaseFormatter::DEPTH_COLORS

      colors.each_with_index do |color, depth|
        expect(formatter.color_for_depth(depth)).to eq(color)
      end
    end

    it 'cycles back to first color after exhausting all colors' do
      colors = TPTree::Formatters::BaseFormatter::DEPTH_COLORS
      overflow_depth = colors.length

      expect(formatter.color_for_depth(overflow_depth)).to eq(colors[0])
      expect(formatter.color_for_depth(overflow_depth + 1)).to eq(colors[1])
    end
  end

  describe 'DEPTH_COLORS constant' do
    it 'contains expected colors' do
      expected_colors = [:green, :blue, :yellow, :magenta, :cyan, :red]
      expect(TPTree::Formatters::BaseFormatter::DEPTH_COLORS).to eq(expected_colors)
    end

    it 'is frozen' do
      expect(TPTree::Formatters::BaseFormatter::DEPTH_COLORS).to be_frozen
    end
  end

  describe 'comparison with regular Formatter' do
    let(:regular_formatter) { TestFormatter.new }

    it 'produces different colorization output' do
      xml_result = formatter.colorize('test', :red)
      ansi_result = regular_formatter.colorize('test', :red)

      expect(xml_result).to eq('<red>test</red>')
      expect(ansi_result).to eq("\e[31mtest\e[0m")
      expect(xml_result).not_to eq(ansi_result)
    end

    it 'produces same parameter formatting' do
      params = [[:req, :param, 'value']]

      xml_result = formatter.format_parameters(params)
      ansi_result = regular_formatter.format_parameters(params)

      expect(xml_result).to eq(ansi_result)
    end

    it 'produces same value formatting' do
      test_values = ['string', :symbol, 42, nil, true, [1, 2], {a: 'b'}]

      test_values.each do |value|
        xml_result = formatter.format_value(value)
        ansi_result = regular_formatter.format_value(value)

        expect(xml_result).to eq(ansi_result)
      end
    end
  end
end