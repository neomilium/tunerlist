#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tunerlist'
require 'timeout'

module TunerList
  class HeadUnitEmulator < Emulator
    def initialize(port)
      super(port)
      @supported_commands = CDC

      @cdc = {}
    end

    private

    def boot_sequence
      [
        [HU::HU_ON],
        [HU::STOP_PLAY],
        [HU::REQ_CD_INFO],
        [HU::RANDOM, 0x02, 0x0a],
        [HU::START_PLAY],
      ]
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
      @transceiver.send([HU::NEXT_TRACK, 0x01])
    end

    private

    def process_booting(payload)
      @cdc[:status] = :booting
    end

    def process_status(payload)
      @cdc[:status] = :ready
      @cdc[:cd_state] = Helper.const_prettify(CD, payload[0])
      @cdc[:tray_state] = Helper.const_prettify(Tray, payload[1])
      @cdc[:cd_number] = payload[4]
      pp @cdc
    end

    def process_random_status(payload)
      puts "random_status = #{Helper.const_prettify(RandomStatus, payload[0])}"
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
