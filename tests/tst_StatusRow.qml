import QtQuick
import QtTest

import ".."

Item {
  id: root
  width: 420
  height: 160

  Component {
    id: statusRowComponent
    StatusRow {
      width: 380
      label: qsTr("Evercount")
      value: qsTr("Healthy")
      detail: qsTr("Last sync available")
      positive: true
      foreground: "#202020"
      dim: "#707070"
      positiveColor: "#008000"
      urgentColor: "#c00000"
      fontFamily: "sans-serif"
      rowSpacing: 3
      labelGap: 8
      bodyFontSize: 14
      captionFontSize: 11
    }
  }

  TestCase {
    name: "StatusRowTests"
    when: windowShown

    function test_providerStateProperties() {
      let row = createTemporaryObject(statusRowComponent, root)
      verify(!!row, "Component exists")
      compare(row.label, qsTr("Evercount"))
      compare(row.value, qsTr("Healthy"))
      compare(row.detail, qsTr("Last sync available"))
      compare(row.positive, true)
      compare(row.urgent, false)
    }

    function test_urgentState() {
      let row = createTemporaryObject(statusRowComponent, root)
      verify(!!row, "Component exists")
      row.positive = false
      row.urgent = true
      row.value = qsTr("Unavailable")
      compare(row.positive, false)
      compare(row.urgent, true)
      compare(row.value, qsTr("Unavailable"))
    }
  }
}
