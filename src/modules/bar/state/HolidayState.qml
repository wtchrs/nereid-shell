pragma Singleton

import QtQuick
import QtQml
import Quickshell
import qs.configs

Singleton {
    id: root

    readonly property var retryDelays: [1000, 2000, 4000]
    readonly property int retryCycleMinInterval: 30000

    property int openCycleCounter: 0
    property int requestGeneration: 0
    property var requestStates: ({})
    property var payloads: ({})
    property var holidaysByYear: ({})

    function countryCode() {
        return String(Config.clockPanel.holidayCountryCode || "").trim().toUpperCase()
    }

    function subdivisionCode() {
        return String(Config.clockPanel.holidaySubdivisionCode || "").trim().toUpperCase()
    }

    function endpointKey(year, endpoint) {
        return `${year}:${endpoint}`
    }

    function beginOpenCycle() {
        root.openCycleCounter += 1
        return root.openCycleCounter
    }

    function reset() {
        retryTimer.stop()
        root.requestGeneration += 1
        root.requestStates = ({})
        root.payloads = ({})
        root.holidaysByYear = ({})
    }

    function setRequestState(key, state) {
        const states = Object.assign({}, root.requestStates)
        states[key] = state
        root.requestStates = states
    }

    function setPayload(key, payload) {
        const nextPayloads = Object.assign({}, root.payloads)
        nextPayloads[key] = payload
        root.payloads = nextPayloads
    }

    function requestUrl(year, endpoint) {
        const country = encodeURIComponent(root.countryCode())
        if (endpoint === "v4")
            return `https://date.nager.at/api/v4/Holidays/${country}/${year}`

        return `https://date.nager.at/api/v3/PublicHolidays/${year}/${country}`
    }

    function ensureYears(years, openCycle) {
        const seen = ({})
        for (const value of years || []) {
            const year = Number(value)
            if (!isFinite(year) || seen[year])
                continue

            seen[year] = true
            root.ensureYear(year, openCycle)
        }
    }

    function ensureYear(year, openCycle) {
        if (root.countryCode() === "")
            return

        root.ensureEndpoint(year, "v3", openCycle)
        root.ensureEndpoint(year, "v4", openCycle)
    }

    function ensureEndpoint(year, endpoint, openCycle) {
        const key = root.endpointKey(year, endpoint)
        const state = root.requestStates[key]

        if (!state) {
            root.startEndpoint(year, endpoint, openCycle, 0)
            return
        }

        if (state.status === "success" || state.status === "loading"
                || state.status === "scheduled" || state.status === "permanent")
            return

        const cycleChanged = state.openCycle !== openCycle
        const intervalElapsed = Date.now() - Number(state.finishedAt || 0)
            >= root.retryCycleMinInterval
        if (state.status === "exhausted" && cycleChanged && intervalElapsed)
            root.startEndpoint(year, endpoint, openCycle, 0)
    }

    function normalizePayload(endpoint, payload) {
        const normalized = []
        for (const item of payload || []) {
            if (!item || !item.date || !item.name)
                continue

            normalized.push({
                date: String(item.date),
                name: String(item.name),
                localName: endpoint === "v3" ? String(item.localName || "") : "",
                national: endpoint === "v3" ? !!item.global : !!item.nationalHoliday,
                subdivisions: endpoint === "v3"
                    ? (Array.isArray(item.counties) ? item.counties : [])
                    : (Array.isArray(item.subdivisionCodes) ? item.subdivisionCodes : [])
            })
        }
        return normalized
    }

    function isRetryableStatus(status) {
        return status === 0 || status === 408 || status === 429 || status >= 500
    }

    function startEndpoint(year, endpoint, openCycle, attempt) {
        const key = root.endpointKey(year, endpoint)
        const generation = root.requestGeneration
        root.setRequestState(key, {
            status: "loading",
            year: year,
            endpoint: endpoint,
            openCycle: openCycle,
            attempt: attempt,
            finishedAt: 0,
            retryAt: 0
        })

        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (generation !== root.requestGeneration)
                return

            const status = Number(request.status || 0)
            if (status >= 200 && status < 300) {
                try {
                    const payload = JSON.parse(request.responseText)
                    if (!Array.isArray(payload))
                        throw new Error("response is not an array")

                    root.setPayload(key, root.normalizePayload(endpoint, payload))
                    root.setRequestState(key, {
                        status: "success",
                        year: year,
                        endpoint: endpoint,
                        openCycle: openCycle,
                        attempt: attempt,
                        finishedAt: Date.now(),
                        retryAt: 0
                    })
                    root.rebuildYear(year)
                    root.rescheduleRetryTimer()
                    return
                } catch (error) {
                    root.handleEndpointFailure(
                        year, endpoint, openCycle, attempt, true,
                        `invalid response: ${error}`
                    )
                    return
                }
            }

            root.handleEndpointFailure(
                year, endpoint, openCycle, attempt,
                root.isRetryableStatus(status),
                status === 0 ? "network error" : `HTTP ${status}`
            )
        }

        request.open("GET", root.requestUrl(year, endpoint), true)
        request.send()
    }

    function handleEndpointFailure(year, endpoint, openCycle, attempt, retryable, message) {
        const key = root.endpointKey(year, endpoint)
        if (retryable && attempt < root.retryDelays.length) {
            const retryAt = Date.now() + root.retryDelays[attempt]
            root.setRequestState(key, {
                status: "scheduled",
                year: year,
                endpoint: endpoint,
                openCycle: openCycle,
                attempt: attempt + 1,
                finishedAt: 0,
                retryAt: retryAt
            })
            root.rescheduleRetryTimer()
            return
        }

        root.setRequestState(key, {
            status: retryable ? "exhausted" : "permanent",
            year: year,
            endpoint: endpoint,
            openCycle: openCycle,
            attempt: attempt,
            finishedAt: Date.now(),
            retryAt: 0
        })
        console.warn(`holiday data ${endpoint} ${year}: ${message}`)
        root.rescheduleRetryTimer()
    }

    function rescheduleRetryTimer() {
        let earliest = 0
        const states = root.requestStates
        for (const key of Object.keys(states)) {
            const state = states[key]
            if (!state || state.status !== "scheduled")
                continue

            const retryAt = Number(state.retryAt || 0)
            if (retryAt > 0 && (earliest === 0 || retryAt < earliest))
                earliest = retryAt
        }

        if (earliest === 0) {
            retryTimer.stop()
            return
        }

        retryTimer.interval = Math.max(1, earliest - Date.now())
        retryTimer.restart()
    }

    function runScheduledRetries() {
        const now = Date.now()
        const states = root.requestStates
        const due = []

        for (const key of Object.keys(states)) {
            const state = states[key]
            if (state && state.status === "scheduled" && state.retryAt <= now)
                due.push(state)
        }

        for (const state of due) {
            root.startEndpoint(
                state.year, state.endpoint, state.openCycle, state.attempt
            )
        }
        root.rescheduleRetryTimer()
    }

    function matchesSubdivision(item) {
        const subdivision = root.subdivisionCode()
        if (item.national)
            return true
        if (subdivision === "")
            return false

        return item.subdivisions.some(code =>
            String(code || "").toUpperCase() === subdivision)
    }

    function rebuildYear(year) {
        const v3 = root.payloads[root.endpointKey(year, "v3")] || []
        const v4 = root.payloads[root.endpointKey(year, "v4")] || []
        const localNames = ({})
        const byDate = ({})

        for (const item of v3) {
            if (item.localName && !localNames[item.name])
                localNames[item.name] = item.localName
        }

        for (const item of v3.concat(v4)) {
            if (!root.matchesSubdivision(item))
                continue

            const name = item.localName || localNames[item.name] || item.name
            const names = byDate[item.date] || []
            if (!names.includes(name))
                names.push(name)
            byDate[item.date] = names
        }

        const nextYears = Object.assign({}, root.holidaysByYear)
        nextYears[year] = byDate
        root.holidaysByYear = nextYears
    }

    function dateKey(date) {
        if (!date || isNaN(date.getTime()))
            return ""

        const year = date.getFullYear()
        const month = String(date.getMonth() + 1).padStart(2, "0")
        const day = String(date.getDate()).padStart(2, "0")
        return `${year}-${month}-${day}`
    }

    function holidaysForDate(date) {
        const year = date && !isNaN(date.getTime()) ? date.getFullYear() : 0
        const byDate = root.holidaysByYear[year] || ({})
        return byDate[root.dateKey(date)] || []
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root.runScheduledRetries()
    }

    Connections {
        target: Config.clockPanel

        function onHolidayCountryCodeChanged() { root.reset() }
        function onHolidaySubdivisionCodeChanged() { root.reset() }
    }
}
