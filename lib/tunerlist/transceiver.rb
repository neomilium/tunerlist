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

      @serialport.read_timeout = 200
      @serialport.flush_input

      @status = :init

      @rx_queue = Queue.new
      @ack_queue = Queue.new

      @tx_frame_id = 0
      @tx_queue = Queue.new

      Thread.abort_on_exception = true
      Thread.report_on_exception = true
      Thread.new do
        loop { process }
      end
    end

    def receive
      @rx_queue.pop
    end

    def send(data)
      @ack_queue.clear
      @tx_queue.push data
      puts 'data pushed to queue, waiting ACK…'
      @ack_queue.pop
    end

    private

    def write(bytes)
      @serialport.write(bytes.pack('C*'))
    end

    def read(count)
      string = @serialport.read(count)
      return nil if string.nil?
      string.bytes
    end

    def ack
      write [Frame::ACKNOWLEDGE]
    end

    def process
      # puts "Transceiver status: #{@status}"
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
                  ack
                  @rx_queue << @frame[2..-2]
                  :init
                when :invalid_checksum
                  puts 'Checksum is invalid'
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
        Frame.compute_checksum(@frame) == bytes.first
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

    def frame_sequence
      @tx_frame_id = (@tx_frame_id + 1) % 256
    end

    def write_data(data)
      frame = [Frame::HEADER, frame_sequence, data.length]
      frame += data
      frame += [Frame.compute_checksum(frame)]
      write frame
    end
  end
end
