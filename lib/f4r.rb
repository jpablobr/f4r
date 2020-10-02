require 'csv'
require 'bindata'
require 'logger'
require 'singleton'

module F4R

  VERSION = '0.1.0'

  ##
  # Fit Profile revision for the messages and types in the {Config.directory}.

  FIT_PROFILE_REV = '2.3'

  ##
  # Class for application wide configurations.

  class Config

    class << self

      ##
      # Directory for all FIT Profile (defined and undefined) definitions.
      #
      # @return [File] @@directory

      def directory
        @@directory ||= get_directory
      end

      ##
      # @param [File] dir

      def directory=(dir)
        @@directory = dir
      end

      private

      ##
      # Directory for all message and type definitions.
      #
      # @return [File] directory

      def get_directory
        local_dir = File.expand_path('~/.f4r')
        if File.directory?(local_dir)
          local_dir
        else
          File.expand_path('../config', __dir__)
        end
      end

    end

  end

  ##
  # Exception for all F4R errors.

  class Error < StandardError ; end

  ##
  # Open ::Logger to add ENCODE and DECODE (debugging) log levels.

  class Logger < ::Logger

    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY ENCODE DECODE)

    def format_severity(severity)
      SEV_LABEL[severity] || 'ANY'
    end

    def encode(progname = nil, &block)
      add(6, nil, progname, &block)
    end

    def decode(progname = nil, &block)
      add(7, nil, progname, &block)
    end

  end

  ##
  # Singleton to provide a common logging mechanism for all objects. It
  # exposes essentially the same interface as the Logger class but just as a
  # singleton and with some additional methods like 'debug', 'warn', 'info'.
  #
  # It also facilitates configurable log output redirection based on severity
  # levels to help reduce noise in the different output devices.

  class F4RLogger

    include Singleton

    ##
    # @example
    #   F4R::Log.logger = F4R::Logger.new($stdout)
    #
    # @param [Logger] logger
    # @return [Logger] +@logger+

    def logger=(logger)
      log_formater(logger) && @logger = logger
    end

    ##
    # @example
    #   F4R::Log.encode_logger = F4R::Logger.new($stdout)
    #
    # @param [Logger] logger
    # @return [Logger] +@encode_logger+

    def encode_logger=(logger)
      log_formater(logger) && @encode_logger = logger
    end

    ##
    # @example
    #   F4R::Log.decode_logger = F4R::Logger.new($stdout)
    #
    # @param [Logger] logger
    # @return [Logger] +@decode_logger+

    def decode_logger=(logger)
      log_formater(logger) && @decode_logger = logger
    end

    ##
    # @return [Logger] +@logger+

    def logger
      @logger ||= Logger.new($stdout)
    end

    ##
    # @return [Logger] +@encode_logger+

    def encode_logger
      @encode_logger ||= Logger.new('/tmp/f4r-encode.log')
    end

    ##
    # @return [Logger] +@decode_logger+

    def decode_logger
      @decode_logger ||= Logger.new('/tmp/f4r-decode.log')
    end

    ##
    # Method for setting the severity level for all loggers.
    #
    # @example
    #   F4R::Log.level = :error
    #
    # @param [Symbol, String, Integer] level

    def level=(level)
      [
        logger,
        decode_logger,
        encode_logger
      ].each { |lgr| lgr.level = level}
    end

    ##
    # Severity level for all [F4RLogger] loggers.
    #
    # @return [Symbol, String, Integer] @@level

    def level
      @level ||= :error
    end

    ##
    # Allow other programs to enable or disable colour output.
    #
    # @example
    #   F4R::Log.color = true
    #
    # @param [Boolean] bool

    def color=(bool)
      @color = bool
    end

    ##
    # When set to True enables logger colour output.
    #
    # @return [Boolean] +@color+

    def color?
      @color ||= false
    end

    ##
    # DEBUG level messages.
    #
    # @param [String, Array<String>] msg
    #
    #   Mostly used to locate or describe items in the +items+ parameter.
    #
    #   String: Simple text message.
    #
    #   Array<String>: List of key words to be concatenated with a '#' inside
    #   '<>' (see: {format_message}). Meant to be used for describing the class
    #   and method where the log message was called from.
    #
    #     Example:
    #       >> ['F4R::Record', 'fields'] #=> '<F4R::Record#fields>'
    #
    # @param [Hash] items
    #
    #   Key/Value list of items for debugging.
    #
    # @yield [block] passed directly to the [F4RLogger] logger.
    # @return [String] formatted message.
    #
    # Example:
    #   >> Log.debug [self.class, __method__], {a:1, b:2}
    #   => DEBUG  <F4R::Record#fields> a: 1 b: 2

    def debug(msg = '', items = {},  &block)
      logger.debug(format_message(msg, items), &block)
    end

    ##
    # INFO level messages.
    #
    # @param [String] msg passed directly to the [F4RLogger] logger
    # @yield [block] passed directly to the [F4RLogger] logger
    # @return [String] formatted message

    def info(msg, &block)
      logger.info(msg, &block)
    end

    ##
    # WARN level messages.
    #
    # @param [String] msg
    #
    #   Passed directly to the [F4RLogger] logger after removing all newlines.
    #
    # @yield [block] passed directly to the [F4RLogger] logger
    # @return [String] formatted message

    def warn(msg, &block)
      logger.warn(msg.gsub(/\n/, ' '), &block)
    end

    ##
    # ERROR level messages.
    #
    # Raises [F4R::ERROR].
    #
    # @param [String] msg Passed directly to the [F4RLogger] logger.
    # @yield [block] passed directly to the [F4RLogger] logger.
    # @raise [F4R::Error] with formatted message.

    def error(msg, &block)
      logger.error(msg, &block)
      raise Error, msg
    end

    ##
    # ENCODE level messages.
    #
    # Similar to {debug} but with its specific [F4RLogger] logger
    #
    # @param [String, Array<String>] msg
    # @param [Hash] items
    # @yield [block] passed directly to the [F4RLogger] logger
    # @return [String] formatted message

    def encode(msg, items = {}, &block)
      decode_logger.encode(format_message(msg, items), &block)
    end

    ##
    # DECODE level messages.
    #
    # Similar to {debug} but with its specific [F4RLogger] logger.
    #
    # @param [String, Array<String>] msg
    # @param [Hash] items
    # @yield [block] passed directly to the [F4RLogger] logger
    # @return [String] formatted message

    def decode(msg, items = {}, &block)
      decode_logger.decode(format_message(msg, items), &block)
    end

    ##
    # Simple colour codes mapping.
    #
    # @param [Symbol] clr to define colour code to use
    # @param [String] text to be coloured
    # @return [String] text with the proper colour code

    def tint(clr, text)
      codes = {
        none: 0, bright: 1, black: 30, red: 31,
        green: 32, yellow: 33, blue: 34,
        magenta: 35, cyan: 36, white: 37, default: 39,
      }
      ["\x1B[", codes[clr].to_s, 'm', text.to_s, "\x1B[0m"].join
    end

    ##
    # Formats message and items for the [F4RLogger] logger output.
    # It also adds colour when {color?} has been set to +true+.
    #
    # @param [String, Array<String, Object>] msg
    # @param [Hash] items
    # @return [String] formatted message

    def format_message(msg, items)
      if msg.is_a?(Array)
        if Log.color?
          msg =  Log.tint(:blue, "<#{msg.join('#')}>")
        else
          msg = "<#{msg.join('#')}>"
        end
      end

      items.each do |k, v|
        k = Log.color? ? Log.tint(:green, k.to_s): k.to_s
        msg += " #{k}: #{v.to_s}"
      end
      msg
    end

    ##
    # Logger formatter configuration

    def log_formater(logger)
      logger.formatter = proc do |severity, _, _, msg|

        if Log.color?
          sc = {
            'DEBUG' => :magenta,
            'INFO' => :blue,
            'WARN' => :yellow,
            'ERROR' => :red,
            'ENCODE' => :green,
            'DECODE' => :cyan,
          }
          Log.tint(sc[severity], "#{'%-6s' % severity} ") + "#{msg}\n"
        else
          severity + " #{msg}\n"
        end

      end
    end

  end

  ##
  # Single F4RLogger instance

  Log = F4RLogger.instance

  ##
  # Provides the FIT SDK global definition for all objects. Sometimes more
  # information is needed in order to be able to decode FIT files so definitions
  # for these undocumented messages and types (based on guesses ) is also
  # provided.

  module GlobalFit

    ##
    # Collection of defined (FIT SDK) and undefined (F4R) messages.
    #
    # Message fields without +field_def+ (e.i., field's number/id within the
    # message) which usually mean that they are either sub-fields or not
    # defined properly (e.i., invalid) get filtered out. Results come from
    # {Helper#get_messages}.
    #
    # @example GlobalFit.messages
    #   [
    #     {
    #       :name=>"file_id",
    #       :number=>0,
    #       :fields=> [...]
    #     },
    #     {
    #       :name=>"file_creator",
    #       :number=>49,
    #       :fields=> [...]
    #     }
    #     ...
    #   ]
    #
    # @return [Array<Hash>] of FIT messages

    def self.messages
      @@messages ||= Helper.new.get_messages.freeze
    end

    ##
    # Collection of defined (FIT SDK) and undefined (F4R) types.
    # Results come from {Helper#get_types}.
    #
    # @example GlobalFit.types
    #   {
    #     file:
    #     {
    #       base_type: :enum,
    #       values: [
    #         {value_name: "device",
    #         value: 1,
    #         comment: "Read only, single file. Must be in root directory."},
    #         {
    #           value_name: "settings",
    #           value: 2,
    #           comment: "Read/write, single file. Directory=Settings"},
    #         ...
    #       ]
    #     },
    #     tissue_model_type:
    #     {
    #       base_type: :enum,
    #       values: [
    #         {
    #           value_name: "zhl_16c",
    #           value: 0,
    #           comment: "Buhlmann's decompression algorithm, version C"}]},
    #     ...
    #   }
    #
    # @return [Hash] Fit Profile types.

    def self.types
      @@types ||= Helper.new.get_types.freeze
    end

    ##
    # Type definitions provide a FIT to F4R (BinData) type conversion table.
    #
    # @return [Array<Hash>] data types.

    def self.base_types
      @@base_types ||= Helper.new.get_base_types.freeze
    end

    ##
    # Helper class to get all types and messages in a usable format for F4R.

    class Helper

      ##
      # Provides messages to {GlobalFit.messages}.
      #
      # @return [Array<Hash>]

      def get_messages
        messages = {}

        profile_messages.keys.each do |name|
          messages[name] = []
          if undocumented_messages[name]
            messages[name] = profile_messages[name] | undocumented_messages[name]
          else
            messages[name] = profile_messages[name]
          end
        end

        (undocumented_messages.keys - messages.keys).each do |name|
          messages[name] = undocumented_messages[name]
        end

        messages.keys.inject([]) do |r, name|
          type = GlobalFit.types[:mesg_num][:values].find { |v| v[:value_name] == name }
          source = undocumented_types[:mesg_num][:values].
            find { |t| t[:value_name] == name }

          unless type
            Log.error <<~ERROR
              Message "#{name}" not found in FIT profile or undocumented messages types.
            ERROR
          end

          r << {
            name: name,
            number: type[:value].to_i,
            source: source ? "F4R #{VERSION}" : "FIT SDK #{FIT_PROFILE_REV}",
            fields: messages[name.to_sym].select { |f| f[:field_def] }
          };r
        end
      end

      ##
      # Provides types to {GlobalFit.types}.
      #
      # @return [Hash]

      def get_types
        types = {}

        profile_types.keys.each do |name|
          types[name] = {}
          if undocumented_types[name]
            values = profile_types[name][:values] | undocumented_types[name][:values]
            types[name][:values] = values
          else
            types[name] = profile_types[name]
          end
        end

        types
      end

      ##
      # Provides base types to {GlobalFit.base_types}.
      #
      # @return [Hash]

      def get_base_types
        csv = CSV.read(Config.directory + '/base_types.csv', converters: %i[numeric])
        csv[1..-1].inject([]) do |r, row|
          r << {
            number: row[0],
            fit: row[1].to_sym,
            bindata: row[2].to_sym,
            bindata_en: row[3].to_sym,
            endian: row[4],
            bytes: row[5],
            undef: row[6],
          };r
        end
      end

      private

      ##
      # Provides FIT SDK messages to {GlobalFit.messages}.
      #
      # @return [Hash]

      def profile_messages
        @profile_messages ||= messages_csv_to_hash(
        CSV.read(
          Config.directory + '/profile_messages.csv',
          converters: %i[numeric]),
         "FIT SDK #{FIT_PROFILE_REV}")
      end

      ##
      # Provides undocumented messages to {GlobalFit.messages}.
      #
      # @return [Hash]

      def undocumented_messages
       @undocumented_messages ||= messages_csv_to_hash(
        CSV.read(
          Config.directory + '/undocumented_messages.csv',
          converters: %i[numeric]),
         "F4R #{VERSION}")
      end

      ##
      # Provides FIT SDK types to {GlobalFit.types}.
      #
      # @return [Hash]

      def profile_types
        @profile_types ||= types_csv_to_hash(
        CSV.read(
          Config.directory + '/profile_types.csv',
          converters: %i[numeric]),
         "FIT SDK #{FIT_PROFILE_REV}")
      end

      ##
      # Provides undocumented types to {GlobalFit.types}.
      #
      # @return [Hash]

      def undocumented_types
        @undocumented_types ||= types_csv_to_hash(
        CSV.read(
          Config.directory + '/undocumented_types.csv',
          converters: %i[numeric]),
          "F4R #{VERSION}")
      end

      ##
      # Converts CSV messages into a Hash.
      #
      # @return [Hash]

      def messages_csv_to_hash(csv, source)
        current_message = ''
        csv[2..-1].inject({}) do |r, row|
          if row[0].is_a? String
            current_message = row[0].to_sym
            r[current_message] = []
          else
            if row[1] && row[2]
              r[current_message] << {
                source: source,
                field_def: row[1],
                field_name: row[2].to_sym,
                field_type: row[3].to_sym,
                array: row[4],
                components: row[5],
                scale: row[6],
                offset: row[7],
                units: row[8],
                bits: row[9],
                accumulate: row[10],
                ref_field_name: row[11],
                ref_field_value: row[12],
                comment: row[13],
                products: row[14],
                example: row[15]
              }
            end
          end
          r
        end
      end

      ##
      # Converts CSV types into a Hash.
      #
      # @return [Hash]

      def types_csv_to_hash(csv, source)
        current_type = ''
        csv[1..-1].inject({}) do |r, row|
          if row[0].is_a? String
            current_type = row[0].to_sym
            r[current_type] = {
              base_type: row[1].to_sym,
              values: []
            }
          else
            unless row.compact.size.zero?
              r[current_type][:values] << {
                source: source,
                value_name: row[2].to_sym,
                value: row[3],
                comment: row[4]
              }
            end
          end
          r
        end
      end

    end

  end

  ##
  # See CRC section in the FIT SDK for more info and CRC16 examples.

  class CRC16

    ##
    # CRC16 table

    @@table = [
      0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
      0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400
    ].freeze

    ##
    # Compute checksum over given IO.
    #
    # @param [IO] io
    #
    # @return [crc] crc
    #   Checksum of lower and upper four bits for all bytes in IO

    def self.crc(io)
      crc = 0
      io.each_byte do |byte|
        [byte, (byte >> 4)].each do |sb|
          crc = ((crc >> 4) & 0x0FFF) ^ @@table[(crc ^ sb) & 0xF]
        end
      end
      crc
    end
  end

  ##
  # BinData definitions for the supported FIT data structures.
  #
  #   module Definition
  #     class Header
  #     class RecordHeader
  #     class RecordField
  #     class Record

  module Definition

    ##
    # Main header for FIT files.
    #
    #   | Byte | Parameter           | Description             | Size (Bytes) |
    #   |------+---------------------+-------------------------+--------------|
    #   |    0 | Header Size         | Length of file header   |            1 |
    #   |    1 | Protocol Version    | Provided by SDK         |            1 |
    #   |    2 | Profile Version LSB | Provided by SDK         |            2 |
    #   |    3 | Profile Version MSB | Provided by SDK         |              |
    #   |    4 | Data Size LSB       | Length of data records  |            4 |
    #   |    5 | Data Size           | Minus header or CRC     |              |
    #   |    6 | Data Size           |                         |              |
    #   |    7 | Data Size MSB       |                         |              |
    #   |    8 | Data Type Byte [0]  | ASCII values for ".FIT" |            4 |
    #   |    9 | Data Type Byte [1]  |                         |              |
    #   |   10 | Data Type Byte [2]  |                         |              |
    #   |   11 | Data Type Byte [3]  |                         |              |
    #   |   12 | CRC LSB             | CRC                     |            2 |
    #   |   13 | CRC MSB             |                         |              |

    class Header < BinData::Record

      endian :little
      uint8 :header_size, initial_value: 14
      uint8 :protocol_version, initial_value: 16
      uint16 :profile_version, initial_value: 2093
      uint32 :data_size, initial_value: 0
      string :data_type, read_length: 4, initial_value: '.FIT'
      uint16 :crc, initial_value: 0

      ##
      # Data validation should happen as soon as possible.
      #
      # @param [IO] io

      def read(io)
        super

        case
        when !supported_header?
          Log.error  "Unsupported header size: #{header_size.snapshot}."
        when data_type.snapshot != '.FIT'
          Log.error "Unknown file type: #{data_type.snapshot}."
        end

        crc_mismatch?(io)

        Log.decode [self.class, __method__], to_log_s
      end

      ##
      # Write header and its CRC to IO
      #
      # @param [IO] io

      def write(io)
        super
        io.rewind
        crc_16 = CRC16.crc(io.read(header_size.snapshot - 2))
        BinData::Uint16le.new(crc_16).write(io)

        Log.encode [self.class, __method__], to_log_s
      end

      ##
      # @return [Boolean]

      def supported_header?
        [12, 14].include? header_size.snapshot
      end

      ##
      # CRC validations
      #
      # @param [IO] io
      # @return [Boolean]

      def crc_mismatch?(io)
        unless crc.snapshot.zero?
          io.rewind
          crc_16 = CRC16.crc(io.read(header_size.snapshot - 2))
          unless crc_16 == crc.snapshot
            Log.error "CRC mismatch: Computed #{crc_16} instead of #{crc.snapshot}."
          end
        end

        start_pos = header_size.snapshot == 14 ? header_size : 0

        crc_16 = CRC16.crc(IO.binread(io, file_size, start_pos))
        crc_ref = io.readbyte.to_i | (io.readbyte.to_i << 8)

        unless crc_16 = crc_ref
          Log.error "crc mismatch: computed #{crc_16} instead of #{crc_ref}."
        end

        io.seek(header_size)
      end

      ##
      # @return [Integer]

      def file_size
        header_size.snapshot + data_size.snapshot
      end

      ##
      # Header format for log output
      #
      # Example:
      #   HS: 14   PlV: 32   PeV: 1012 DS: 1106 DT: .FIT CRC:0
      #
      # @return [String]

      def to_log_s
        {
          file_header: [
            ('%-8s' % "HS: #{header_size.snapshot}"),
            ('%-8s' % "PlV:#{protocol_version.snapshot}"),
            ('%-8s' % "PeV:#{profile_version.snapshot}"),
            ('%-8s' % "DS: #{data_size.snapshot}"),
            ('%-8s' % "DT: #{data_type.snapshot}"),
            ('%-8s' % "CRC:#{crc.snapshot}"),
          ].join(' ')
        }
      end

    end

    ##
    #  Record header
    #
    #   | Bit | Value       | Description           |
    #   |-----+-------------+-----------------------|
    #   |   7 | 0           | Normal Header         |
    #   |   6 | 0 or 1      | Message Type:         |
    #   |     |             | 1: Definition         |
    #   |     |             | 2: Data               |
    #   |   5 | 0 (default) | Message Type Specific |
    #   |   4 | 0           | Reserved              |
    #   | 0-3 | 0-15        | Local Message Type    |

    class RecordHeader < BinData::Record
      bit1 :normal
      bit1 :message_type
      bit1 :developer_data_flag
      bit1 :reserved

      choice :local_message_type, selection: :normal do
        bit4 0
        bit2 1
      end

      ##
      # Serves as first place for validating data.
      #
      # @param [IO] io

      def read(io)
        super

        if compressed?
          Log.error "Compressed Timestamp Headers are not supported. #{inspect}"
        end

        Log.decode [self.class, __method__], to_log_s
      end

      ##
      # @param [io] io

      def write(io)
        super

        Log.encode [self.class, __method__], to_log_s
      end

      ##
      # @return [Boolean]

      def compressed?
        normal.snapshot == 1
      end

      ##
      # @return [Boolean]

      def for_new_definition?
        normal.snapshot.zero? && message_type.snapshot == 1
      end

      ##
      # Header format for log output
      #
      # @example:
      #   record_{data}_header: N: 0 MT: 1 DDF: 0 R: 0 LMT: 6
      #
      # @return [String]

      def to_log_s
        {
          "#{message_type.snapshot.zero? ? 'record_data' : 'record'}_header" => [
            ('%-8s' % "N:  #{normal.snapshot}"),
            ('%-8s' % "MT: #{message_type.snapshot}"),
            ('%-8s' % "DDF:#{developer_data_flag.snapshot}"),
            ('%-8s' % "R:  #{reserved.snapshot}"),
            ('%-8s' % "LMT:#{local_message_type.snapshot}"),
          ].join(' ')
        }
      end

      ##
      # Helper method for writing data headers
      #
      # @param [IO] io
      # @param [Record] record

      def write_data_header(io, record)
        data_header = self.new
        data_header.normal = 0
        data_header.message_type = 0
        data_header.local_message_type = record[:local_message_number]
        data_header.write(io)
      end

    end

    ##
    # Record Field
    #
    #   | Bit | Name             | Description                         |
    #   |-----+------------------+-------------------------------------|
    #   |   7 | Endian Ability   | 0 - for single byte data            |
    #   |     |                  | 1 - if base type has endianness     |
    #   |     |                  | (i.e. base type is 2 or more bytes) |
    #   | 5-6 | Reserved         | Reserved                            |
    #   | 0-4 | Base Type Number | Number assigned to Base Type        |

    class RecordField < BinData::Record

      hide :reserved

      uint8 :field_definition_number
      uint8 :byte_count
      bit1 :endian_ability
      bit2 :reserved
      bit5 :base_type_number

      ##
      # @return [String]

      def name
        global_message_field[:field_name]
      end

      ##
      # @return [Integer]

      def number
        global_message_field[:field_def]
      end

      ##
      # Returns field in [BinData::Struct] format.
      # Field identifier is its number[String] since some field names
      # (e.g., 'type') are reserved [BinData::Struct] keywords.
      #
      # @example
      #   [:uint8, '1']
      #   [:string, '2', {length: 8}]
      #   [:array, '3', {type: uint8, initial_length: 4}]
      #
      # @return [Array]

      def to_bindata_struct
        type = base_type_definition[:bindata]
        bytes = base_type_definition[:bytes]

        case
        when type == :string
          [type, number.to_s, {length: byte_count.snapshot}]
        when byte_count.snapshot > bytes # array
          if byte_count.snapshot % bytes != 0
            Log.error <<~ERROR
              Total bytes ("#{total_bytes}") must be multiple of base type
              bytes ("#{bytes}") of type "#{type}" in global FIT message "#{name}".
            ERROR
          end
          length = byte_count.snapshot / bytes
          [:array, number.to_s, {type: type, initial_length: length}]
        else
          [type, number.to_s]
        end
      end

      ##
      # Global message field with all its properties
      #
      # @return [Hash]

      def global_message_field
        @global_message_field ||= global_message[:fields].
          find { |f| f[:field_def] ==  field_definition_number.snapshot }
      end

      ##
      # Global message for field.
      #
      # @return [Hash]

      def global_message
        @global_message ||= parent.parent.global_message
      end

      ##
      # Base type definitions for field
      #
      # @return [Hash]

      def base_type_definition
        @base_type_definition ||= get_base_type_definition
      end

      ##
      # Field log output
      #
      # @example:
      #   FDN:2 BC: 4 EA: 1 R: 0 BTN:4 uint16 message_# field_#:  0 65535
      #
      # @param [String,Integer] value
      # @return [String]

      def to_log_s(value)
        [
          ('%-8s' % "FDN:#{field_definition_number.snapshot}"),
          ('%-8s' % "BC: #{byte_count.snapshot}"),
          ('%-8s' % "EA: #{endian_ability.snapshot}"),
          ('%-8s' % "R:  #{reserved.snapshot}"),
          ('%-8s' % "BTN:#{base_type_number.snapshot}"),
          ('%-8s' % (base_type_definition[:fit])),
          global_message[:name],
          " #{name}: ",
          value,
        ].join(' ')
      end

      private

      ##
      # Find base type definition for field
      #
      # @return [Hash]

      def get_base_type_definition
        field_type = global_message_field[:field_type].to_sym
        global_type = GlobalFit.types[field_type]

        type_definition = GlobalFit.base_types.find do |dt|
          dt[:fit] == (global_type ? global_type[:base_type].to_sym : field_type)
        end

        unless type_definition
          Log.warn <<~WARN
            Data type "#{global_message_field[:field_type]}" is not a valid
            type for field field "#{global_message_field[:field_name]}
            (#{global_message_field[:filed_number]})" in message
            number "#{field_definition_number.snapshot}".
          WARN
        end

        type_definition
      end

    end

    ##
    # Record
    #
    #   | Byte            | Description           | Length     | Value         |
    #   |-----------------+-----------------------+------------+---------------|
    #   | 0               | Reserved              | 1 Byte     | 0             |
    #   | 1               | Architecture          | 1 Byte     | Arch Type:    |
    #   |                 |                       |            | 0: Little     |
    #   |                 |                       |            | 1: Big        |
    #   | 2-3             | Global Message #      | 2 Bytes    | 0: 65535      |
    #   | 4               | Fields                | 1 Byte     | # of fields   |
    #   | 5-              | Field Definition      | 3 Bytes    | Field content |
    #   | 4 + Fields * 3  |                       |  per field |               |
    #   | 5 + Fields * 3  | # of Developer Fields | 1 Byte     | # of Fields   |
    #   | 6 + Fields * 3- | Developer Field Def.  | 3 Bytes    |               |
    #   | END             |                       |  per feld  | Field content |

    class Record < BinData::Record
      hide :reserved

      uint8 :reserved, initial_value: 0
      uint8 :architecture, initial_value: 0, assert: lambda { value <= 1 }

      choice :global_message_number, selection: :architecture do
        uint16le 0
        uint16be :default
      end

      uint8 :field_count
      array :data_fields, type: RecordField, initial_length: :field_count

      ##
      # Serves as first place for validating data.
      #
      # @param [IO] io

      def read(io)
        super

        unless global_message
          Log.error <<~ERROR
            Undefined global message: "#{global_message_number.snapshot}".
          ERROR
        end
      end

      ##
      # Helper for getting the architecture
      #
      # @return [Symbol]

      def endian
        @endion ||= architecture.zero? ? :little : :big
      end

      ##
      # Helper for getting the message global message
      #
      # @return [Hash] @global_message

      def global_message
        @global_message ||= GlobalFit.messages.find do |m|
          m[:number] == global_message_number.snapshot
        end
      end

      ##
      # Read data belonging to the same definition.
      #
      # @param [IO] io
      # @return [BinData::Struct] data

      def read_data(io)
        data = to_bindata_struct.read(io)

        Log.decode [self.class, __method__],
          pos: io.pos, record: to_log_s

        data_fields.each do |df|
          Log.decode [self.class, __method__],
            field: df.to_log_s(data[df.number].snapshot)
        end

        data
      end

      ##
      # Write data belonging to the same definition.
      #
      # @param [IO] io
      # @param [Record] record

      def write_data(io, record)
        struct = to_bindata_struct

        record[:fields].each do |name, field|
          struct[field[:definition].number] = field[:value]

          Log.encode [self.class, __method__],
            pos: io.pos,
            field: field[:definition].to_log_s(field[:value])
        end

        struct.write(io)
      end

      ##
      # Create [BinData::Struct] to contain and read and write
      # the data belonging to the same definition.
      #
      # @return [BinData::Struct]

      def to_bindata_struct
        opts = {
          endian: endian,
          fields: data_fields.map(&:to_bindata_struct)
        }
        BinData::Struct.new(opts)
      end

      private

      ##
      # Definition log output
      #
      # @example:
      #   R: 0 A: 0 GM: 18 FC: 95
      #
      # @return [String]

      def to_log_s
        [
          ('%-8s' % "R:  #{reserved.snapshot}"),
          ('%-8s' % "A:  #{architecture.snapshot}"),
          ('%-8s' % "GM: #{global_message_number.snapshot}"),
          ('%-8s' % "FC: #{field_count.snapshot}"),
          ('%-8s' % global_message[:value_name]),
        ].join(' ')
      end
    end

  end

  ##
  # Stores records and meta data for encoding and decoding

  class Registry

    ##
    # Main file header
    #
    # @return [BinData::RecordHeader] header
    attr_reader :header

    ##
    # Storage for all records including their meta data
    #
    # @return [Hash]

    attr_accessor :records

    ##
    # Definitions for all records
    #
    # @return [Array<Hash>]

    attr_accessor :definitions

    def initialize(header)
      @header = header
      @records = []
      @definitions = []
    end

    ##
    # Add record to +@records+ [Array<Hash>]
    #
    # @param [Hash] record
    # @param [Integer] local_message_number

    def add(record, local_message_number)
      @records << {
        index: @records.size,
        message_name: record.message[:name],
        message_number: record.message[:number],
        message_source: record.message[:source],
        local_message_number: local_message_number,
        fields: record.fields
      }
    end

    ##
    # Helper method to find the associated definitions with an specific record
    #
    # @param [Hash] record
    # @return [Hash]

    def definition(record)
      definitions.find do |d|
        d[:local_message_number] == record[:local_message_number] &&
          d[:message_name] == record[:message_name]
      end
    end

  end

  ##
  # +Record+ is where each data message gets stored including meta data.

  class Record

    ##
    # Where all fields for the specific record get stored
    #
    # @example
    #   {
    #     field_1: {
    #       value: value,
    #       base_type: base_type,
    #       message_name: 'file_id',
    #       message_number: 0,
    #       properties: {...}, # copy of global message's field
    #     },
    #     field_2: {
    #       value: value,
    #       base_type: base_type,
    #       message_name: 'file_id',
    #       message_number: 0,
    #       properties: {...}, # copy of global message's field
    #     },
    #    ...
    #   }
    #
    # @return [Hash] current message fields.

    attr_reader :fields

    def initialize(message_name)
      @message_name = message_name
      @fields = {}
    end

    ##
    # Global message
    #
    # @return [Hash] copy of associated global message.

    def message
      @message ||= GlobalFit.messages.find { |m| m[:name] == @message_name }
    end

    ##
    # Sets the +value+ attribute for the passed field.
    #
    # @param [RecordField] definition
    # @param [String, Integer] value

    def set_field_value(definition, value)
      if fields[definition.name]
        @fields[definition.name][:value] = value
        @fields[definition.name][:definition] = definition
      else
        @fields[definition.name] = {
          value: value,
          base_type: definition.base_type_definition,
          message_name: definition.global_message[:name],
          message_number: definition.global_message[:number],
          definition: definition,
          properties: definition.global_message_field,
        }
      end
    end

  end

  ##
  # FIT binary file Encoder/Writer

  module Encoder

    ##
    # Encode/Write binary FIT file
    #
    # @param [String] file_name path for new FIT file
    # @param [Hash,Registry] records
    #
    # @param [String] source
    #   Optional source FIT file to be used as a reference for
    #   structuring the binary data.
    #
    # @return [File] binary FIT file

    def self.encode(file_name, records, source)
      io = ::File.open(file_name, 'wb+')

      if records.is_a? Registry
        registry = records
      else
        registry = RegistryBuilder.new(records, source).registry
      end

      begin
        start_pos = registry.header.header_size

        io.seek(start_pos)

        local_messages = []
        last_local_message_number = nil
        registry.records.each do |record|

          local_message = local_messages.find do |lm|
            lm[:local_message_number] == record[:local_message_number] &&
              lm[:message_name] == record[:message_name]
          end

          unless local_message ||
              record[:local_message_number] == last_local_message_number

            local_messages << {
              local_message_number: record[:local_message_number],
              message_name: record[:message_name]
            }

            definition = registry.definition(record)
            definition[:header].write(io)
            definition[:record].write(io)
          end

          definition = registry.definition(record)
          definition[:header].write_data_header(io, record)
          definition[:record].write_data(io, record)

          last_local_message_number = record[:local_message_number]
        end

        end_pos = io.pos
        BinData::Uint16le.new(CRC16.crc(IO.binread(io, end_pos, start_pos))).write(io)
        registry.header.data_size = end_pos - start_pos
        io.rewind
        registry.header.write(io)
      ensure
        io.close
      end

      file_name
    end

    ##
    # {Encoder} requires a properly built {Registry} to be able to encode.

    class RegistryBuilder

      ##
      # @return [Registry]

      attr_reader :registry

      def initialize(records, source)
        @records = records
        @source = source
        source ? clone_definitions : build_definitions
      end

      private

      ##
      # Decode source FIT file that will be used to provide binary
      # structure for the FIT file to be created.
      #
      # @param [String] source path to FIT file

      def clone_definitions
        io = ::File.open(@source, 'rb')

        begin
          until io.eof?
            offset = io.pos

            header = Definition::Header.read(io)
            @registry = Registry.new(header)

            while io.pos < offset + header.file_size
              record_header = Definition::RecordHeader.read(io)

              local_message_number = record_header.local_message_type.snapshot

              if record_header.for_new_definition?
                definition = Definition::Record.read(io)

                @registry.definitions << {
                  local_message_number: local_message_number,
                  message_name: definition.global_message[:name],
                  header: record_header,
                  record: definition,
                }
              else
                @registry.definitions.reverse.find do |d|
                  d[:local_message_number] == local_message_number
                end[:record].read_data(io)
              end
            end

            io.seek(2, :CUR)
          end
        ensure
          io.close
        end

        build_records
      end

      ##
      # Try to build definitions with the most accurate binary structure.

      def build_definitions
        @registry = Registry.new(Definition::Header.new)

        largest_records = @records.
          group_by { |record| record[:message_name] }.
          inject({}) do |r, rcrds|
          r[rcrds[0]] = rcrds[1].sort_by { |rf| rf[:fields].count }.last
          r
        end

        largest_records.each do |name, record|
          global_message = GlobalFit.messages.find do |m|
            m[:name] == name
          end

          definition = @registry.definition(record)

          unless definition

            record_header = Definition::RecordHeader.new
            record_header.normal = 0
            record_header.message_type = 1
            record_header.local_message_type = record[:local_message_number]

            definition = Definition::Record.new
            definition.field_count = record[:fields].count
            definition.global_message_number = global_message[:number]

            record[:fields].each_with_index do |(field_name, _), index|
              global_field = global_message[:fields].
                find { |f| f[:field_name] == field_name }

              field_type = global_field[:field_type].to_sym
              global_type = GlobalFit.types[field_type]

              # Check in GlobalFit first as types can be anything form
              # strings to files, exercise, water, etc...
              base_type = GlobalFit.base_types.find do |dt|
                dt[:fit] == (global_type ? global_type[:base_type].to_sym : field_type)
              end

              unless base_type
                Log.warn <<~WARN
                  Data type "#{field[:field_type]}" is not a valid type for field
                  "#{field[:field_name]} (#{field[:filed_number]})".
                WARN
              end

              field = definition.data_fields[index]

              field.field_definition_number = global_field[:field_def]
              field.byte_count = 0 # set on build_records
              field.endian_ability = base_type[:endian]
              field.base_type_number = base_type[:number]
            end

            @registry.definitions << {
              local_message_number: record[:local_message_number],
              message_name: definition.global_message[:name],
              header: record_header,
              record: definition
            }
          end
        end

        build_records
      end

      ##
      # Build and add/fix records' binary data/format.
      #
      # @return [Hash] fixed/validated records

      def build_records
        fixed_strings = {}

        @records.each do |record|
          definition = registry.definition(record)
          definition = definition && definition[:record]

          fields = {}

          definition.data_fields.each do |field|
            record_field = record[:fields][field.name]

            if record_field && !record_field[:value].nil?
              value = record_field[:value]
            else
              value = field.base_type_definition[:undef]

              sibling = field_sibling(field)
              if sibling.is_a?(Array)
                value = [field.base_type_definition[:undef]] * sibling.size
              end
            end

            unless from_source?
              field.byte_count = field.base_type_definition[:bytes]

              if field.base_type_definition[:bindata] == :string
                if fixed_strings[record[:message_name]] &&
                    fixed_strings[record[:message_name]][field.name]
                  largest_string = fixed_strings[record[:message_name]][field.name]
                else
                  largest_string = @records.
                    select {|rd| rd[:message_name] == record[:message_name] }.
                    map do |rd|
                    rd[:fields][field.name] &&
                      rd[:fields][field.name][:value].to_s.length
                  end.compact.sort.last

                  fixed_strings[record[:message_name]] = {}
                  fixed_strings[record[:message_name]][field.name] = largest_string
                end

                field.byte_count = ((largest_string / 8) * 8) + 8
              end

              if value.is_a?(Array)
                field.byte_count *= value.size
              end
            end

            if field.base_type_definition[:bindata] == :string
              opts = {length: field.byte_count.snapshot}
              value = BinData::String.new(value, opts).snapshot
            end

            fields[field.name] = {
              value: value,
              base_type: field.base_type_definition,
              properties: field.global_message_field,
              definition: field
            }
          end

          registry.records << {
            message_name: definition.global_message[:name],
            message_number: definition.global_message[:number],
            local_message_number: record[:local_message_number],
            fields: fields
          }
        end
      end

      ##
      # Helper method for finding a field's sibling.
      #
      # This is mostly because we can't trust base_type on arrays.
      #
      # @param [RecordField] field
      # @return [Array,Integer,String] sibling

      def field_sibling(field)
        sibling = @records.find do |rd|
          rd[:message_name] == field.global_message[:name] &&
            rd[:fields].keys.include?(field.name)
        end

        sibling && sibling[:fields][field.name][:value]
      end

      ##
      # @return [Boolean]

      def from_source?
        !@source.nil?
      end

    end

  end

  ##
  # Decode/Read binary FIT file and return data in a {Registry}.

  class Decoder

    ##
    # FIT binary file decoder/reader by providing data
    # in a human readable format [Hash]
    #
    # @param [String] file_name path for file to be read

    def self.decode(file_name)
      io = ::File.open(file_name, 'rb')

      begin
        until io.eof?
          offset = io.pos

          registry = Registry.new(Definition::Header.read(io))

          while io.pos < offset + registry.header.file_size
            record_header = Definition::RecordHeader.read(io)

            local_message_number = record_header.local_message_type.snapshot

            if record_header.for_new_definition?
              record_definition = Definition::Record.read(io)

              registry.definitions << {
                local_message_number: local_message_number,
                message_name: record_definition.global_message[:name],
                header: record_header,
                record: record_definition
              }
            else
              record_definition = registry.definitions.reverse.find do |d|
                d[:local_message_number] == local_message_number
              end[:record]

              data = record_definition.read_data(io)

              record = Record.new(record_definition.global_message[:name])

              record_definition.data_fields.each do |field|
                value = data[field.number].snapshot
                record.set_field_value(field, value)
              end

              registry.add record, local_message_number
            end
          end

          io.seek(2, :CUR)
        end
      ensure
        io.close
      end

      Log.info "Finished reading #{file_name} file."

      registry
    end

  end

  ##
  # @param [String] file path to file to be decoded.

  def self.decode(file)
    Log.info "Reading #{file} file."
    Decoder.decode(file)
  end

  ##
  # @param [String] file path for new FIT file
  # @param [Hash,Registry] records
  #
  # @param [String] source
  #   Optional source FIT file to be used as a reference for
  #   structuring the binary data.

  def self.encode(file, records, source = nil)
    Log.info "Writing to #{file} file."
    Encoder.encode(file, records, source)
  end

end
