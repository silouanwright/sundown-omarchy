pragma ComponentBehavior: Bound

import QtQuick
import QtTest

import ".."

Item {
  id: root
  width: 240
  height: 240

  QtObject {
    id: controller
    property bool reportBusy: false
    property bool reportEverLoaded: false
    property string reportError: ""
    property var report: ({
      end_date: "",
      recorded_days: 0,
      days: [],
      totals: { steam_seconds: 0, web_seconds: {}, app_seconds: {} }
    })
  }

  Component {
    id: historyStateComponent
    HistoryState {
      reportEverLoaded: controller.reportEverLoaded
      reportBusy: controller.reportBusy
      reportError: controller.reportError
      recordedDays: Number(controller.report.recorded_days || 0)
    }
  }

  TestCase {
    name: "HistoryStateTests"
    when: windowShown

    function init() {
      controller.reportBusy = false
      controller.reportEverLoaded = false
      controller.reportError = ""
      controller.report = {
        end_date: "",
        recorded_days: 0,
        days: [],
        totals: { steam_seconds: 0, web_seconds: {}, app_seconds: {} }
      }
    }

    function test_initialLoadingState() {
      controller.reportBusy = true
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "loading")
      compare(history.showHistoryContent, false)
      compare(history.stateTitle, qsTr("Loading Screen Time history…"))
    }

    function test_firstLoadErrorState() {
      controller.reportError = qsTr("Could not load Screen Time history")
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "error")
      compare(history.showHistoryContent, false)
      compare(history.stateTitle, qsTr("Could not load Screen Time history"))
    }

    function test_retryAfterFirstErrorReturnsToLoading() {
      controller.reportError = qsTr("Could not load Screen Time history")
      controller.reportBusy = true
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "loading")
      compare(history.showHistoryContent, false)
      compare(history.stateTitle, qsTr("Loading Screen Time history…"))
    }

    function test_validEmptyState() {
      controller.reportEverLoaded = true
      controller.report = {
        end_date: "2026-09-02",
        recorded_days: 0,
        days: [],
        totals: { steam_seconds: 0, web_seconds: {}, app_seconds: {} }
      }
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "empty")
      compare(history.showHistoryContent, false)
      compare(history.stateTitle, qsTr("No recorded days yet"))
    }

    function test_loadedContentState() {
      prepareLoadedReport()
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "content")
      compare(history.showHistoryContent, true)
      compare(history.showRefreshStatus, false)
    }

    function test_refreshingPreservesContent() {
      prepareLoadedReport()
      controller.reportBusy = true
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "content")
      compare(history.showHistoryContent, true)
      compare(history.showRefreshStatus, true)
      compare(history.refreshStatusText, qsTr("Refreshing history…"))
    }

    function test_refreshErrorMarksLastGoodContent() {
      prepareLoadedReport()
      controller.reportError = qsTr("Could not refresh history")
      let history = createTemporaryObject(historyStateComponent, root)
      verify(!!history, "Component exists")
      compare(history.viewState, "content")
      compare(history.showHistoryContent, true)
      compare(history.showRefreshStatus, true)
      compare(history.refreshStatusText,
        qsTr("%1 · showing the last update").arg(controller.reportError))
    }

    function prepareLoadedReport() {
      controller.reportEverLoaded = true
      controller.report = {
        end_date: "2026-09-02",
        recorded_days: 1,
        days: [],
        totals: { steam_seconds: 600, web_seconds: {}, app_seconds: {} }
      }
    }
  }
}
