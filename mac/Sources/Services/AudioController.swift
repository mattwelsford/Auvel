import AudioToolbox
import CoreAudio
import Foundation

/// Volume and mute of the default output device through CoreAudio (ADR-003).
@MainActor
final class AudioController {
    struct State: Equatable {
        var volume: Double = 0
        var muted = false
        var volumeSettable = false
        var outputName = ""
    }

    private(set) var state = State()
    var onChange: ((State) -> Void)?

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var systemListener: AudioObjectPropertyListenerBlock?

    private static var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.attachToDefaultDevice() }
        }
        systemListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultOutputAddress, .main, block)
        attachToDefaultDevice()
    }

    /// Sets volume, 0...1. Returns false if the device has no software volume.
    @discardableResult
    func setVolume(_ level: Double) -> Bool {
        guard state.volumeSettable else { return false }
        var value = Float32(min(max(level, 0), 1))
        let status = AudioObjectSetPropertyData(device, &Self.volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status == noErr, state.muted, value > 0 { setMuted(false) }
        refresh()
        return status == noErr
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard AudioObjectHasProperty(device, &Self.muteAddress) else { return false }
        var value: UInt32 = muted ? 1 : 0
        let status = AudioObjectSetPropertyData(device, &Self.muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        refresh()
        return status == noErr
    }

    private func attachToDefaultDevice() {
        for (address, block) in deviceListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, block)
        }
        deviceListeners.removeAll()

        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &Self.defaultOutputAddress, 0, nil, &size, &id)
        device = id

        for address in [Self.volumeAddress, Self.muteAddress] {
            var address = address
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(device, &address, .main, block) == noErr {
                deviceListeners.append((address, block))
            }
        }
        refresh()
    }

    private func refresh() {
        var next = State()
        next.outputName = deviceName() ?? "Output"

        var settable: DarwinBoolean = false
        if AudioObjectHasProperty(device, &Self.volumeAddress),
           AudioObjectIsPropertySettable(device, &Self.volumeAddress, &settable) == noErr {
            next.volumeSettable = settable.boolValue
            var volume = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &Self.volumeAddress, 0, nil, &size, &volume) == noErr {
                next.volume = Double(min(max(volume, 0), 1))
            }
        }
        if AudioObjectHasProperty(device, &Self.muteAddress) {
            var muted = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &Self.muteAddress, 0, nil, &size, &muted) == noErr {
                next.muted = muted != 0
            }
        }
        guard next != state else { return }
        state = next
        onChange?(next)
    }

    private func deviceName() -> String? {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &Self.nameAddress, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }
}
