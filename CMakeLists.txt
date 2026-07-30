cmake_minimum_required(VERSION 3.31)

project(KCast)

set(PROJECT_VERSION "0.3.0")
set(KF6_MIN_VERSION "6.10.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(FeatureSummary)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    I18n
)

find_package(KF6Kirigami ${KF6_MIN_VERSION} CONFIG)
set_package_properties(KF6Kirigami PROPERTIES
    TYPE RUNTIME
)

find_package(KF6QQC2DesktopStyle ${KF6_MIN_VERSION} CONFIG)
set_package_properties(KF6QQC2DesktopStyle PROPERTIES
    TYPE RUNTIME
)

option(BUILD_DOLPHIN_SERVICE_MENU "Install Dolphin service menu for KCast" ON)

if(BUILD_DOLPHIN_SERVICE_MENU)
    install(FILES servicemenus/kcast_stream.desktop
            DESTINATION ${KDE_INSTALL_DATADIR}/kio/servicemenus)
endif()

ki18n_install(translate
    INSTALL_DESTINATION ${KDE_INSTALL_LOCALEDIR}
)

install(FILES package/metadata.json DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.kcast)
install(DIRECTORY package/contents/ DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.kcast/contents)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
