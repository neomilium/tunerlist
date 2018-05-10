#!/usr/bin/env ruby
# frozen_string_literal: true

require 'serialport'

require 'tunerlist'

module TunerList
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
