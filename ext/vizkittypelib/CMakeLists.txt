cmake_minimum_required(VERSION 2.6)
find_package(Rock)
rock_init(vizkit 1.0)
rock_feature(NOCURDIR)
set(RUBY_USE_PROJECT_INSTALL_PREFIX TRUE)
include(RockRuby)

rock_find_qt5()

find_package(Gem COMPONENTS rice)
pkg_check_modules(TYPELIB "rtt_typelib-${OROCOS_TARGET}")
pkg_check_modules(TYPELIBRUBY "typelib_ruby")

if (TYPELIB_FOUND AND TYPELIBRUBY_FOUND AND GEM_FOUND)
    rock_ruby_rice_extension(vizkittypelib MODULE
	MOC5 TypelibToQVariant.cpp
        DEPS_PKGCONFIG rtt_typelib-${OROCOS_TARGET} typelib_ruby)
    target_link_libraries(vizkittypelib
        Qt5::Core Qt5::Gui Qt5::Widgets
        ${GEM_LIBRARIES})

    rock_ruby_rice_extension(TypelibQtAdapter MODULE
	MOC5 TypelibQtAdapter.cpp
        DEPS_PKGCONFIG rtt_typelib-${OROCOS_TARGET} typelib_ruby)
    target_link_libraries(TypelibQtAdapter
        Qt5::Core Qt5::Gui Qt5::Widgets
        ${GEM_LIBRARIES})
else()
    if (NOT TYPELIB_FOUND)
        message(FATAL_ERROR "cannot find typelib")
    elseif (NOT TYPELIBRUBY_FOUND)
        message(FATAL_ERROR "cannot find typelib's ruby bindings")
    elseif (NOT GEM_FOUND)
        message(FATAL_ERROR "cannot find the rice gem")
    endif()
endif()
