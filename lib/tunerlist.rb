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
end
