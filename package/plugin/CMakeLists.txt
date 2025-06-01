cmake_minimum_required(VERSION 3.16)
project(KCastPlugin LANGUAGES CXX)

# Benötigte Qt6‐Komponenten
find_package(Qt6 6.9 REQUIRED COMPONENTS Core Qml DBus)
# Für ecm_add_qml_module
find_package(ECM 5.0 REQUIRED NO_MODULE)

# Hiermit wird die QML‐Plugin‐Registrierungsdatei erzeugt:
ecm_add_qml_module(kcastplugin
    URI de.agundur.kcast
    VERSION 2.0
    GENERATE_PLUGIN_SOURCE
)

# Füge die C++‐Quelldatei(n) hinzu:
target_sources(kcastplugin PRIVATE
    kcastinterface.cpp
)

# Linke gegen Qt6::Core, Qt6::Qml und Qt6::DBus:
target_link_libraries(kcastplugin PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::DBus
)

# Modul fertigstellen
ecm_finalize_qml_module(kcastplugin)
