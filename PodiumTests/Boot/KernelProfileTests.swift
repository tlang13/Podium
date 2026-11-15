import XCTest
@testable import Podium

final class KernelProfileTests: XCTestCase {
    func testReferenceProfileKeepsTheAddressesTheSessionUsedToHardcode() {
        // Moved out of EmulationSession/KernelAcceleration unchanged; if one
        // of these moves, the 10B500 boot has regressed.
        let profile = KernelProfile.iPodTouch4_10B500
        XCTAssertEqual(profile.panicEntries, [0x8001_7C10: 0, 0x8001_7F28: 2])
        XCTAssertEqual(profile.shutdownEntry, 0x801D_F6E8)
        XCTAssertEqual(profile.sharedRegionEntry, 0x8021_DC94)
        XCTAssertEqual(profile.timebaseReadLoop, 0x8008_9608)
    }

    func testReferenceProfileMatchesTheReferenceFirmware() {
        let profile = KernelProfile.iPodTouch4_10B500
        XCTAssertEqual(profile.deviceIdentifier, ReferenceFirmware.device.identifier)
        XCTAssertEqual(profile.buildVersion, ReferenceFirmware.buildVersion)
    }

    func testLookupRequiresBothDeviceAndBuild() {
        XCTAssertEqual(KernelProfile.profile(forDevice: "iPod4,1", build: "10B500"), KernelProfile.iPodTouch4_10B500)
        // 10B500 is also the build of other devices' iOS 6.1.6; their
        // kernelcaches are different files, so the build alone isn't enough.
        XCTAssertNil(KernelProfile.profile(forDevice: "iPhone2,1", build: "10B500"))
        XCTAssertNil(KernelProfile.profile(forDevice: "iPod4,1", build: "10B329"))
    }

    func testIPhone4IOS7HasNoProfileYet() {
        // Guards against anyone booting the port with another build's addresses.
        XCTAssertNil(KernelProfile.profile(forDevice: IPhone4iOS7Target.device.identifier,
                                           build: IPhone4iOS7Target.buildVersion))
    }

    func testIPhone4IsRecognizedButNotCompatible() {
        XCTAssertEqual(DeviceCatalog.device(for: "iPhone3,1"), DeviceCatalog.iPhone4)
        let metadata = FirmwareMetadata(
            supportedDeviceIdentifiers: ["iPhone3,1"],
            productVersion: IPhone4iOS7Target.productVersion,
            buildVersion: IPhone4iOS7Target.buildVersion,
            fileSizeBytes: 1,
            originalFileName: "iPhone3,1_7.1.2_11D257_Restore.ipsw",
            kernelCachePath: "kernelcache.release.n90",
            deviceTreePath: "Firmware/all_flash/all_flash.n90ap.production/DeviceTree.n90ap.img3"
        )
        XCTAssertEqual(FirmwareCompatibilityChecker.evaluate(metadata), .unsupportedDevice)
    }
}
