# frozen_string_literal: true

require 'stringio'

RSpec.describe TPTree do
  it "has a version number" do
    expect(TPTree::VERSION).not_to be nil
  end

  describe '.catch' do
    it 'captures and prints the call tree' do
      original_stdout = $stdout
      $stdout = StringIO.new

      def method_a
        method_b(5)
        method_c
      end

      def method_b(x)
        x * 2
      end

      def method_c; end

      TPTree.catch do
        method_a
      end

      output = $stdout.string
      $stdout = original_stdout

      # This is the expected output, without color.
      # The structure should be a call to method_a, which contains call_returns for b and c,
      # and then the return for a.
      expected_output = <<~OUTPUT
        method_a()
        │  method_b(x = 5) → 10
        │  method_c() → nil
        └→ nil
      OUTPUT

      uncolored_output = output.gsub(/\e\[\d+m/, '')

      # Normalize line endings and remove trailing whitespace
      cleaned_output = uncolored_output.lines.map(&:rstrip).join("\n")
      cleaned_expected_output = expected_output.lines.map(&:rstrip).join("\n")

      expect(cleaned_output).to eq(cleaned_expected_output)
    end

    context 'with filtering' do
      before do
        def method_a
          method_b(5)
          method_c
          method_d
        end

        def method_b(x)
          x * 2
        end

        def method_c; end
        def method_d; end
      end

      it 'filters methods with string filter' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(filter: 'method_b') do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_b(x = 5) → 10')
        expect(uncolored_output).not_to include('method_c')
        expect(uncolored_output).not_to include('method_d')
      end

      it 'excludes methods with string exclude' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(exclude: 'method_c') do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_a')
        expect(uncolored_output).to include('method_b')
        expect(uncolored_output).not_to include('method_c')
        expect(uncolored_output).to include('method_d')
      end

      it 'filters methods with regexp' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(filter: /method_[bc]/) do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_b')
        expect(uncolored_output).to include('method_c')
        expect(uncolored_output).not_to include('method_a')
        expect(uncolored_output).not_to include('method_d')
      end

      it 'filters methods with array of criteria' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(filter: ['method_b', /method_d/]) do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_b')
        expect(uncolored_output).to include('method_d')
        expect(uncolored_output).not_to include('method_a')
        expect(uncolored_output).not_to include('method_c')
      end

      it 'filters methods with block' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(filter: ->(name, klass, tp) { name.to_s.end_with?('_c') }) do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_c')
        expect(uncolored_output).not_to include('method_a')
        expect(uncolored_output).not_to include('method_b')
        expect(uncolored_output).not_to include('method_d')
      end

      it 'combines filter and exclude' do
        original_stdout = $stdout
        $stdout = StringIO.new

        TPTree.catch(filter: /method_/, exclude: 'method_c') do
          method_a
        end

        output = $stdout.string
        $stdout = original_stdout
        uncolored_output = output.gsub(/\e\[\d+m/, '')

        expect(uncolored_output).to include('method_a')
        expect(uncolored_output).to include('method_b')
        expect(uncolored_output).not_to include('method_c')
        expect(uncolored_output).to include('method_d')
      end
    end
  end
end