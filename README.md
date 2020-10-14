# F4R

Simple Ruby library for encoding/decoding and editing [FIT (ANT+)](https://www.thisisant.com/developer/resources/downloads) binary files.

[Library Documentation](https://rdoc.info/github/jpablobr/f4r)

## Features

- Decoded data stored in plain Ruby objects.

- Decoded data stored with (as much as possible) meta-data from the FIT file and from the binary definitions (e.i., the data from the specific file's activity and the one from its associated FIT SDK profile data).

- Decoded data stored in its original state as much as possible. This means that the data will not get converted or scaled, also meaning that sub-fields will not get "expanded" or converted into the values they are supposed to represent (according to the FIT SDK), this needs to happen at the specific app level where F4R will be used.

- Encoder allows to build FIT binary files from scratch and also from a source/template FIT file to serve as a reference to help preserve/replicate a specific binary structure. This is important given that sometimes, even if the resulting FIT file is valid, it might not be for specific parsers such as Garmin/TrainingPeaks, etc... So preserving the structure, size or meta-data might be important in certain scenarios.

## F4R-CLI

F4R-CLI is a command line tool to help with the interpretation (conversion, scaling, editing, import/export) of the decoded/encoded FIT files. As F4R's main aim is to be (and stay) as simple and minimal as possible, it might not be enough for getting usable human readable (or interpretable) data, so F4R-CLI is meant to help with that and also as an example for other apps.

https://github.com/jpablobr/f4r-cli

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'f4r'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install f4r

## Instant gratification

```ruby
>> require 'f4r'
>> records = F4R::decode(path_to_fit_file).records
>> laps = records.select { |r| r[:message_name] == :lap }
>> laps.last[:fields][:max_heart_rate]
=> {:value=>180,
   :index => 21,
   :base_type=>:uint8,
   :message_name=>"lap",
   :message_number=>19,
   :source => "FIT SDK 2.1",
   :properties=>
   {:field_def=>16,
     :field_name=>"max_heart_rate",
     :field_type=>"uint8",
     :array=>nil,
     :components=>nil,
     :scale=>nil,
     :offset=>nil,
     :units=>"bpm",
     :bits=>nil,
     :accumulate=>nil,
     :ref_field_name=>nil,
     :ref_field_value=>nil,
     :comment=>nil,
     :products=>nil,
     :example=>"1"}}
```

## Usage

### Logging

F4R has 3 built-in loggers that you can override. By default, the main logger logs to STDOUT and the other two (decode and encode loggers) log to `/tmp/` but can be replaced by any Logger class.

```ruby
F4R::Log.logger = Logger.new('/tmp/f4r.log')
F4R::Log.encode_logger = F4R::Logger.new($stdout)
F4R::Log.decode_logger = F4R::Logger.new($stdout)
```
#### Colour output

Colour output can be enabled or disabled.

```ruby
F4R::Log.color = true
```

#### Severity level

Severity level can be enabled or disabled.

```ruby
F4R::Log.level = :info # :error, etc...

# Logger severity Level 8+ take precedence
# over all the rest silencing them.
# F4R::Log.level = 8
```

### Config Directory

By default F4R reads all FIT configuration files (FIT SDK Profile messages and types) from the `config` directory. This directory also provides **guessed** messages and types (`undocumented_messages.csv` and `undocumented_types.csv`) to help with the encoding/decoding process. If a `~/.f4r` directory exists F4R will read from this directory but the directory can be replaced via the `Config` class.

```ruby
F4R::Config.directory = '~/my-f4r'
```

This is mostly to allow for modification of the undocumented messages and types easier.

### Encoding

```ruby
require 'f4r'

# Records with minimum required data.
# (Similar to required data in the FitCSVTool.jar from the FIT SDK)
records = [
  {
    message_name: :file_id,
    local_message_number: 0,
    fields: {
      serial_number: {value: 123456789},
      type: {value: 4},
      manufacturer: {value: 1}}},
  {
    message_name: :device_info,
    local_message_number: 1,
    fields: {
      timestamp: {value: 939346537},
      source_type: {value: 1},
      device_index: {value: 0},
      manufacturer: {value: 1},
      serial_number: {value: 123456789},
      undocumented_field_29: {value: [0, 1, 2, 3, 4, 5]}}
  }
  ...
]

F4R::encode(file_name, records) #=> file_name

# Optionally, the third argument `source` file can be passed as well.
# It will be used as a binary structure reference.

F4R::encode(file_name, records, source_fit_file) #=> file_name
```

### Decoding

```ruby
F4R::decode(path_to_fit_file).records #=> Array of record Hashes
```

## TODO

- Documentation.
- Support for FIT Developer Data fields.
- Support for FIT Compressed Timestamp headers.
- Move logging to separate gem.

(PRs welcome!)

## Reporting Bugs and Requesting Features

Please use the issues section to report bugs and request features. This section is also used as the TODO area for the F4R gem.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jpablobr/f4r.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
 
