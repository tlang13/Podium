import Foundation

/// A device Podium knows how to identify, independent of whether emulation
/// is actually implemented for it yet.
struct SupportedDevice: Identifiable, Hashable {
    /// Apple's internal device identifier, e.g. "iPod4,1".
    let identifier: String
    /// Full marketing name, e.g. "iPod touch (4th generation)".
    let marketingName: String
    /// Short name used in compact UI, e.g. "iPod touch 4".
    let shortName: String

    var id: String { identifier }
}

/// The catalog of devices Podium currently recognizes.
///
/// This is intentionally narrow. Podium's first hardware target is the
/// iPod touch 4th generation; broadening this catalog is a deliberate
/// future step, not an oversight.
enum DeviceCatalog {
    static let iPodTouch4 = SupportedDevice(
        identifier: "iPod4,1",
        marketingName: "iPod touch (4th generation)",
        shortName: "iPod touch 4"
    )

    /// The iPhone 4 (GSM): the same A4 (S5L8930X) and 640x960 panel as the
    /// iPod touch 4, but with a different board (N90AP), 512 MB of RAM and,
    /// unlike the iPod, an iOS 7 release. Recognized so firmware for it can
    /// be identified; emulation of it is not implemented yet.
    static let iPhone4 = SupportedDevice(
        identifier: "iPhone3,1",
        marketingName: "iPhone 4 (GSM)",
        shortName: "iPhone 4"
    )

    static let all: [SupportedDevice] = [iPodTouch4, iPhone4]

    static func device(for identifier: String) -> SupportedDevice? {
        all.first { $0.identifier == identifier }
    }
}

/// The exact firmware Podium is built against during initial development.
/// Other builds/devices may parse successfully but are reported as
/// unsupported until they've been validated.
enum ReferenceFirmware {
    static let device = DeviceCatalog.iPodTouch4
    static let productVersion = "6.1.6"
    static let buildVersion = "10B500"
}

/// The iPhone 4 / iOS 7.1.2 firmware Podium is being ported to. Unlike
/// `ReferenceFirmware`, nothing treats this as compatible yet:
/// `FirmwareCompatibilityChecker` still accepts only `ReferenceFirmware`,
/// and there is no `KernelProfile` for this build. It exists so the port's
/// target is named in one place (see docs/IPHONE4_IOS7_PORT.md).
enum IPhone4iOS7Target {
    static let device = DeviceCatalog.iPhone4
    static let productVersion = "7.1.2"
    static let buildVersion = "11D257"
    /// The board whose device tree and kernelcache this device uses.
    static let boardName = "n90ap"
}
