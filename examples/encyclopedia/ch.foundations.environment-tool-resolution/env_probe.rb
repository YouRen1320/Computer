# frozen_string_literal: true

allowed = %w[DEMO_MARKER LOCAL_ONLY JAVA_HOME PATH].freeze
ARGV.each do |name|
  abort "unsupported environment key" unless allowed.include?(name)

  value = ENV.key?(name) ? ENV.fetch(name) : "<unset>"
  puts "#{name}=#{value}"
end
