# TpTree

A Ruby gem for visualizing method call traces with timing information. TPTree uses Ruby's TracePoint to capture method calls and presents them in a beautiful tree format with execution times, parameters, and return values.

## Features

- 🌳 **Tree visualization** of method calls with proper indentation
- ⏱️ **Timing information** for performance analysis
- 🎯 **Method filtering** to focus on specific methods or classes
- 📊 **JSON export** for integration with external tools
- 🎨 **Colorized output** for better readability
- 🔧 **Multiple output formats** (ANSI and XML)

## Installation

Install the gem by executing:

```bash
gem install tp_tree
```

Or add it to your Gemfile:

```ruby
gem 'tp_tree'
```

Then execute:

```bash
bundle install
```

## Usage

### Basic Usage

Wrap any code block with `TPTree.catch` to trace method calls:

```ruby
require 'tp_tree'

def slow_method(n)
  sleep(0.1)
  fast_method(n)
end

def fast_method(n)
  sleep(0.01)
  n * 2
end

TPTree.catch do
  slow_method(5)
end
```

Output:
```
slow_method(n = 5) [112.0ms]
│  fast_method(n = 5) → 10 [11.1ms]
└→ 10 [112.0ms]
```

### Method Filtering

Filter methods by name, class, or custom criteria:

```ruby
# Filter by method name (string or regex)
TPTree.catch(filter: 'slow_method') do
  # your code
end

# Filter by multiple criteria
TPTree.catch(filter: ['method1', /^User/, SomeClass]) do
  # your code
end

# Exclude specific methods
TPTree.catch(exclude: 'fast_method') do
  # your code
end

# Custom filtering with block
TPTree.catch(filter: ->(call_info) { call_info.method_name.start_with?('api_') }) do
  # your code
end
```

### JSON Export

Export trace data for external analysis:

```ruby
TPTree.catch(write_to: 'trace.json') do
  # your code
end
```

The JSON file contains structured data with timing, parameters, return values, and call hierarchy.

### Advanced Options

```ruby
TPTree.catch(
  filter: 'important_method',     # Method filtering
  exclude: 'noise_method',        # Method exclusion
  write_to: 'trace.json',         # JSON export
  interactive: true               # Interactive viewer (if available)
) do
  # your code
end
```

## Examples

See the `examples/` directory for complete demonstrations:

- `timing_demo.rb` - Basic timing visualization
- `interactive_timing_demo.rb` - Interactive viewer demo
- `semi_empty_nodes_demo.rb` - Complex filtering examples

Run them with:
```bash
ruby examples/timing_demo.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dmk/tp_tree. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/dmk/tp_tree/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TpTree project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/dmk/tp_tree/blob/main/CODE_OF_CONDUCT.md).
