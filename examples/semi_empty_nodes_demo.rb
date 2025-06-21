#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/tp_tree'

# Example methods to demonstrate semi-empty nodes
class Demo
  def public_method
    private_helper_method("hello")
  end

  private

  def private_helper_method(message)
    internal_processing(message)
  end

  def internal_processing(data)
    final_operation(data.upcase)
  end

  def final_operation(processed_data)
    "Result: #{processed_data}"
  end
end

puts "=== Without filtering (full call tree) ==="
TPTree.catch do
  demo = Demo.new
  result = demo.public_method
  puts "Final: #{result}"
end

puts "\n=== With filtering (semi-empty nodes for filtered methods) ==="
puts "Filtering out private helper methods but keeping them visible"
TPTree.catch(exclude: [/private_helper_method/, /internal_processing/]) do
  demo = Demo.new
  result = demo.public_method
  puts "Final: #{result}"
end

puts "\n=== Heavy filtering (multiple methods filtered) ==="
TPTree.catch(exclude: [/helper/, /processing/, /operation/]) do
  demo = Demo.new
  result = demo.public_method
  puts "Final: #{result}"
end