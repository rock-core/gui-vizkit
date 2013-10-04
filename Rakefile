require 'rake'
require 'utilrb/doc/rake'

begin
    require 'hoe'
    namespace 'dist' do
        config = Hoe.spec('orocos.rb') do |p|
            self.developer("Alexander Duda", "alexander.duda@dfki.de")

            self.summary = 'Provides a Qt ruby based framework for visualisation of rock data items'
            self.description = ""
            self.urls = ["http://rock-robotics.org"]
            self.changes = ""

            self.extra_deps <<
                ['utilrb', ">= 1.1"] <<
                ['qtruby'] <<
                ['rake', ">= 0.8"]
        end
        Rake.clear_tasks(/dist:(re|clobber_|)docs/)
    end

rescue LoadError
    STDERR.puts "cannot load the Hoe gem. Distribution is disabled"
rescue Exception => e
    if e.message !~ /\.rubyforge/
        STDERR.puts "cannot load the Hoe gem, or Hoe fails. Distribution is disabled"
        STDERR.puts "error message is: #{e.message}"
    end
end

task :default => ["setup:ext"]
namespace :setup do
    desc "builds typlib qt extension"
    task :ext do
        builddir = File.join('ext', 'build')
        #prefix   = File.join(Dir.pwd, 'ext')
        prefix = ENV['CMAKE_PREFIX_PATH'].split(":").first

        FileUtils.mkdir_p builddir
        orocos_target = ENV['OROCOS_TARGET'] || 'gnulinux'
        Dir.chdir(builddir) do
            FileUtils.rm_f "CMakeCache.txt"
            if !system("cmake", "-DRUBY_PROGRAM_NAME=#{FileUtils::RUBY}", "-DCMAKE_INSTALL_PREFIX=#{prefix}", "-DOROCOS_TARGET=#{orocos_target}", "-DCMAKE_BUILD_TYPE=Debug", "..")
                raise "unable to configure the extension using CMake"
            end
            if !system("make") || !system("make", "install")
                STDERR.puts "unable to build the extension"
            end
        end
      #  FileUtils.ln_sf "../ext/rorocos_ext.so", "lib/rorocos_ext.so"
    end
end
task :setup => "setup:ext"
desc "remove by-products of setup"
task :clean do
    FileUtils.rm_rf "ext/build"
    FileUtils.rm_rf "ext/rorocos_ext.so"
    FileUtils.rm_rf "lib/rorocos_ext.so"
end

if Utilrb.doc?
    namespace 'doc' do
        Utilrb.doc 'api', :include => ['lib/**/*.rb'],
            :exclude => [],
            :target_dir => 'doc',
            :title => 'vizkit'
    end

    task 'redocs' => 'doc:reapi'
    task 'doc' => 'doc:api'
else
    STDERR.puts "WARN: cannot load yard or rdoc , documentation generation disabled"
end

