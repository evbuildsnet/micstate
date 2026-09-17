import CoreAudio
import Foundation

/// Thin typed helpers over the C CoreAudio property API.
enum CoreAudio {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func get<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, as _: T.Type) -> T? {
        var address = address
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        return status == noErr ? pointer.move() : nil
    }

    static func getArray<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, of _: T.Type) -> [T] {
        var address = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
            initialized = status == noErr ? Int(size) / MemoryLayout<T>.stride : 0
        }
    }

    static func getString(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
        guard let cf = get(object, address, as: CFString?.self), let cf else { return nil }
        return cf as String
    }

    @discardableResult
    static func set(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: UInt32) -> Bool {
        var address = address
        var value = value
        return AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    static func isSettable(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return false }
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(object, &address, &settable)
        return settable.boolValue
    }

    /// Subscribes on the main queue. The returned token keeps the subscription alive; drop it to unsubscribe.
    static func listen(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        _ handler: @escaping () -> Void
    ) -> ListenerToken {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
        return ListenerToken(object: object, address: address, block: block)
    }

    final class ListenerToken {
        private let object: AudioObjectID
        private var address: AudioObjectPropertyAddress
        private let block: AudioObjectPropertyListenerBlock

        init(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
            self.object = object
            self.address = address
            self.block = block
        }

        deinit { AudioObjectRemovePropertyListenerBlock(object, &address, .main, block) }
    }
}
