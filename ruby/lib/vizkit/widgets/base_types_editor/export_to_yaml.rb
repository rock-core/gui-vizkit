class ExportToYaml
    def initialize(parent = nil)
    end

    def config(object,options=Hash.new)
        sample = if object.respond_to? :reader
                     object.reader.read
                 else
                     object
                 end
        if !sample
            Vizkit.warn "Cannot export sample to YAML: There is currently no sample available!"
        else
            @@file_path = Qt::FileDialog::getSaveFileName(nil,"Save Type to YAML",@@file_path,"YAML-File (*.yml)")
            if @@file_path
                temp = if sample.is_a?(Typelib::Type)
                           Orocos::TaskConfigurations::typelib_to_yaml_value(sample)
                       else
                           sample.to_yaml
                       end
                File.open(@@file_path, 'w') do |io|
                    io.write(YAML.dump(temp))
                end
            end
        end
        :do_not_connect
    end

    def pretty_print(pp) 
        pp.text "=========================================================="
        pp.breakable
        pp.text "Vizkit Export Widget: #{self.class.name}"
        pp.breakable

        pp.text "call config(sample) or config(port) to save the current sample to an YAML file."
        pp.breakable 
    end

    @@file_path ||= ENV["HOME"]
end

Vizkit::UiLoader.register_ruby_widget "ExportToYaml", ExportToYaml.method(:new)
Vizkit::UiLoader.register_widget_for("ExportToYaml", Typelib::Type) { }
