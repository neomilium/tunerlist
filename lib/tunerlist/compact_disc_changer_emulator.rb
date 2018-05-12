#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tunerlist'
require 'timeout'

module TunerList
  class CompactDiscChangerEmulator
    def initialize(port)
      @transceiver = TunerList::Transceiver.new port

      @status = :init
      @frame_queue = Queue.new
      @ack_queue = Queue.new
    end

    def run
      Thread.abort_on_exception = true
      Thread.report_on_exception = true
      Thread.new do
        loop do
          frame = @transceiver.read
          if frame.nil?
            @ack_queue << true if @transceiver.acknowledged?
          else
            @frame_queue << frame
          end
        end
      end
      loop do
        puts @status
        @status = case @status
                  when :init
                    send_boot_sequence ? :running : :init
                  when :running
                    status = :running
                    begin
                      Timeout.timeout(3) do
                        process_frame @frame_queue.pop
                      end
                    rescue Timeout::Error
                      status = keep_alive ? :running : :init
                    end
                    status
                  else
                    raise 'Invalid status'
                  end
      end
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

    def send_boot_sequence
      begin
        send_booting
        send_boot_ok
        send_status
        send_cd_operation
        send_random_status
        send_tray_status
        send_cd_summary
      rescue Timeout::Error
        puts 'timeout'
        return false
      end
      true
    end

    def send_and_wait_ack(data)
      @ack_queue.clear
      @transceiver.write_data(data)
      Timeout.timeout(3) do
        @ack_queue.pop
      end
    end

    def send_booting
      send_and_wait_ack([CDC::BOOTING, 0x60, 0x06])
    end

    def send_boot_ok
      send_and_wait_ack([CDC::BOOT_OK, 0x00, 0x25])
    end

    def send_status
      send_and_wait_ack([CDC::STATUS, cd_state, Tray::CD_READY, 0x09, 0x05, cd_number])
    end

    def send_cd_operation
      send_and_wait_ack([CDC::CD_OPERATION, cd_state])
    end

    def send_random_status
      send_and_wait_ack([CDC::RANDOM_STATUS, random_status])
    end

    def send_tray_status
      send_and_wait_ack([CDC::TRAY_STATUS, cd_state, cd_number, cd_bitmap, cd_bitmap])
    end

    def send_cd_summary
      tracks_count = 0x99
      time_hour = 0x99
      time_minute = 0x99
      time_seconds = 0x99
      send_and_wait_ack([CDC::CD_SUMMARY, tracks_count, 0x01, 0x00, time_hour, time_minute, time_seconds])
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
