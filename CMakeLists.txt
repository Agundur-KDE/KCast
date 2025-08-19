cmake_minimum_required(VERSION 3.31)

project(plasma-desktop)

set(PROJECT_VERSION "6.3.80")

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

if(EXISTS "${CMAKE_SOURCE_DIR}/.git")
  include(KDEGitCommitHooks OPTIONAL)
endif()

include(ECMQmlModule)
include(ECMConfiguredInstall)

option(BUILD_KCM_MOUSE_X11 "Build the Mouse KCM's X11 backend" ON)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Quick
    QuickWidgets
    DBus
    Widgets
    # Svg
    #Concurrent
    #Core5Compat
    # Sql # kcms/activities

)

if (Qt6Gui_VERSION VERSION_GREATER_EQUAL "6.10.0")
    find_package(Qt6GuiPrivate ${REQUIRED_QT_VERSION} REQUIRED NO_MODULE)
endif()


find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
   # Auth
    #Crash
    Config
    I18n
    KCMUtils
    # NewStuff
    Notifications
    NotifyConfig
    # Attica
    # Runner
    GlobalAccel
    CoreAddons # KSharedDataCache required by KImageCache, KStringHandler required by FolderModel
    GuiAddons # KImageCache
    DBusAddons
    Config
    WidgetsAddons
    Codecs
    Package
    IconThemes
    XmlGui
    # Svg
)

option(BUILD_DOLPHIN_SERVICE_MENU "Install Dolphin service menu for KCast" ON)

if(BUILD_DOLPHIN_SERVICE_MENU)
    # Installiert nach /usr/share/kio/servicemenus (systemweit)
    install(FILES servicemenus/kcast_stream.desktop
            DESTINATION ${KDE_INSTALL_DATADIR}/kio/servicemenus)
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

ki18n_install(translate
    INSTALL_DESTINATION ${KDE_INSTALL_LOCALEDIR}
)


install(DIRECTORY contents/
    DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.kcast/
    FILES_MATCHING PATTERN "*.qml"
                   PATTERN "*.svg"
                   PATTERN "*.js"
                   PATTERN "*.json"
                   PATTERN "*.png"
)


add_subdirectory(package)

install(DIRECTORY package/ DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.kcast)
