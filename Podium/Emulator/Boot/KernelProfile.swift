import Foundation

/// The facts about one exact kernelcache build that Podium's emulator
/// depends on and can't discover for itself: where `_panic`, `boot()` and
/// the dyld shared-region mapping syscall live, and where the kernel keeps
/// the timebase read loop that is run natively.
///
/// These are addresses inside a specific, decrypted kernelcache, so they
/// belong to a (device, build) pair and nothing else: a different iOS
/// version, or even a different device's kernelcache for the same iOS
/// version, moves every one of them. Keeping them in one value, rather
/// than as constants scattered through `EmulationSession` and
/// `KernelAcceleration`, is what lets a second target (the iPhone 4 on
/// iOS 7.1.2) be brought up by filling in a new profile instead of
/// editing the session.
///
/// A profile is looked up by `profile(forDevice:build:)`; a build with no
/// profile can't be booted, and callers should say so rather than fall
/// back to another build's addresses.
struct KernelProfile: Equatable {
    /// e.g. "iPod4,1" — the device whose kernelcache these addresses are in.
    let deviceIdentifier: String
    /// e.g. "10B500".
    let buildVersion: String

    /// `_panic` and the unexported `panic_context` (reached from exception
    /// handlers, jumping into `_panic`'s tail), each mapped to the register
    /// holding its format string.
    let panicEntries: [UInt32: Int]

    /// `boot(paniced, howto, command)`, where every shutdown and restart
    /// begins once launchd asks for one; `howto` bit 3 (`RB_HALT`) tells a
    /// shutdown from a restart. The run ends there: everything the kernel
    /// does after it — syncing and unmounting a root filesystem whose
    /// changes are discarded at power-off anyway, telling every driver —
    /// only takes time. A lot of it: by then the root filesystem's cached
    /// pages are going, and a launchd thread that wakes up faults on its own
    /// code, takes the signal, faults again in the handler, and crowds out
    /// the halt for a minute or more.
    let shutdownEntry: UInt32

    /// `shared_region_map_and_slide_np` (a syscall; 438 on this kernel, from
    /// `sysent`), which launchd's dyld calls once, early, to map the dyld
    /// shared cache: the slide it picked is the fourth word of the
    /// arguments (`r1 + 0xc`), and `QuartzCoreAcceleration` needs it.
    let sharedRegionEntry: UInt32

    /// `mach_absolute_time`'s read of the timebase (see
    /// `KernelAcceleration`). `nil` leaves the kernel's own code running,
    /// which is correct, just slower.
    let timebaseReadLoop: UInt32?

    /// iPod touch 4 (iPod4,1), iOS 6.1.6 (10B500): the one build Podium boots.
    static let iPodTouch4_10B500 = KernelProfile(
        deviceIdentifier: "iPod4,1",
        buildVersion: "10B500",
        panicEntries: [0x8001_7C10: 0, 0x8001_7F28: 2],
        shutdownEntry: 0x801D_F6E8,
        sharedRegionEntry: 0x8021_DC94,
        timebaseReadLoop: 0x8008_9608
    )

    // iPhone 4 (iPhone3,1), iOS 7.1.2 (11D257): deliberately absent. Its
    // addresses have to be found in that kernelcache (see
    // docs/IPHONE4_IOS7_PORT.md); inventing placeholders would make the
    // emulator set breakpoints at arbitrary kernel addresses.

    /// Every profile Podium has.
    static let all: [KernelProfile] = [iPodTouch4_10B500]

    static func profile(forDevice deviceIdentifier: String, build buildVersion: String) -> KernelProfile? {
        all.first { $0.deviceIdentifier == deviceIdentifier && $0.buildVersion == buildVersion }
    }
}
