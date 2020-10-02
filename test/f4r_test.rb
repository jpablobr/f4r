require 'test_helper'

describe F4R do

  describe F4R::Config do

    it 'allows to set a custom config directory' do

      _(F4R::Config.directory.match?(/\/f4r\/config/)).must_equal true

      F4R::Config.directory = '~/.test'
      _(F4R::Config.directory).must_equal '~/.test'

      F4R::Config.directory = nil
      _(F4R::Config.directory.match?(/\/f4r\/config/)).must_equal true

    end

  end

  describe F4R::Definition::Header do

    let(:header) { F4R::Definition::Header.new }
    let(:header_io) { StringIO.new("\x0E\x10-\b\xEB\x16\x00\x00.FIT\xAC\xEF") }

    it 'writes/encodes' do

      io = StringIO.open('')
      _(io.size).must_equal 0
      header.write(io)
      _(io.size).must_equal 14

      _(io.string.force_encoding('ASCII-8BIT')).must_equal(
        "\x0E\x10-\b\x00\x00\x00\x00.FIT\x94\xD5".force_encoding('ASCII-8BIT'))

    end

    it 'reads/decodes' do

      _(header.snapshot).must_equal(
        header_size: 14,
        protocol_version: 16,
        profile_version: 2093,
        data_size: 0,
        data_type: ".FIT",
        crc: 0
      )

      def header.crc_mismatch?(io); end # stub

      header.read(header_io)

      _(header.snapshot).must_equal(
        header_size: 14,
        protocol_version: 16,
        profile_version: 2093,
        data_size: 5867,
        data_type: ".FIT",
        crc: 61356
      )

    end

    it 'validates' do

      begin
        wrong_size = StringIO.new("\xDA\x10-\b\xEB\x16\x00\x00.FIT\xAC\xEF")
        _(header.read(wrong_size)).must_raise F4R::Error
      rescue => e
        assert_match(/Unsupported header size: 218./, e.to_s)
      end

      begin
        wrong_type = StringIO.new("\x0E\x10-\b\xEB\x16\x00\x00.AIT\xAC\xEF")
        _(header.read(wrong_type)).must_raise F4R::Error
      rescue => e
        assert_match(/Unknown file type: .AIT./, e.to_s)
      end

      begin
        wrong_crc = StringIO.new("\x0E\x10-\b\xEB\x16\x00\x00.FIT\xAC\xEA")
        _(header.read(wrong_crc)).must_raise F4R::Error
      rescue => e
        assert_match(/CRC mismatch: Computed 61356 instead of 60076./, e.to_s)
      end

    end

  end

  describe F4R::Definition::RecordHeader do

    let(:record_header) { ::F4R::Definition::RecordHeader.new }

    it 'reads/decodes' do

      _(record_header.snapshot).must_equal(
        normal: 0,
        message_type: 0,
        developer_data_flag: 0,
        reserved: 0,
        local_message_type: 0
      )

      record_header.read(StringIO.new("@"))
      _(record_header.snapshot.values).must_equal([0, 1, 0, 0, 0])

      record_header.read(StringIO.new("\x00"))
      _(record_header.snapshot.values).must_equal([0, 0, 0, 0, 0])

      record_header.read(StringIO.new("A"))
      _(record_header.snapshot.values).must_equal([0, 1, 0, 0, 1])

      record_header.read(StringIO.new("\x01"))
      _(record_header.snapshot.values).must_equal([0, 0, 0, 0, 1])

      record_header.read(StringIO.new("B"))
      _(record_header.snapshot.values).must_equal([0, 1, 0, 0, 2])

      record_header.read(StringIO.new("\x02"))
      _(record_header.snapshot.values).must_equal([0, 0, 0, 0, 2])

      _(record_header.snapshot).must_equal(
        normal: 0,
        message_type: 0,
        developer_data_flag: 0,
        reserved: 0,
        local_message_type: 2,
      )

    end

    it 'validates' do

      begin
        _(record_header.read(StringIO.new("\xFF\xE0"))).must_raise F4R::Error
      rescue => e
        assert_match(/Compressed Timestamp Header/, e.to_s)
      end

    end

  end

  describe F4R::Definition::RecordField do

    let(:field) { F4R::Definition::RecordField.new }

    it 'reads/decodes' do

      def field.global_message; end # stub

        _(field.snapshot).must_equal(
          field_definition_number: 0,
          byte_count: 0,
          endian_ability: 0,
          base_type_number: 0
        )

        field.read(StringIO.new("\x03\x04\x8C"))
        _(field.snapshot.values).must_equal([3, 4, 1, 12])

    end

  end

  describe F4R::Definition::Record do

    let(:definition) { F4R::Definition::Record.new }

    it 'reads/decodes' do

      definition.read(StringIO.new(
        "\x00\x01\x00\x00\x05\x03\x04\x8C\x04\x04\x86\x01\x02\x84\x02\x02\x84\x00\x01\x00"))
      _(definition.snapshot).must_equal(
        architecture: 1,
        global_message_number: 0,
        field_count: 5,
        data_fields: [
          {
            field_definition_number: 3,
            byte_count: 4,
            endian_ability: 1,
            base_type_number: 12
          },
          {
            field_definition_number: 4,
            byte_count: 4,
            endian_ability: 1,
            base_type_number: 6
          },
          {
            field_definition_number: 1,
            byte_count: 2,
            endian_ability: 1,
            base_type_number: 4
          },
          {
            field_definition_number: 2,
            byte_count: 2,
            endian_ability: 1,
            base_type_number: 4
          },
          {
            field_definition_number: 0,
            byte_count: 1,
            endian_ability: 0,
            base_type_number: 0
          }
        ]
      )

      data = definition.read_data(
        StringIO.new("\x7F\xFF\xFF\xFF)\xE6\a\x12\x00\x0F\x00\x01\x04"))
      _(data.snapshot).must_equal(
        '3': 2147483647, # serial_number
        '4': 702940946, # time_created
        '1': 15, # manufacturer
        '2': 1, # product
        '0': 4 # type
      )

    end

    it 'validates' do

      begin
        wrong_arch = StringIO.new(
          "\x00\x03\x00\x00\x05\x03\x04\x8C\x04\x04\x86\x01\x02\x84\x02\x02\x84\x00\x01\x00")
        _(definition.read(wrong_arch)).must_raise BinData::ValidityError
      rescue => e
        assert_match(/value '3' not as expected for obj.architecture/, e.to_s)
      end

      begin
        undefined_global_message = StringIO.new(
          "\x00\x01\x00\xDD\x05\x03\x04\x8C\x04\x04\x86\x01\x02\x84\x02\x02\x84\x00\x01\x00")
        _(definition.read(undefined_global_message)).must_raise F4R::Error
      rescue => e
        assert_match(/Undefined global message: "221"/, e.to_s)
      end

    end

  end

  describe F4R, 'reading, writing and editing a FIT file' do

    let(:tmp_fit_file) { 'tmp.fit' }
    let(:edited_tmp_fit_file) { 'edited_tmp.fit' }

    it 'data gets stored correctly' do

      # Similar format as the FIT SDK CSV tool requirements
      records = [
        {
          message_name: :file_id,
          local_message_number: 0,
          fields: {
            serial_number: {value: 123456789}, # uint32z/uint32
            type: {value: 4}, # enum/unit8
            manufacturer: {value: 1}}}, # uint16/uint16
        {
          message_name: :file_id,
          local_message_number: 0,
          fields: {
            serial_number: {value: 123456789},  # uint32z/uint32
            type: {value: 5}, # enum/uint8
            manufacturer: {value: 1}}}, # unit16/unit16
        {
          message_name: :device_info,
          local_message_number: 1,
          fields: {
            timestamp: {value: 939346537}, # uint32/unit32
            source_type: {value: 1}, # enum/unit8
            device_index: {value: 0}, # enum/uint8
            manufacturer: {value: 1},
            serial_number: {value: 123456789}, # uint32z/uint32
            undocumented_field_29: {value: [0, 1, 2, 3, 4, 5]}}}, # enum/unit8
        {
          message_name: :device_info,
          local_message_number: 1,
          fields: {
            timestamp: {value: 939346538}, # uint32/unit32
            undocumented_field_29: {value: [5, 4, 3, 2, 1, 0]}}}, # enum/unit8
        {
          message_name: :device_info,
          local_message_number: 1,
          fields: {
            timestamp: {value: 939346539}}}, # uint32/unit32
            # undocumented_field_29: gets replaced with
            # array of its base_type_definitions[:undef]
        {
          message_name: :file_creator,
          local_message_number: 2,
          fields: {
            software_version: {value: 510}, # enum/unit8
            hardware_version: {value: 220}, # uint16/uint16
            undocumented_field_2: {value: "Foo"}}}, # string/string
        {
          message_name: :file_creator,
          local_message_number: 2,
          fields: {
            software_version: {value: 5}, # enum/unit8
            # nil should be replaced with
            # base_type_definitions[:undef]
            hardware_version: {value: nil}, # uint16/uint16
            undocumented_field_2: {value: "Bar Baz"}}}, # string/string
        {
          message_name: :file_creator,
          local_message_number: 2,
          fields: {
            software_version: {value: 5}, # enum/uint8
            # missing "hardware_version:" should be
            # replaced with base_type_definitions[:undef]
            undocumented_field_2: {value: ''}}}, # string/string
        {
          message_name: :event,
          local_message_number: 3,
          fields: {
            event: {value: 0}, # enum/uint8
            event_type: {value: 2}}}, # enum/uint8
        {
          message_name: :event,
          local_message_number: 3,
          fields: {
            event: {value: 1}, # enum/uint8
            event_type: {value: 2}}}, # enum/uint8
        {
          message_name: :session,
          local_message_number: 4,
          fields: {
            start_position_lat: {value:  29}, # sint32/int32
            sport: {value: 5}, # enum/uint8
            sub_sport: {value: 17}}}, # enum/uint8
        {
          message_name: :lap,
          local_message_number: 5,
          fields: {
            max_temperature: {value: 29}, # sint8/int8
            event: {value: 1}, # enum/uint8
            event_type: {value: 2}}} # enum/uint8
      ]

      F4R.encode(tmp_fit_file, records)
      _(File.exist?(tmp_fit_file)).must_equal true

      a = F4R.decode(File.open(tmp_fit_file))

      _(name_value_fields(a.records, :file_id)).must_equal([
        {serial_number: 123456789, type: 4, manufacturer: 1},
        {serial_number: 123456789, type: 5, manufacturer: 1}
      ])

      _(name_value_fields(a.records, :device_info)).must_equal([
        {
          timestamp: 939346537,
          source_type: 1,
          device_index: 0,
          manufacturer: 1,
          serial_number: 123456789,
          undocumented_field_29: [0, 1, 2, 3, 4, 5]
        },
        {
          timestamp: 939346538,
          source_type: 255,
          device_index: 255,
          manufacturer: 65535,
          serial_number: 0,
          undocumented_field_29: [5, 4, 3, 2, 1, 0]
        },
        {
          timestamp: 939346539,
          source_type: 255,
          device_index: 255,
          manufacturer: 65535,
          serial_number: 0,
          undocumented_field_29: [255] * 6
        }
      ])

      _(name_value_fields(a.records, :file_creator)).must_equal([
        {
          software_version: 510,
          hardware_version: 220,
          undocumented_field_2: ('Foo'+"\x00"*5).force_encoding('ASCII-8BIT')
        },
        {
          software_version: 5,
          hardware_version: 255,
          undocumented_field_2: "Bar Baz\x00".force_encoding('ASCII-8BIT')
        },
        {
          software_version: 5,
          hardware_version: 255,
          undocumented_field_2: ("\x00"*8).force_encoding('ASCII-8BIT')
        }
      ])

      _(name_value_fields(a.records, :session)).must_equal([
        {start_position_lat: 29, sport: 5, sub_sport: 17}
      ])

      _(name_value_fields(a.records, :lap)).must_equal([
        {max_temperature: 29, event: 1, event_type: 2}
      ])

      # Encode a again
      F4R.encode(tmp_fit_file, a)
      _(File.exist?(tmp_fit_file)).must_equal true

      # Read a again
      b = F4R.decode(tmp_fit_file)
      _(b.records.count).must_equal 12

      a_fields = a.records.map do |r|
        r[:fields].map {|k,v| [k, v[:value]] }
      end

      b_fields = b.records.map do |r|
        r[:fields].map {|k,v| [k, v[:value]] }
      end

      # Make sure all fields are the same
      a_fields.each_with_index do |r, index|
        r.to_h.each do |k,v|
          _(b_fields[index].to_h[k]).must_equal v
        end
      end

      # Edit and pass source file
      records[2][:fields].merge!( # device_info
        timestamp: {value: 123456789},
        source_type: {value: 5},
        device_index: {value: 2},
        manufacturer: {value: 2},
        serial_number: {value: 987654321},
        undocumented_field_29: {value: [6, 7, 8, 9, 10, 11]}
      )

      records[5][:fields].merge!( # file_creator
        software_version: {value: 123},
        hardware_version: {value: 202},
        undocumented_field_2: {value: 'Edit'}
      )

      F4R.encode(edited_tmp_fit_file, records, tmp_fit_file)
      _(File.exist?(edited_tmp_fit_file)).must_equal true

      c = F4R.decode(File.open(edited_tmp_fit_file))

      _(name_value_fields(c.records, :device_info)).must_equal([
        {
          timestamp: 123456789,
          source_type: 5,
          device_index: 2,
          manufacturer: 2,
          serial_number: 987654321,
          undocumented_field_29: [6, 7, 8, 9, 10, 11]
        },
        {
          timestamp: 939346538,
          source_type: 255,
          device_index: 255,
          manufacturer: 65535,
          serial_number: 0,
          undocumented_field_29: [5, 4, 3, 2, 1, 0]
        },
        {
          timestamp: 939346539,
          source_type: 255,
          device_index: 255,
          manufacturer: 65535,
          serial_number: 0,
          undocumented_field_29: [255] * 6
        }
      ])

      _(name_value_fields(c.records, :file_creator)).must_equal([
        {
          software_version: 123,
          hardware_version: 202,
          undocumented_field_2: ('Edit'+"\x00"*4).force_encoding('ASCII-8BIT')
        },
        {
          software_version: 5,
          hardware_version: 255,
          undocumented_field_2: "Bar Baz\x00".force_encoding('ASCII-8BIT')
        },
        {
          software_version: 5,
          hardware_version: 255,
          undocumented_field_2: ("\x00"*8).force_encoding('ASCII-8BIT')
        }
      ])

    end

    before do
      File.delete(tmp_fit_file) if File.exist?(tmp_fit_file)
      File.delete(edited_tmp_fit_file) if File.exist?(edited_tmp_fit_file)
    end

    after do
      File.delete(tmp_fit_file) if File.exist?(tmp_fit_file)
      File.delete(edited_tmp_fit_file) if File.exist?(edited_tmp_fit_file)
    end

  end

end
