module TunerList
  class Emulator
    def initialize(port)
      @transceiver = TunerList::Transceiver.new port

      @status = :init
    end

    def run
      loop do
        puts @status
        @status = case @status
                  when :init
                    send_boot_sequence ? :running : :init
                  when :running
                    status = :running
                    begin
                      Timeout.timeout(2) { process_data @transceiver.receive }
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

    def send_boot_sequence
      begin
        boot_sequence.each do |frame|
          send_and_wait_ack frame
        end
      rescue Timeout::Error
        puts 'timeout'
        return false
      end
      true
    end

    def send_and_wait_ack(data)
      Timeout.timeout(2) do
        @transceiver.send data
      end
    end

    def process_data(data)
      payload_type = data.shift
      payload = data[0..-2]

      if (const_name = Helper.find_const_name(@supported_commands, payload_type))
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
