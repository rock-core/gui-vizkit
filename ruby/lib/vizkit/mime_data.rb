
module Vizkit
    def self.to_mime_data(obj)
        data = Hash.new
        if obj.is_a?(Orocos::Async::PortProxy) || obj.is_a?(Orocos::Async::SubPortProxy)
            data[:class] = :OutputPort
            data[:port] = obj.name.force_encoding("UTF-8")
            data[:task] = obj.task.name.force_encoding("UTF-8")
            data[:type] = obj.type.name.force_encoding("UTF-8")
        else
            return 0
        end
        val = Qt::MimeData.new
        val.setText data.to_yaml
        val
    end

    def self.from_mime_data(data)
        text = if data.respond_to? :text
                   data.text
               else
                   data
               end
        obj = YAML.load text

        if obj[:class] == :OutputPort
            
        end
    end
end
