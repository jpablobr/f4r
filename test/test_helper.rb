$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'stringio'

# Do not buffer output
$stdout.sync = true
$stderr.sync = true

F4R::Log.level = 8
F4R::Log.color = false

def name_value_fields(records, message_name)
  records.
    select {|r| r[:message_name] == message_name}.
    map { |m| m[:fields].inject({}) {|r,(k,v)| r[k] = v[:value];r } }
end

class StringIO
  # Returns the value that was written to the io
  def value
    rewind
    read
  end
end

module Kernel
  def must_equal_binary(expected)
    must_equal expected.dup.force_encoding(Encoding::BINARY)
  end
end
