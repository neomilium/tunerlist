#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tunerlist'

module TunerList
  class HeadUnitEmulator
    def initialize(port)
      @transceiver = TunerList::Transceiver.new port
      @cdc = {}
    end

    def run
      loop do
        process_data @transceiver.receive
      end
    end

    private

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
      @transceiver.send([HU::NEXT_TRACK, 0x01])
    end

    def process_data(data)
      payload_type = data.shift
      payload = data
      case payload_type
      when CDC::BOOTING
        process_booting
      when CDC::STATUS
        process_status(payload)
      when CDC::RANDOM_STATUS
        process_random_status(payload)
      when CDC::PLAYING
        process_playing(payload)
        send_next_track
      else
        puts "Unknown payload_type: #{hex([payload_type])} with payload: #{payload} (length: #{payload.length})"
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
      @cdc[:random] = payload[0] == RandomStatus::ON
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
