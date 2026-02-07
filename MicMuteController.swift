import Foundation
import CoreAudio
import AudioToolbox

final class MicMuteController {

  enum MicMuteError: Error, LocalizedError {
    case noDefaultInputDevice
    case osStatus(OSStatus, String)
    case deviceDoesNotSupportMuteOrVolume

    var errorDescription: String? {
      switch self {
      case .noDefaultInputDevice:
        return "No default input device"
      case let .osStatus(status, context):
        return "\(context) failed with OSStatus=\(status)"
      case .deviceDoesNotSupportMuteOrVolume:
        return "Default input device does not support mute or input volume control"
      }
    }
  }

  // Если устройство не поддерживает mute, будем “мутить” через volume=0 и восстанавливать последнее ненулевое.
  private var lastNonZeroVolumeByDevice: [AudioDeviceID: Float32] = [:]

  // MARK: - Public API (то, что ждёт AppDelegate)

  var isMuted: Bool {
    (try? currentIsMuted()) ?? false
  }

  func toggleMute() {
    do {
      try toggle()
    } catch {
      NSLog("MicMuteController.toggleMute error: \(error.localizedDescription)")
    }
  }

  // MARK: - Core logic

  private func currentIsMuted() throws -> Bool {
    let deviceID = try defaultInputDeviceID()

    if supportsMute(deviceID: deviceID) {
      return try getMute(deviceID: deviceID)
    }

    if supportsInputVolume(deviceID: deviceID) {
      let v = try getInputVolume(deviceID: deviceID)
      return v <= 0.000_1
    }

    throw MicMuteError.deviceDoesNotSupportMuteOrVolume
  }

  private func toggle() throws {
    let deviceID = try defaultInputDeviceID()

    if supportsMute(deviceID: deviceID) {
      let muted = try getMute(deviceID: deviceID)
      try setMute(deviceID: deviceID, muted: !muted)
      return
    }

    if supportsInputVolume(deviceID: deviceID) {
      let current = try getInputVolume(deviceID: deviceID)
      if current > 0.000_1 {
        lastNonZeroVolumeByDevice[deviceID] = current
        try setInputVolume(deviceID: deviceID, volume: 0.0)
      } else {
        let restore = lastNonZeroVolumeByDevice[deviceID] ?? 0.7
        try setInputVolume(deviceID: deviceID, volume: max(0.05, min(restore, 1.0)))
      }
      return
    }

    throw MicMuteError.deviceDoesNotSupportMuteOrVolume
  }

  // MARK: - Default input device

  private func defaultInputDeviceID() throws -> AudioDeviceID {
    var deviceID = AudioDeviceID(0)

    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultInputDevice),
      mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )

    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )

    guard status == noErr else {
      throw MicMuteError.osStatus(status, "AudioObjectGetPropertyData(default input device)")
    }
    guard deviceID != 0 else {
      throw MicMuteError.noDefaultInputDevice
    }

    return deviceID
  }

  // MARK: - Mute property

  private func supportsMute(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyMute),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )
    return AudioObjectHasProperty(deviceID, &address)
  }

  private func getMute(deviceID: AudioDeviceID) throws -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyMute),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )

    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
    guard status == noErr else {
      throw MicMuteError.osStatus(status, "AudioObjectGetPropertyData(mute)")
    }

    return value != 0
  }

  private func setMute(deviceID: AudioDeviceID, muted: Bool) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyMute),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )

    var value: UInt32 = muted ? 1 : 0
    let size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
    guard status == noErr else {
      throw MicMuteError.osStatus(status, "AudioObjectSetPropertyData(mute)")
    }
  }

  // MARK: - Input volume property (fallback)

  private func supportsInputVolume(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )
    return AudioObjectHasProperty(deviceID, &address)
  }

  private func getInputVolume(deviceID: AudioDeviceID) throws -> Float32 {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )

    var value: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
    guard status == noErr else {
      throw MicMuteError.osStatus(status, "AudioObjectGetPropertyData(input volume)")
    }

    return value
  }

  private func setInputVolume(deviceID: AudioDeviceID, volume: Float32) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )

    var value = max(0.0, min(volume, 1.0))
    let size = UInt32(MemoryLayout<Float32>.size)

    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
    guard status == noErr else {
      throw MicMuteError.osStatus(status, "AudioObjectSetPropertyData(input volume)")
    }
  }
}
