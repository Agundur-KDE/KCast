cmake_minimum_required(VERSION 3.16)

project(KCastPlasmoid LANGUAGES CXX)

set(PROJECT_VERSION "0.2.0")

set(PROJECT_DEP_VERSION "6.2.90")
set(QT_MIN_VERSION "6.7.0")
set(KF6_MIN_VERSION "6.10.0")
set(ACCOUNTSQT_DEP_VERSION "1.13")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)
set(INSTALL_SDDM_THEME TRUE)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)
include(ECMGenerateExportHeader)
include(ECMInstallIcons)
include(ECMMarkAsTest)
include(ECMMarkNonGuiExecutable)
include(ECMOptionalAddSubdirectory)
include(ECMQtDeclareLoggingCategory)
include(ECMSetupVersion)
include(FeatureSummary)
include(CheckIncludeFiles)
include(KDEClangFormat)
include(KDEGitCommitHooks)
include(ECMQmlModule)
include(ECMConfiguredInstall)

option(BUILD_DOC "Whether to build the documentation" OFF)
option(BUILD_KCM_MOUSE_KWIN_WAYLAND "Build the Mouse KCM's KWin+Wayland backend" ON)
option(BUILD_KCM_MOUSE_X11 "Build the Mouse KCM's X11 backend" ON)
option(BUILD_KCM_TOUCHPAD_KWIN_WAYLAND "Build the Touchpad KCM's KWin+Wayland backend" ON)
option(BUILD_KCM_TOUCHPAD_X11 "Build the Touchpad KCM's X11 backend" ON)
option(BUILD_KCM_TABLET "Build the Tablet KCM" ON)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Quick
    QuickWidgets
    Widgets
    Svg
    Concurrent
    Core5Compat
)

if (Qt6Gui_VERSION VERSION_GREATER_EQUAL "6.10.0")
    find_package(Qt6GuiPrivate ${REQUIRED_QT_VERSION} REQUIRED NO_MODULE)
endif()

if(BUILD_KCM_TABLET)
    find_package(Qt6WaylandClient ${QT_MIN_VERSION} CONFIG REQUIRED)
endif()

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Auth
    Crash
    Config
    I18n
    KCMUtils
    Notifications
    NotifyConfig
    Attica
    Runner
    GlobalAccel
    CoreAddons # KSharedDataCache required by KImageCache, KStringHandler required by FolderModel
    GuiAddons # KImageCache
    Config
    WidgetsAddons
    Codecs
    Package
    IconThemes
    XmlGui
    Svg
)

find_package(Plasma5Support ${PROJECT_DEP_VERSION} REQUIRED)
find_package(Plasma ${PROJECT_DEP_VERSION} REQUIRED)
find_package(PlasmaQuick ${PROJECT_DEP_VERSION} REQUIRED)
find_package(PlasmaActivities ${PROJECT_DEP_VERSION} REQUIRED)
find_package(PlasmaActivitiesStats ${PROJECT_DEP_VERSION} REQUIRED)

if(BUILD_TESTING)
    find_package(Qt6Test ${QT_MIN_VERSION} CONFIG REQUIRED)
    include(ECMAddTests)
endif()


find_package(KF6Kirigami ${KF6_MIN_VERSION} CONFIG)
set_package_properties(KF6Kirigami PROPERTIES
    DESCRIPTION "A QtQuick based components set"
    PURPOSE "Required at runtime by many KCMs"
    TYPE RUNTIME
)


find_package(KF6KirigamiAddons 1.0.0 CONFIG)
set_package_properties(KF6KirigamiAddons PROPERTIES
    DESCRIPTION "Extra controls for Kirigami applications"
    PURPOSE "Required at runtime for Kickoff"
    TYPE RUNTIME
)

find_package(KF6QQC2DesktopStyle ${KF6_MIN_VERSION} CONFIG)
set_package_properties(KF6QQC2DesktopStyle PROPERTIES
    DESCRIPTION "QtQuickControls 2 style that uses QWidget's QStyle for painting"
    PURPOSE "Required at runtime by many KCMs"
    TYPE RUNTIME
)



find_package(X11)
set_package_properties(X11 PROPERTIES
    DESCRIPTION "X11 libraries"
    URL "https://www.x.org"
    PURPOSE "Required for building the X11 based workspace"
    TYPE REQUIRED
)

if(X11_FOUND)
  set(HAVE_X11 1)
endif()


install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/contents/ DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.kcast/contents PATTERN "CMakeLists.txt" EXCLUDE PATTERN "build" EXCLUDE PATTERN "*.o" EXCLUDE PATTERN "*.so" EXCLUDE)


add_subdirectory(plugin)
# plasma_install_package(package de.agundur.kcast)
