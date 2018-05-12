#!/usr/bin/env ruby
# frozen_string_literal: true

require 'serialport'

def hex(data)
  data.map do |b|
    format('%02x', b)
  end
end

module TunerList
  module Frame
    HEADER = 0x3d
    ACKNOWLEDGE = 0xc5

    def compute_checksum(bytes)
      checksum = 0x00
      bytes.each do |b|
        checksum ^= b
      end
      checksum
    end
  end

  class Transceiver
    def initialize(port)
      @serialport = SerialPort.new(port,
                                   baud: 9600,
                                   data_bits: 8,
                                   stop_bits: 1,
                                   parity: SerialPort::EVEN)

      @serialport.read_timeout = 2000

      @status = :init
      @frame_id = 0
      @frame_acknowledged = false
    end

    def ack
      write_raw [Frame::ACKNOWLEDGE]
    end

    def acknowledged?
      acknowledged = @frame_acknowledged
      @frame_acknowledged = false
      acknowledged
    end

    def write_raw(bytes)
      @serialport.write(bytes.pack('C*'))
    end

    def frame_sequence
      @frame_id = (@frame_id + 1) % 256
    end

    def write_data(data)
      frame = [Frame::HEADER, frame_sequence, data.length]
      frame += data
      frame += [Frame.compute_checksum(frame)]
      write_raw frame
      @frame_acknowledged = false
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
                  @frame_acknowledged = true
                  :init
                else
                  :init
                end
      output
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
      when Frame::HEADER
        @frame += bytes
        :header
      when Frame::ACKNOWLEDGE
        :acknowledge
      else
        puts "Dropped byte: #{hex(bytes)}"
        :init
      end
    end

    def process_checksum
      process_bytes(1, :complete, :invalid_checksum) do |bytes|
        Frame.compute_checksum(@frame) == bytes.first
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
