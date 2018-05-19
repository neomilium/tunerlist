# frozen_string_literal: true

module TunerList
  class Emulator
    def initialize(port)
      @transceiver = TunerList::Transceiver.new port

      @tx_datum = Queue.new
    end

    def run
      send_boot_sequence

      Thread.new { send_datum }

      loop do
        process_data @transceiver.receive
      end
    end

    private

    def send_datum
      loop do
        data = @tx_datum.pop
        begin
          send_and_wait_ack data
        rescue Timeout::Error
          puts "timeout for: #{Helper.const_prettify(@send_commands_from, data[0])}"
          @tx_datum.clear
          reset
          send_boot_sequence
        end
      end
    end

    def send(data)
      @tx_datum.push data
    end

    def send_boot_sequence
      boot_sequence.each do |data|
        send data
      end
    end

    def send_and_wait_ack(data)
      Timeout.timeout(2) do
        puts "send: #{Helper.const_prettify(@send_commands_from, data[0])}"
        @transceiver.send data
      end
    end

    def process_data(data)
      payload_type = data.shift
      payload = data[0..-2]

      if (const_name = Helper.find_const_name(@receive_commands_from, payload_type))
        method_name = "process_#{const_name.downcase}"
        if respond_to? method_name, true
          __send__(method_name, payload)
          puts "'#{method_name}' executed with payload: #{hex(payload)} (length: #{payload.length})"
        else
          puts "'#{method_name}' is not implemented (type: #{const_name}, payload: #{hex(payload)}, length: #{payload.length})"
        end
      else
        puts "Unknown payload_type: #{hex([payload_type])} with payload: #{hex(payload)} (length: #{payload.length})"
      end
    end
  end
end
