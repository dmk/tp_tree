# frozen_string_literal: true

require 'tp_tree'

RSpec.describe TPTree::MethodFilter do
  describe '#should_include?' do
    let(:method_name) { :test_method }
    let(:defined_class) { Object }
    let(:tp) { double('TracePoint') }

    context 'with no filters' do
      let(:filter) { TPTree::MethodFilter.new }

      it 'includes all methods' do
        expect(filter.should_include?(method_name, defined_class, tp)).to be true
      end
    end

    context 'with string filter' do
      let(:filter) { TPTree::MethodFilter.new(filter: 'test_method') }

      it 'includes matching methods' do
        expect(filter.should_include?(:test_method, defined_class, tp)).to be true
      end

      it 'excludes non-matching methods' do
        expect(filter.should_include?(:other_method, defined_class, tp)).to be false
      end
    end

    context 'with regexp filter' do
      let(:filter) { TPTree::MethodFilter.new(filter: /^test_/) }

      it 'includes matching methods' do
        expect(filter.should_include?(:test_method, defined_class, tp)).to be true
        expect(filter.should_include?(:test_other, defined_class, tp)).to be true
      end

      it 'excludes non-matching methods' do
        expect(filter.should_include?(:other_method, defined_class, tp)).to be false
      end
    end

    context 'with array filter' do
      let(:filter) { TPTree::MethodFilter.new(filter: ['test_method', /^other_/]) }

      it 'includes methods matching any criteria' do
        expect(filter.should_include?(:test_method, defined_class, tp)).to be true
        expect(filter.should_include?(:other_method, defined_class, tp)).to be true
      end

      it 'excludes methods not matching any criteria' do
        expect(filter.should_include?(:unrelated_method, defined_class, tp)).to be false
      end
    end

    context 'with block filter' do
      let(:filter) { TPTree::MethodFilter.new(filter: ->(name, klass, tp) { name.to_s.length > 5 }) }

      it 'includes methods passing the block condition' do
        expect(filter.should_include?(:very_long_method_name, defined_class, tp)).to be true
      end

      it 'excludes methods not passing the block condition' do
        expect(filter.should_include?(:short, defined_class, tp)).to be false
      end
    end

    context 'with string exclude' do
      let(:filter) { TPTree::MethodFilter.new(exclude: 'test_method') }

      it 'excludes matching methods' do
        expect(filter.should_include?(:test_method, defined_class, tp)).to be false
      end

      it 'includes non-matching methods' do
        expect(filter.should_include?(:other_method, defined_class, tp)).to be true
      end
    end

    context 'with both filter and exclude' do
      let(:filter) { TPTree::MethodFilter.new(filter: /^test_/, exclude: 'test_excluded') }

      it 'includes methods that match filter and do not match exclude' do
        expect(filter.should_include?(:test_method, defined_class, tp)).to be true
      end

      it 'excludes methods that match exclude even if they match filter' do
        expect(filter.should_include?(:test_excluded, defined_class, tp)).to be false
      end

      it 'excludes methods that do not match filter' do
        expect(filter.should_include?(:other_method, defined_class, tp)).to be false
      end
    end

    context 'with invalid filter type' do
      it 'raises ArgumentError' do
        expect { TPTree::MethodFilter.new(filter: 123) }.to raise_error(ArgumentError)
      end
    end
  end
end