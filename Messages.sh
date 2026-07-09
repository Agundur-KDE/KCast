#!/usr/bin/env bash
# Extracts translatable strings from the QML sources into translate/kcast.pot.
$XGETTEXT $(find package/contents -name '*.qml') -o translate/kcast.pot \
    --from-code=UTF-8 \
    --language=C++ \
    --keyword=i18n --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
    --package-name=kcast
