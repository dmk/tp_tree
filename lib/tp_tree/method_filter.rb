# frozen_string_literal: true

module TPTree
  # MethodFilter handles filtering and excluding method calls based on various criteria
  class MethodFilter
    def initialize(filter: nil, exclude: nil)
      @filter_matchers = build_matchers(filter) if filter
      @exclude_matchers = build_matchers(exclude) if exclude
    end

    def should_include?(method_name, defined_class, tp)
      # If we have filters, method must match at least one filter
      if @filter_matchers && !@filter_matchers.empty?
        return false unless matches_any?(@filter_matchers, method_name, defined_class, tp)
      end

      # If we have excludes, method must not match any exclude
      if @exclude_matchers && !@exclude_matchers.empty?
        return false if matches_any?(@exclude_matchers, method_name, defined_class, tp)
      end

      true
    end

    private

    def build_matchers(criteria)
      case criteria
      when Array
        criteria.map { |item| build_single_matcher(item) }
      else
        [build_single_matcher(criteria)]
      end
    end

    def build_single_matcher(criterion)
      case criterion
      when String
        ->(method_name, defined_class, tp) { method_name.to_s == criterion }
      when Regexp
        ->(method_name, defined_class, tp) { criterion.match?(method_name.to_s) }
      when Proc
        criterion
      else
        raise ArgumentError, "Filter/exclude criteria must be String, Regexp, Array, or Proc"
      end
    end

    def matches_any?(matchers, method_name, defined_class, tp)
      matchers.any? { |matcher| matcher.call(method_name, defined_class, tp) }
    end
  end
end