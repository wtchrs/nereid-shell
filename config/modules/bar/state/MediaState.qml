pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // Mpris is process-wide, while each screen owns its own bar and panel.
    // Keep the selected player and all control entry points here so every
    // screen observes and changes the same media state.
    property var players: Mpris.players?.values ?? []
    property MprisPlayer activeMedia: null
    property string activeMediaDbusName: ""

    function defaultMedia() {
        return root.players.find(player => player && player.isPlaying)
            || root.players.find(player => !!player)
            || null
    }

    function resolveActiveMedia() {
        const selected = root.players.find(player =>
            player && player.dbusName === root.activeMediaDbusName)
        if (selected) {
            root.activeMedia = selected
            return selected
        }

        // Keep the selected bus name while its player is temporarily absent.
        // A fallback keeps the bar usable, while a re-registered player with
        // the same name becomes active again.
        const fallback = root.defaultMedia()
        root.activeMedia = fallback
        if (!root.activeMediaDbusName && fallback)
            root.activeMediaDbusName = fallback.dbusName
        return fallback
    }

    function setActiveMedia(media) {
        if (!media)
            return false

        const dbusName = media.dbusName
        if (!dbusName)
            return false

        root.activeMedia = media
        root.activeMediaDbusName = dbusName
        return true
    }

    function togglePlaying(media) {
        if (!root.setActiveMedia(media) || !media.canTogglePlaying)
            return
        media.togglePlaying()
    }

    function previous(media) {
        if (!root.setActiveMedia(media) || !media.canGoPrevious)
            return
        media.previous()
    }

    function next(media) {
        if (!root.setActiveMedia(media) || !media.canGoNext)
            return
        media.next()
    }

    function seekTo(media, seconds) {
        if (!root.setActiveMedia(media) || !media.canSeek || !media.positionSupported)
            return

        const length = Number(media.length)
        const requested = Number(seconds)
        if (!isFinite(length) || length <= 0 || !isFinite(requested))
            return

        media.position = Math.max(0, Math.min(length, requested))
    }

    onPlayersChanged: root.resolveActiveMedia()

    Component.onCompleted: root.resolveActiveMedia()
}
