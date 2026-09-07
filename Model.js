function parseStatus(raw) {
  try {
    var parsed = JSON.parse(raw || "{}")
    if (!parsed || typeof parsed !== "object") return { connected: false }
    return parsed
  } catch (e) {
    return { connected: false }
  }
}

function buildOptions(setting) {
  if (!setting || !setting.setting || !Array.isArray(setting.setting.options)) return []
  var options = setting.setting.options
  var labels = setting.setting.localizedOptions || options
  var list = []
  for (var i = 0; i < options.length; i++) {
    list.push({
      value: String(options[i]),
      label: String(labels[i] !== undefined ? labels[i] : options[i])
    })
  }
  return list
}

function formatBandLabel(hz) {
  var n = Number(hz) || 0
  if (n >= 1000) {
    var khz = Math.round(n / 100) / 10
    return khz + "kHz"
  }
  return n + "Hz"
}

function csvFromBands(bands) {
  var parts = []
  for (var i = 0; i < bands.length; i++) {
    parts.push(String(Math.round(Number(bands[i]) || 0)))
  }
  return parts.join(",")
}

function friendlyModel(model) {
  var known = {
    "SoundcoreA3028": "Life Q30",
    "SoundcoreA3948": "A20i"
  }
  return known[model] || model || "Unknown model"
}

function batteryText(values) {
  if (!values) return ""
  var parts = []
  for (var key in values) {
    if (!Object.prototype.hasOwnProperty.call(values, key)) continue
    if (key.toLowerCase().indexOf("battery") === -1) continue
    var label = key.replace(/^battery/i, "").replace(/([A-Z])/g, " $1").trim()
    parts.push((label ? label + " " : "") + values[key])
  }
  return parts.join(" · ")
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    buildOptions: buildOptions,
    formatBandLabel: formatBandLabel,
    csvFromBands: csvFromBands,
    friendlyModel: friendlyModel,
    batteryText: batteryText
  }
}
