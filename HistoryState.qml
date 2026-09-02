import QtQuick

QtObject {
  id: root

  required property bool reportEverLoaded
  required property bool reportBusy
  required property string reportError
  required property int recordedDays

  readonly property bool hasRecordedDays: root.reportEverLoaded && root.recordedDays > 0
  readonly property string viewState: {
    if (!root.reportEverLoaded) {
      if (root.reportBusy) return "loading"
      return root.reportError !== "" ? "error" : "loading"
    }
    return root.hasRecordedDays ? "content" : "empty"
  }
  readonly property bool showHistoryContent: root.viewState === "content"
  readonly property bool showRefreshStatus: root.reportEverLoaded
    && (root.reportBusy || root.reportError !== "")
  readonly property string refreshStatusText: {
    if (root.reportBusy) return qsTr("Refreshing history…")
    if (root.reportError !== "")
      return qsTr("%1 · showing the last update").arg(root.reportError)
    return ""
  }
  readonly property string stateTitle: {
    if (root.viewState === "loading") return qsTr("Loading Screen Time history…")
    if (root.viewState === "error") return root.reportError
    if (root.viewState === "empty") return qsTr("No recorded days yet")
    return ""
  }
  readonly property string stateDetail: {
    if (root.viewState === "error") return qsTr("Press R to try again.")
    if (root.viewState === "empty")
      return qsTr("Usage will appear here after Sundown records its first day.")
    return ""
  }
}
