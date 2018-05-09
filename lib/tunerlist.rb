#!/usr/bin/env ruby
# frozen_string_literal: true

require 'serialport'
require 'pp'

def hex(data)
  data.map do |b|
    format('%02x', b)
  end
end

module TunerList
  class FrameCodec
    FRAME_HEADER = 0x3d
    ACKNOWLEDGE  = 0xc5

    def initialize(serialport)
      @serialport = serialport
      @status = :init
      @frame_id = 0
    end

    def ack
      write_raw [ACKNOWLEDGE]
    end

    def write_raw(bytes)
      @serialport.write(bytes.pack('C*'))
    end

    def frame_sequence
      @frame_id = (@frame_id + 1) % 256
    end

    def write_data(data)
      frame = [FRAME_HEADER, frame_sequence, data.length]
      frame += data
      frame += [FrameCodec.compute_checksum(frame)]
      write_raw frame
      @frame_acked = false
    end

    def write_payload(payload_type, payload)
      data = [payload_type]
      data += payload
      write_data(data)
    end

    def read
      output = nil
      # puts "Status: #{@status.to_s}"
      @status = case @status
                when :init
                  @frame = []
                  process_first_byte
                when :header
                  process_bytes(1, :id)
                when :id
                  process_bytes(1, :data) do |bytes|
                    process_bytes(bytes.first, true, false)
                  end
                when :data
                  process_checksum
                when :complete
                  puts '\o/'
                  output = @frame
                  :init
                when :invalid_checksum
                  puts 'Checksum is invalid'
                  :init
                when :acknowledge then
                  @frame_acked = true
                  :init
                else
                  :init
                end
      output
    end

    private_class_method

    def self.compute_checksum(bytes)
      checksum = 0x00
      bytes.each do |b|
        checksum ^= b
      end
      checksum
    end

    private

    def read_raw(count)
      string = @serialport.read(count)
      return nil if string.nil?
      string.bytes
    end

    def process_first_byte
      bytes = read_raw(1)
      return :init if bytes.nil?
      case bytes.first
      when FRAME_HEADER
        @frame += bytes
        :header
      when ACKNOWLEDGE
        :acknowledge
      else
        puts "Dropped byte: #{hex(bytes)}"
        :init
      end
    end

    def process_checksum
      process_bytes(1, :complete, :invalid_checksum) do |bytes|
        FrameCodec.compute_checksum(@frame) == bytes.first
      end
    end

    def process_bytes(count, success, failure = :init)
      bytes = read_raw(count)
      return failure if bytes.nil?

      result = block_given? ? yield(bytes) : true

      if result == true
        @frame += bytes
        return success
      end
      failure
    end
  end

  class HeadUnitEmulator
    # CDC
    BOOTING       = 0x11
    STATUS        = 0x20
    RANDOM_STATUS = 0x25
    PLAYING       = 0x47

    RANDOM_STATUS_ON  = 0x07
    RANDOM_STATUS_OFF = 0x03

    # HU
    NEXT_TRACK = 0x17

    def initialize(port)
      @serialport = SerialPort.new(port,
                                   baud: 9600,
                                   data_bits: 8,
                                   stop_bits: 1,
                                   parity: SerialPort::EVEN)

      @serialport.read_timeout = 2000
      @frame_codec = TunerList::FrameCodec.new @serialport
      @cdc = {}
    end

    def run
      loop do
        @frame = @frame_codec.read
        process_frame unless @frame.nil?
      end
    end

    private

    def extract_data
      @frame[2..-1]
    end

    def int_to_bcd(int)
      s = int.to_s
      s.insert(0, '0') if s.length.odd?
      [s].pack('H*').unpack('C*')[0]
    end

    def bcd_to_int(bcd)
      format('%02x', bcd).to_i 10
    end

    def send_next_track
      puts 'next track'
      @frame_codec.write_payload(NEXT_TRACK, [0x01])
    end

    def process_frame
      @frame_codec.ack
      data = extract_data
      payload_type = data[0]
      payload = data[1..-1]
      case payload_type
      when BOOTING
        process_booting
      when STATUS
        process_status(payload)
      when RANDOM_STATUS then
        process_random_status(payload)
      when PLAYING then
        process_playing(payload)
        send_next_track
      else
        puts "Unknown data: #{hex(data)} (length: #{data.length})"
      end
    end

    def process_booting
      @cdc[:status] = :booting
    end

    def process_status(payload)
      @cdc[:status] = :ready
      @cdc[:cd_state] = payload[0]
      @cdc[:tray_state] = payload[1]
      @cdc[:cd_number] = payload[4]
      pp @cdc
    end

    def process_random_status(payload)
      @cdc[:random] = payload[0] == RANDOM_STATUS_ON
      pp @cdc
    end

    def process_playing(payload)
      @cdc[:track_number] = bcd_to_int(payload.shift)
      @cdc[:cd_time] = payload_to_time(payload)
      @cdc[:track_time] = payload_to_time(payload)
      pp @cdc
    end

    def payload_to_time(payload)
      {
        hour:   bcd_to_int(payload.shift),
        minute: bcd_to_int(payload.shift),
        second: bcd_to_int(payload.shift),
        sector: bcd_to_int(payload.shift),
      }
    end
  end
end
