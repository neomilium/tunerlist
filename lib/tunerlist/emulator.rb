module TunerList
  class Emulator
    def initialize(port)
      @transceiver = TunerList::Transceiver.new port
    end

    private

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
