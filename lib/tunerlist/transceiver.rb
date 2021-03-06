#!/usr/bin/env ruby
# frozen_string_literal: true

require 'serialport'

def hex(data)
  return nil unless data
  data.map do |b|
    format('%02x', b)
  end
end

module TunerList
  module Frame
    HEADER = 0x3d
    ACKNOWLEDGE = 0xc5

    def self.compute_checksum(bytes)
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

      @serialport.flush_input

      @status = :init

      @rx_frame_id = 0
      @rx_queue = Queue.new
      @ack_queue = Queue.new

      @tx_frame_id = 0
      @tx_queue = Queue.new

      Thread.abort_on_exception = true
      # Thread.report_on_exception = true
      Thread.new do
        loop { process }
      end
    end

    def receive
      @rx_queue.pop
    end

    def send(data)
      @tx_queue.push data
      @ack_queue.pop
    end

    private

    def write(bytes)
      @serialport.write(bytes.pack('C*'))
    end

    def read(count)
      set_timeout count
      string = @serialport.read(count)
      return nil if string.nil?
      string.bytes
    end

    def ack
      write [Frame::ACKNOWLEDGE]
    end

    def set_timeout(count)
      @serialport.read_timeout = 50 + count * 10
    end

    def process
      # puts "Transceiver status: #{@status}, #{hex(@frame)}"
      @status = case @status
                when :init
                  @frame = []
                  :ready
                when :idle
                  write_data(@tx_queue.pop) unless @tx_queue.empty?
                  :ready
                when :ready
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
                  process_complete
                  :init
                when :invalid_checksum
                  puts "Checksum is invalid for: #{hex(@frame)}"
                  :init
                when :acknowledge then
                  @ack_queue << true
                  :init
                else
                  raise 'You should not be here!'
                end
    end

    def process_first_byte
      bytes = read(1)
      return :idle if bytes.nil?
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
        computed = Frame.compute_checksum(@frame)
        received = bytes.first
        # puts "received = #{hex([received])}, #{hex([computed])}" unless (computed == received)
        computed == received
      end
    end

    def process_bytes(count, success, failure = :init)
      bytes = read(count)
      return failure if bytes.nil?

      result = block_given? ? yield(bytes) : true

      if result == true
        @frame += bytes
        return success
      end
      failure
    end

    def process_complete
      ack
      @rx_queue << @frame[2..-2] unless @frame[1] == @rx_frame_id
      @rx_frame_id = @frame[1]
    end

    def frame_sequence
      @tx_frame_id = (@tx_frame_id + 1) % 256
    end

    def write_data(data)
      # puts "write_data: #{hex(data)}"
      frame = [Frame::HEADER, frame_sequence, data.length]
      frame += data
      frame += [Frame.compute_checksum(frame)]
      write frame
    end
  end
end
