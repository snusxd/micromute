import Foundation
import CoreAudio

struct MicrophoneInputDevice: Equatable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

struct MicrophoneVolumeInfo: Equatable {
    let volume: Float      // 0.0 ... 1.0
    let isSettable: Bool
}

enum MicrophoneDeviceError: Error, LocalizedError {
    case osStatus(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case let .osStatus(status, context):
            return "\(context) failed with OSStatus=\(status)"
        }
    }
}

final class MicrophoneDeviceManager {
    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

    func listInputDevices() -> [MicrophoneInputDevice] {
        let ids = allDeviceIDs()
        var result: [MicrophoneInputDevice] = []
        result.reserveCapacity(ids.count)

        for id in ids {
            if inputChannelCount(deviceID: id) > 0 {
                let name = deviceName(deviceID: id) ?? "Unknown"
                let uid = deviceUID(deviceID: id) ?? "\(id)"
                result.append(.init(id: id, uid: uid, name: name))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func getDefaultInputDeviceID() throws -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(systemObjectID, &addr, 0, nil, &size, &deviceID)
        guard status == noErr else {
            throw MicrophoneDeviceError.osStatus(status, "AudioObjectGetPropertyData(default input device)")
        }

        return deviceID
    }

    func setDefaultInputDevice(deviceID: AudioDeviceID) throws {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var id = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectSetPropertyData(systemObjectID, &addr, 0, nil, size, &id)
        guard status == noErr else {
            throw MicrophoneDeviceError.osStatus(status, "AudioObjectSetPropertyData(default input device)")
        }
    }

    func volumeInfo(deviceID: AudioDeviceID) -> MicrophoneVolumeInfo? {
        let elements = volumeElements(deviceID: deviceID)
        guard !elements.isEmpty else { return nil }

        var values: [Float] = []
        values.reserveCapacity(elements.count)

        var anySettable = false

        for el in elements {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: el
            )

            if isPropertySettable(objectID: deviceID, address: &addr) {
                anySettable = true
            }

            var v = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &v)
            if status == noErr {
                values.append(Float(v))
            }
        }

        guard !values.isEmpty else { return nil }

        let avg = values.reduce(0, +) / Float(values.count)
        return MicrophoneVolumeInfo(volume: clamp01(avg), isSettable: anySettable)
    }

    func setVolume(deviceID: AudioDeviceID, volume: Float) throws {
        let elements = volumeElements(deviceID: deviceID)
        guard !elements.isEmpty else { return } // not supported

        let v = Float32(clamp01(volume))
        let size = UInt32(MemoryLayout<Float32>.size)

        var didSetAny = false
        var lastError: OSStatus = noErr

        for el in elements {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: el
            )

            guard isPropertySettable(objectID: deviceID, address: &addr) else { continue }

            var vv = v
            let status = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &vv)
            if status == noErr {
                didSetAny = true
            } else {
                lastError = status
            }
        }

        if !didSetAny && lastError != noErr {
            throw MicrophoneDeviceError.osStatus(lastError, "AudioObjectSetPropertyData(input volume)")
        }
    }

    func findDevice(byUID uid: String) -> AudioDeviceID? {
        listInputDevices().first(where: { $0.uid == uid })?.id
    }

    // MARK: - Internals

    private func allDeviceIDs() -> [AudioDeviceID] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let s1 = AudioObjectGetPropertyDataSize(systemObjectID, &addr, 0, nil, &size)
        guard s1 == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = Array(repeating: AudioDeviceID(0), count: count)

        let s2 = ids.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(systemObjectID, &addr, 0, nil, &size, bytes.baseAddress!)
        }

        guard s2 == noErr else { return [] }
        return ids
    }

    private func inputChannelCount(deviceID: AudioDeviceID) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let s1 = AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
        guard s1 == noErr, size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }

        let abl = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        let s2 = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, abl)
        guard s2 == noErr else { return 0 }

        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        var channels = 0
        for b in buffers {
            channels += Int(b.mNumberChannels)
        }
        return channels
    }

    private func deviceName(deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var cfStr: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &cfStr)
        guard status == noErr else { return nil }
        return cfStr as String
    }

    private func deviceUID(deviceID: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var cfStr: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &cfStr)
        guard status == noErr else { return nil }
        return cfStr as String
    }

    private func volumeElements(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        // Prefer Main element if supported; otherwise fall back to per-channel elements.
        if hasVolumeProperty(deviceID: deviceID, element: kAudioObjectPropertyElementMain) {
            return [kAudioObjectPropertyElementMain]
        }

        let channels = inputChannelCount(deviceID: deviceID)
        guard channels > 0 else { return [] }

        var els: [AudioObjectPropertyElement] = []
        els.reserveCapacity(channels)

        for ch in 1...channels {
            let el = AudioObjectPropertyElement(ch)
            if hasVolumeProperty(deviceID: deviceID, element: el) {
                els.append(el)
            }
        }

        return els
    }

    private func hasVolumeProperty(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        return AudioObjectHasProperty(deviceID, &addr)
    }

    private func isPropertySettable(objectID: AudioObjectID, address: inout AudioObjectPropertyAddress) -> Bool {
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func clamp01(_ v: Float) -> Float {
        if v < 0 { return 0 }
        if v > 1 { return 1 }
        return v
    }
}
