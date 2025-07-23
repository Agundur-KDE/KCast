file(GLOB_RECURSE QML_FILES ../contents/ui/*.qml)

ecm_create_po_files(QML
    BASE_NAME kcast
    FILES ${QML_FILES}
    INSTALL_DESTINATION ${KDE_INSTALL_LOCALEDIR}
)