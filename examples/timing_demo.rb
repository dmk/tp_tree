#!/usr/bin/env ruby

require_relative '../lib/tp_tree'

def slow_method(n)
  sleep(0.1)
  fast_method(n)
end

def fast_method(n)
  sleep(0.01)
  n * 2
end

def complex_calculation(arr)
  sleep(0.05)
  arr.map { |x| slow_method(x) }.sum
end

puts "=== Method Timing Demo ==="
puts "This demo shows method execution times in the call tree"
puts

result = TPTree.catch do
  complex_calculation([1, 2, 3])
end

puts "\nDemo completed!"