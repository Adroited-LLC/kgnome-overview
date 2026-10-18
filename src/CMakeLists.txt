# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
ecm_add_qml_module(kgnomeoverviewplugin
    URI org.kgnome.overview
    VERSION 1.0
    GENERATE_PLUGIN_SOURCE
    DEPENDENCIES QtQuick
)

target_sources(kgnomeoverviewplugin PRIVATE
    appsmodel.cpp appsmodel.h
    launcher.cpp launcher.h
    iconresolver.cpp iconresolver.h
)

target_link_libraries(kgnomeoverviewplugin PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
    KF6::Service KF6::CoreAddons KF6::ConfigCore
)

ecm_finalize_qml_module(kgnomeoverviewplugin DESTINATION ${KDE_INSTALL_QMLDIR})
