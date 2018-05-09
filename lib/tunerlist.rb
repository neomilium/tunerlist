#!/usr/bin/env ruby

require 'serialport'
require 'pp'

def hex(data)
  if data.class == Array
    data.map do |b|
      b = b.ord if b.class == String
      "%02x" % b
    end
  else
    puts "Huh?: data is a #{data.class}"
  end
end

module TunerList
  class FrameCodec
    FRAME_HEADER = "\x3d"
    ACKNOWLEDGE  = "\xc5"
    
    def initialize(serialport)
      @serialport = serialport
      @frame = ''
      @status = :init
    end

    def self.compute_checksum(bytes)
      puts "compute_checksum: #{hex(bytes)}"
      checksum = 0x00
      bytes.each do |b|
        checksum ^= b
      end
      checksum
    end

    def ack
      @serialport.write ACKNOWLEDGE
    end

    def write_data(data)
      @frame_id = 0
      frame = [ FRAME_HEADER, @frame_id, data.length ]
      frame += data
      frame.map!{|b| b.ord}
      frame += [ FrameCodec::compute_checksum(frame) ]
      pp frame
      @serialport.write(frame.pack('C*'))
    end

    def write_payload(payload_type, payload)
      data = [ payload_type ]
      data += payload
      data.map!{|b| b.ord}
      write_data(data)
    end

    def read
      output = nil
      # puts "Status: #{@status.to_s}"
      @status = case @status
        when :init then
          byte = @serialport.read(1)
          if byte == FRAME_HEADER then
            @frame = FRAME_HEADER
            :header
          else
            puts "Dropped byte: #{byte[0].ord}" unless byte.nil?
            :init
          end
        when :header then
          frame_id = @serialport.read(1)
          @frame += frame_id
          frame_id.nil? ? :init : :id
        when :id then
          data_length = @serialport.read(1)
          @frame += data_length
          data = @serialport.read data_length[0].ord
          @frame += data
          :data
        when :data then
          checksum = @serialport.read(1)[0].ord
          if FrameCodec::compute_checksum(@frame.bytes) == checksum
            puts '\o/'
          end
          output = @frame
          :init
        else
          :init
        end
      output
    end
  end

  class HUEmulator
    # CDC
    BOOTING       = "\x11"
    STATUS        = "\x20"
    RANDOM_STATUS = "\x25"
    PLAYING       = "\x47"

    RANDOM_STATUS_ON  = "\x07"
    RANDOM_STATUS_OFF = "\x03"

    # HU
    NEXT_TRACK = "\x17"

    def initialize(port)
      @serialport = SerialPort.new(port, {
        baud: 9600,
        data_bits: 8,
        stop_bits: 1,
        parity: SerialPort::EVEN
      })
      
      @serialport.read_timeout = 2000
      @frame_codec = TunerList::FrameCodec.new @serialport
    end

    def run
      loop do
        @frame = @frame_codec.read
        process_frame unless @frame.nil?
      end
    end

    private
    def extract_data
      @frame[3..-1]
    end

    def int_to_bcd(i)
       s = i.to_s
       s.insert(0, '0') if s.length.odd?
       [s].pack('H*').unpack('C*')[0]
    end

    def bcd_to_int(bcd)
      ("%02x" % bcd).to_i 10
    end

    def send_next_track
      @frame_codec.write_payload(NEXT_TRACK, [ "\x01" ])
    end

    def process_frame
      @frame_codec.ack
      data = extract_data
      case data[0]
      when BOOTING then
      when STATUS then
        puts "STATUS: #{data[1].ord} #{data[2].ord} #{data[5].ord}"
      when RANDOM_STATUS then
        puts "RANDOM_STATUS: #{data[1] == RANDOM_STATUS_ON}"
      when PLAYING then
        status = {
          track_number:      bcd_to_int(data[1].ord),
          cd_time_hour:      bcd_to_int(data[3].ord),
          cd_time_minute:    bcd_to_int(data[4].ord),
          cd_time_second:    bcd_to_int(data[5].ord),
          cd_time_sector:    bcd_to_int(data[6].ord),
          track_time_hour:   bcd_to_int(data[7].ord),
          track_time_minute: bcd_to_int(data[8].ord),
          track_time_second: bcd_to_int(data[9].ord),
          track_time_sector: bcd_to_int(data[10].ord),
        }
        puts "PLAYING: #{status}"
        send_next_track
      else
        puts "Unknown data: #{hex(data)} (length: #{data.length})"
      end
    end
  end
end

