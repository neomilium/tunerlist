#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tunerlist'
require 'timeout'

module TunerList
  class CompactDiscChangerEmulator < Emulator
    attr_reader :cd_number
    attr_reader :cd_state
    attr_reader :cd_time
    attr_reader :track_number
    attr_reader :track_time
    attr_reader :random_status

    def initialize(port)
      super(port)

      @cd_number = 0x01
      @cd_state = CD::PLAYING
      @random_status = RandomStatus::OFF
      @track_number = 0x23
      @track_time = [0x00, 0x12, 0x34, 0x02]
      @cd_time = [0x01, 0x12, 0x34, 0x02]

      @receive_commands_from = HU
      @send_commands_from = CDC

    end


    private

    def keep_alive
      begin
        send_status
      rescue Timeout::Error
        return false
      end
      true
    end

    def boot_sequence
      [
        [CDC::BOOTING, 0x60, 0x06],
        [CDC::BOOT_OK, 0x00, 0x25],
        status_to_frame,
        cd_operation_to_frame,
        random_status_to_frame,
        tray_status_to_frame,
        cd_summary_to_frame,
      ]
    end

    def send_booting
      send_and_wait_ack([CDC::BOOTING, 0x60, 0x06])
    end

    def send_status
      send_and_wait_ack status_to_frame
    end

    def status_to_frame
      [CDC::STATUS, cd_state, Tray::CD_READY, 0x09, 0x05, cd_number]
    end

    def cd_operation_to_frame
      [CDC::CD_OPERATION, cd_state]
    end

    def random_status_to_frame
      [CDC::RANDOM_STATUS, random_status]
    end

    def tray_status_to_frame
      [CDC::TRAY_STATUS, cd_state, cd_number, cd_bitmap, cd_bitmap]
    end

    def cd_summary_to_frame
      tracks_count = 0x99
      time_hour = 0x99
      time_minute = 0x99
      time_seconds = 0x99
      [CDC::CD_SUMMARY, tracks_count, 0x01, 0x00, time_hour, time_minute, time_seconds]
    end

    def cd_number
      0x01
    end

    def cd_state
      CD::PLAYING
    end

    def random_status
      RandomStatus::OFF
    end

    def cd_bitmap
      0xfc
    end
  end
end
