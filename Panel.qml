import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.s-w-3.soundcore"
  ipcTarget: "io.github.s-w-3.soundcore"

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.s-w-3.soundcore"

  property var status: ({ connected: false })
  property var pendingBands: []
  property var draggingFlags: [false, false, false, false, false, false, false, false]
  readonly property bool anyDragging: draggingFlags.indexOf(true) !== -1

  readonly property bool connected: !!status.connected
  readonly property var schemaList: status.schema || []
  readonly property var values: status.values || {}
  readonly property string deviceName: status.name || "Soundcore"
  readonly property string batteryText: Model.batteryText(values)

  function categorySettings(catId) {
    for (var i = 0; i < schemaList.length; i++)
      if (schemaList[i].categoryId === catId) return schemaList[i].settings || []
    return []
  }

  function findSetting(catId, settingId) {
    var list = categorySettings(catId)
    for (var i = 0; i < list.length; i++)
      if (list[i].settingId === settingId) return list[i]
    return null
  }

  readonly property var ambientSetting: findSetting("soundModes", "ambientSoundMode")
  readonly property var ancSetting: findSetting("soundModes", "noiseCancelingMode")
  readonly property var presetSetting: findSetting("equalizer", "presetEqualizerProfile")
  readonly property var eqSetting: findSetting("equalizer", "volumeAdjustments")

  readonly property string ambientValue: values.ambientSoundMode || ""
  readonly property string ancValue: values.noiseCancelingMode || ""
  readonly property string presetValue: values.presetEqualizerProfile || ""

  readonly property bool hasSoundModes: !!ambientSetting
  readonly property bool hasEqualizer: !!eqSetting
  readonly property bool hasControls: hasSoundModes || hasEqualizer

  function ambientOptions() { return Model.buildOptions(ambientSetting) }
  function ancOptions() { return Model.buildOptions(ancSetting) }
  function presetOptions() { return Model.buildOptions(presetSetting) }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function refreshSoon() {
    refreshTimer.restart()
  }

  function updateStatus(raw) {
    var parsed = Model.parseStatus(raw)
    root.status = parsed
    var bands = parsed.connected && parsed.values ? parsed.values.volumeAdjustments : null
    if (Array.isArray(bands) && !root.anyDragging) root.pendingBands = bands.slice()
  }

  function setSetting(id, value) {
    if (!root.status.mac) return
    setProc.command = [root.pluginDir + "/soundcore-set", root.status.mac, id + "=" + value]
    setProc.running = true
  }

  function setDragging(index, dragging) {
    var next = draggingFlags.slice()
    next[index] = dragging
    draggingFlags = next
  }

  function bandValue(index) {
    return root.pendingBands.length > index ? root.pendingBands[index] : 0
  }

  function moveBand(index, rawValue) {
    var next = root.pendingBands.slice()
    next[index] = rawValue
    root.pendingBands = next
  }

  function commitBands() {
    setSetting("volumeAdjustments", Model.csvFromBands(root.pendingBands))
  }

  onOpenedChanged: if (opened) refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.pluginDir + "/soundcore-status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateStatus(text) }
  }

  Process {
    id: setProc
    onExited: root.refreshSoon()
  }

  Timer {
    id: refreshTimer
    interval: 500
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 12000
    running: !root.anyDragging
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋋"
    dimmed: !root.connected
    tooltipText: root.connected ? root.deviceName : "No Soundcore headphones connected"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: root.deviceName
            meta: root.connected ? Model.friendlyModel(root.status.model) : "Disconnected"
            detail: root.batteryText
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰋋"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
                opacity: root.connected ? 1.0 : 0.4
              }
            }
          }

          Text {
            visible: !root.connected
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Connect your Soundcore headphones over Bluetooth to control them here."
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: root.connected && !root.hasControls
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "This model doesn't have sound mode or equalizer controls in OpenSCQ30 yet."
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // ---------- Sound mode ----------
          PanelSeparator {
            visible: root.connected && root.hasSoundModes
            foreground: root.bar.foreground
          }

          Column {
            visible: root.connected && root.hasSoundModes
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SOUND MODE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ButtonGroup {
              width: parent.width
              options: root.ambientOptions()
              value: root.ambientValue
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(v) { root.setSetting("ambientSoundMode", v) }
            }

            Column {
              visible: !!root.ancSetting && root.ambientValue === "NoiseCanceling"
              width: parent.width
              spacing: Style.space(6)
              topPadding: Style.space(6)

              PanelSectionHeader {
                text: "NOISE CANCELING"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              ButtonGroup {
                width: parent.width
                options: root.ancOptions()
                value: root.ancValue
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onChanged: function(v) { root.setSetting("noiseCancelingMode", v) }
              }
            }
          }

          // ---------- Equalizer ----------
          PanelSeparator {
            visible: root.connected && root.hasEqualizer
            foreground: root.bar.foreground
          }

          Column {
            visible: root.connected && root.hasEqualizer
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "EQUALIZER PRESET"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Dropdown {
              width: parent.width
              showLabel: false
              options: root.presetOptions()
              value: root.presetValue
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onChanged: function(v) { root.setSetting("presetEqualizerProfile", v) }
            }

            PanelSectionHeader {
              text: "CUSTOM EQ"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              topPadding: Style.space(6)
            }

            Repeater {
              model: root.eqSetting ? root.eqSetting.setting.bandHz.length : 0

              Column {
                id: bandRow
                required property int index
                width: panelColumn.width
                spacing: Style.space(2)

                readonly property real fd: root.eqSetting.setting.fractionDigits
                readonly property real scale: Math.pow(10, fd)
                readonly property real rawValue: root.bandValue(index)

                Row {
                  width: parent.width

                  Text {
                    textFormat: Text.PlainText
                    text: Model.formatBandLabel(root.eqSetting.setting.bandHz[bandRow.index])
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: parent.width - dbLabel.implicitWidth
                  }

                  Text {
                    id: dbLabel
                    textFormat: Text.PlainText
                    text: (bandRow.rawValue / bandRow.scale).toFixed(bandRow.fd) + " dB"
                    color: Qt.darker(root.bar.foreground, 1.3)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                PanelSlider {
                  bar: root.bar
                  width: parent.width
                  minimum: root.eqSetting.setting.min
                  maximum: root.eqSetting.setting.max
                  step: 1
                  integer: true
                  value: bandRow.rawValue

                  onMoved: function(v) { root.moveBand(bandRow.index, v) }
                  onDraggingChanged: root.setDragging(bandRow.index, dragging)
                  onReleased: function(v) {
                    root.moveBand(bandRow.index, v)
                    root.commitBands()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
