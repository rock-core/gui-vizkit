begin
require 'simplecov'
rescue Exception
    puts "!!! Cannot load simplecov. Coverage is disabled !!!"
end

def start_simple_cov(name)
    if defined? SimpleCov
        if !defined? @@simple_cov_started
            puts name
            SimpleCov.command_name name
            @@simple_cov_started = true
            SimpleCov.root(File.join(File.dirname(__FILE__),".."))
            SimpleCov.start do 
                add_group "Vizkit.rb" do |src|
                    nil != (src.filename =~ /lib\/vizkit\/\w*.rb$/)
                end
                add_group "C++ Widget Extension","lib/vizkit/cplusplus_extensions"
                add_group "Buildin Ruby Widgets", "lib/vizkit/widgets"
            end
        end
    end
end
