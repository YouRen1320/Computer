# frozen_string_literal: true

# Deliberately prints only the argument boundary that Ruby received. The shell
# has already finished tokenization, quoting and glob expansion at this point.
puts "argc=#{ARGV.length}"
ARGV.each_with_index do |argument, index|
  puts "argv[#{index}]=#{argument.dump}"
end
