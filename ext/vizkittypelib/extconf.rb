require 'rake'

name = "vizkittypelib"
ext_dir = "ext/vizkittypelib"
lib_dir = "lib/vizkit"
# Use absolute main package directory as starting point, since rake-compiler uses a build directory which depends on the system architecture and ruby version
#
# Adapt the target installation path for the ruby extension through the environment variable RUBY_CMAKE_INSTALL_PREFIX
main_dir = File.join(File.dirname(__FILE__),"..","..")
if prefix = ENV['RUBY_CMAKE_INSTALL_PREFIX']
    prefix = ENV['RUBY_CMAKE_INSTALL_PREFIX'].split(":").first
    prefix = File.absolute_path( File.join(main_dir, prefix) )
else
    prefix = File.join(main_dir,lib_dir)
end


orocos_target = ENV['OROCOS_TARGET'] || 'gnulinux'
FileUtils.rm_f "CMakeCache.txt"
if !system("which cmake")
    raise "cmake command is not available -- make sure cmake is properly installed"
end
if !system("cmake", "-DRUBY_PROGRAM_NAME=#{FileUtils::RUBY}", "-DCMAKE_INSTALL_PREFIX=#{prefix}", "-DOROCOS_TARGET=#{orocos_target}", "-DCMAKE_BUILD_TYPE=Debug", File.join(main_dir, ext_dir))
    raise "unable to configure the extension using CMake"
end
