import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  property var controller: null
  property int attempts: 0

  function fail(message) {
    console.error("QML check failed:", message)
    Qt.exit(1)
  }

  function checkFlexSection() {
    const section = flexComponent.createObject(root)
    if (!section) return fail("could not create FlexSection")
    if (section.expanded || section.actionCount !== 1)
      return fail("flex targets must start behind one action")

    let redeemed = ""
    section.redeem.connect(function(target) { redeemed = target })
    section.moveCursor(1)
    section.activateCursor()
    if (!section.expanded || section.cursorIndex !== 1)
      return fail("the flex action did not reveal and select its first target")

    section.activateCursor()
    if (redeemed !== "steam" || section.expanded)
      return fail("the selected target was not redeemed and collapsed")
    section.destroy()
  }

  Component {
    id: controllerComponent
    Plugin.SundownController {
      panelOpen: true
      sundownCommand: "/definitely-missing/sundown"
    }
  }

  Component {
    id: flexComponent
    Plugin.FlexSection {
      width: 380
      status: ({
        flex: {
          enabled: true,
          pass_seconds: 900,
          remaining_uses: 1,
          eligible: ["steam", "web:social"],
          redemptions: []
        },
        steam: { name: "gaming" },
        web: { rules: [{ name: "social" }] },
        apps: { groups: [] }
      })
    }
  }

  Timer {
    interval: 25
    running: true
    repeat: true
    onTriggered: {
      root.attempts++
      if (root.controller.statusKnown && root.controller.reportKnown) {
        if (root.controller.available
            || root.controller.statusError !== qsTr("Sundown is not available")
            || root.controller.reportError !== qsTr("Could not load Screen Time history"))
          return root.fail("failed commands did not settle into their error states")
        root.checkFlexSection()
        console.log("QML checks passed")
        Qt.quit()
      } else if (root.attempts >= 200) {
        root.fail("controller checks timed out")
      }
    }
  }

  Component.onCompleted: {
    controller = controllerComponent.createObject(root)
    if (!controller) fail("could not create SundownController")
  }
}
