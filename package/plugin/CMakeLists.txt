ecm_add_qml_module(kcastplugin
    URI de.agundur.kcast
    VERSION 0.2.0
    GENERATE_PLUGIN_SOURCE
)
target_sources(kcastplugin PRIVATE
    kcastinterface.cpp
)

target_link_libraries(kcastplugin PRIVATE
    Qt6::Core
    Qt6::Qml
)
ecm_finalize_qml_module(kcastplugin)
