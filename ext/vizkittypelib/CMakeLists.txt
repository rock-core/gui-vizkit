cmake_minimum_required(VERSION 2.6)
find_package(Rock)
rock_init(vizkit 1.0)
include(RockRuby)

find_package(Gem COMPONENTS rice)
pkg_check_modules(TYPELIB "rtt_typelib-${OROCOS_TARGET}")
pkg_check_modules(TYPELIBRUBY "typelib_ruby")
pkg_check_modules(QT "QtCore" REQUIRED)
include_directories(${QT_HEADER_DIR})

if (TYPELIB_FOUND AND TYPELIBRUBY_FOUND AND GEM_FOUND)
    rock_ruby_rice_extension(vizkittypelib MODULE
	MOC TypelibToQVariant.cpp
        DEPS_PKGCONFIG rtt_typelib-${OROCOS_TARGET} typelib_ruby)
    target_link_libraries(vizkittypelib
        ${QT_LIBRARIES} ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY} 
        ${GEM_LIBRARIES})

    rock_ruby_rice_extension(TypelibQtAdapter MODULE
	MOC TypelibQtAdapter.cpp
        DEPS_PKGCONFIG rtt_typelib-${OROCOS_TARGET} typelib_ruby)
    target_link_libraries(TypelibQtAdapter
        ${QT_LIBRARIES} ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY} 
        ${GEM_LIBRARIES})
else()
    if (NOT TYPELIB_FOUND)
        message(STATUS "cannot find typelib, the vizkit-ruby bridge is disabled")
    elseif (NOT TYPELIBRUBY_FOUND)
        message(STATUS "cannot find typelib's ruby bindings, the vizkit-ruby bridge is disabled")
    elseif (NOT GEM_FOUND)
        message(STATUS "cannot find the rice gem, the vizkit-ruby bridge is disabled")
    endif()
endif()
