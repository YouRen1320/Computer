# frozen_string_literal: true

puts "argc=#{ARGV.length}"
ARGV.each_with_index { |argument, index| puts "argv[#{index}]=#{argument.dump}" }
