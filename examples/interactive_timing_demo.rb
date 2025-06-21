#!/usr/bin/env ruby

require_relative '../lib/tp_tree'

def recursive_fibonacci(n)
  return n if n <= 1
  sleep(0.001) # Small delay to make timing visible
  recursive_fibonacci(n - 1) + recursive_fibonacci(n - 2)
end

def optimized_fibonacci(n)
  return n if n <= 1
  sleep(0.001)

  a, b = 0, 1
  2.upto(n) do
    sleep(0.0001)
    a, b = b, a + b
  end
  b
end

puts "=== Interactive Method Timing Demo ==="
puts "This demo shows method execution times in interactive mode"
puts "Use arrow keys to navigate, Enter to expand/collapse, 'q' to quit"
puts "Press any key to start..."
gets

TPTree.catch(interactive: true) do
  puts "Computing fibonacci(5) recursively..."
  recursive_fibonacci(5)

  puts "Computing fibonacci(5) iteratively..."
  optimized_fibonacci(5)
end