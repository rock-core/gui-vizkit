require 'rake'
begin
    require 'hoe'
    Hoe::plugin :yard

    hoe_spec = Hoe.spec('vizkit') do |p|
        self.version = '0.1'
        self.developer("Alexander Duda", "alexander.duda@dfki.de")

        self.summary = 'Provides a Qt ruby based framework for visualisation of rock data items'
        self.readme_file = FileList['README*'].first
        self.description = paragraphs_of(history_file, 3..5).join("\n\n")
        self.urls = ["http://rock-robotics.org"]

        self.extra_deps <<
            ['utilrb', ">= 1.1"] <<
            ['qtruby'] <<
            ['rake', ">= 0.8"] <<
            ["rake-compiler",   "~> 0.8.0"] <<
            ["hoe-yard",   ">= 0.1.2"]
    end
    Rake.clear_tasks(/default/)

    # Making sure that native extension will be build with gem
    require 'rubygems/package_task'
    Gem::PackageTask.new(hoe_spec.spec) do |pkg|
        pkg.need_zip = true
        pkg.need_tar = true
    end

    # Leave in top level namespace to allow rake-compiler to build native gem: 'rake native gem'
    require 'rake/extensiontask'
    desc "builds Vizkit's Typelib - C extension"
    vizkitypelib_task = Rake::ExtensionTask.new('vizkittypelib', hoe_spec.spec) do |ext|
        # Same info as in ext/rocoros/extconf.rb where cmake
        # is used to generate the Makefile
        ext.name = "vizkittypelib"
        ext.ext_dir = "ext/vizkittypelib"
        ext.lib_dir = "lib/vizkit"
        ext.gem_spec = hoe_spec.spec
        ext.source_pattern = "*.{c,cpp,cc}"

        if not Dir.exists?(ext.tmp_dir)
            FileUtils.mkdir_p ext.tmp_dir
        end
    end

    typelib_qt_adapter_task = Rake::ExtensionTask.new('typelib_qt_adapter', hoe_spec.spec) do |ext|
        # Same info as in ext/rocoros/extconf.rb where cmake
        # is used to generate the Makefile
        ext.name = "TypelibQtAdapter"
        ext.ext_dir = "ext/vizkittypelib"
        ext.lib_dir = "lib/vizkit"
        ext.gem_spec = hoe_spec.spec
        ext.source_pattern = "*.{c,cpp,cc}"

        if not Dir.exists?(ext.tmp_dir)
            FileUtils.mkdir_p ext.tmp_dir
        end
    end

    task :default => :compile
    task :doc => :yard
    task :docs => :yard
    task :redoc => :yard
    task :redocs => :yard

rescue LoadError
    STDERR.puts "cannot load the Hoe gem. Distribution is disabled"
rescue Exception => e
    if e.message !~ /\.rubyforge/
        STDERR.puts "cannot load the Hoe gem, or Hoe fails. Distribution is disabled"
        STDERR.puts "error message is: #{e.message}"
    end
end


