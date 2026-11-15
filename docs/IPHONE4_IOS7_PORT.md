# Porting Podium to iPhone 4 / iOS 7.1.2

Target: **iPhone 4 (GSM), `iPhone3,1`, iOS 7.1.2, build `11D257`**, board `n90ap`
(codename Sochi). The IPSW is `iPhone3,1_7.1.2_11D257_Restore.ipsw`, about
1.2 GB (SHA-1 `81da17b3e893a61508fe203849b7e1f60e2127b1`, per ipsw.me).

Why this device: the iPod touch 4 stops at iOS 6.1.6. The iPhone 4 has the
same A4 (S5L8930X) and the same 640x960 panel, and it did ship iOS 7, so the
platform models in `Emulator/Platform` carry over. The iPhone 4's IMG3-format
firmware assets (`*.s5l8930x.img3`, `DeviceTree.n90ap.img3`) are the same
container family Podium already parses.

## What has been done

- `KernelProfile` (`Emulator/Boot/KernelProfile.swift`) now holds the
  kernelcache-specific addresses that used to be constants in
  `EmulationSession` and `KernelAcceleration`. The 10B500 values are moved,
  not changed. `EmulationSession.init` takes a `profile`, defaulting to
  iPod touch 4 / 10B500, so current behaviour is intended to be identical.
- `DeviceCatalog.iPhone4` and `IPhone4iOS7Target` name the target.
  `FirmwareCompatibilityChecker` is untouched and still rejects iPhone 4
  firmware, so nothing can try to boot it yet.
- `KernelProfileTests` pins the 10B500 addresses and asserts that there is
  no iPhone 4 profile yet.

None of this has been compiled or run (no Swift toolchain was available when
it was written). Build and run the test suite first.

## Bring-up checklist, in order

### 1. Obtain and open the firmware
- Get the IPSW and check its SHA-1.
- Keys: the kernelcache, DeviceTree and root filesystem keys for `11D257`
  (`iPhone3,1`) are on TheAppleWiki page "Keys:Sochi 11D257 (iPhone3,1)".
  `ReferenceFirmwareKeys` holds one build's keys as flat constants, so first
  turn it into a table keyed by (device, build), then add these. Copy them
  from the page yourself and verify each as the existing comments describe
  (the kernelcache must decrypt, LZSS-decompress, match the embedded Adler-32
  and be a Mach-O armv7 file; the DeviceTree must show readable property
  strings; the root filesystem must yield a UDIF image whose volume mounts).
- The IPSW paths differ: the kernelcache is `kernelcache.release.n90` and the
  device tree is under `Firmware/all_flash/all_flash.n90ap.production/`. Check
  that `BuildManifestPlist` and `IPSWParser` find them.

### 2. Find the kernel entry points (fills in a `KernelProfile`)
Do this on the decrypted, decompressed iOS 7.1.2 kernelcache (XNU 2423).
Every value must be found, not assumed.
- `panicEntries`: `_panic` and `panic_context`, with the register holding each
  format string. Locate them from references to panic format strings, and
  check the registers against the disassembly rather than reusing 0 and 2.
- `shutdownEntry`: `boot(paniced, howto, command)`. The `reboot` syscall's
  handler (look it up in `sysent`) leads to it. Confirm `howto` is in `r1`
  and that bit 3 (`RB_HALT`) still distinguishes halt from restart.
- `sharedRegionEntry`: `shared_region_map_and_slide_np`. Find its `sysent`
  slot (it was 438 on 10B500; check 11D257) and confirm the slide is still
  the fourth word of the arguments at `r1 + 0xc`.
- `timebaseReadLoop`: search for the five instruction words
  `E59C1004 E59C0000 E59C2004 E1510002 1AFFFFFA` that `KernelAcceleration`
  verifies. If they are not there, leave it `nil`. The kernel's own code then
  runs, which is slower but correct.
- Add `iPhone4_11D257` to `KernelProfile.all` and update
  `testIPhone4IOS7HasNoProfileYet` to expect it.

### 3. Boot the kernel to launchd
- RAM: `GuestMemoryLayout.ramSize` is already 1 GB, more than the iPhone 4's
  512 MB, so it needs no change. Check `DeviceTreeMemoryMap` and the
  `DeviceTreePatcher` memory properties for 256 MB assumptions anyway.
- Device tree: n90ap differs from n81ap. Walk each `DeviceTreePatcher` step
  (clocks, NVRAM proxy, panel ID, dot pitch, display scale, VRAM, RAM disk,
  secure root, debugging, effaceable storage, pram) against the n90ap tree.
  Expect to find nodes and drivers the iPod tree doesn't have (baseband,
  camera, proximity and so on) that stall boot until stubbed.
- `KernelcachePatcher.skipBacklightSearch` matches an exact kext plist
  string; check whether it still exists and still helps.
- `BootArgsBuilder`: check the boot-args revision and layout for XNU 2423.
- Touch: `MultitouchN1` loads `N81.mtprops`. The iPhone 4 needs its own
  multitouch firmware properties and protocol check.
- Use the existing panic and kernel-message-buffer reporting to iterate.

### 4. Root filesystem
- `RootFilesystemPreparer.referenceBuild` and the `lockdownd` build check in
  `RootFilesystemBuilder` are exact-build checks; generalize them to the
  target table.
- Regenerate `boot_read_files.txt` (the files the guest reads while booting)
  and `first_boot_state.plist` for iOS 7. They were measured and captured on
  10B500 and will not be right for 11D257.
- Rebuild the guest tools with the iOS 7 SDK if needed. `keybag_bootstrap`
  assumes iOS 6's `MobileKeyBag` symbols and `keybagd` behaviour, and iOS 7
  may check code signatures differently from what `legacy_adhoc_sign.py`
  produces.
- `GuestAccommodations`: confirm that the data-protection-class `fcntl` filter
  is still what blocks first boot, and whether iOS 7 adds other blockers.

### 5. First frame
- Expect a very long boot. iOS 7's UI leans on blur and translucency, all of
  which the guest CPU renders in software, since no GPU is modeled.
- `QuartzCoreAcceleration`'s five span functions are addresses in the
  10B500 dyld shared cache and cannot be reused. iOS 7 needs its own
  profiling, and new accelerations written to be bit-exact with the guest's
  code, with the differential tester that exists for the current ones.

### 6. Make it selectable
- Replace the single `ReferenceFirmware` with a table of targets.
  `FirmwareCompatibilityChecker`, `IPSWMeAPIClient`, the downloader,
  `PersistentGuestStorage` (its per-device, per-build paths) and the UI text
  all hard-code iPod touch 4 / 6.1.6 today.
- `EmulatorCore.boot` should pick the `KernelProfile` from the firmware's
  device and build, and refuse to boot if there isn't one.

## Unknowns

- Whether the iPhone 4 needs peripherals beyond the iPod touch's to finish
  booting.
- How much slower iOS 7 is under software compositing, and whether it is
  usable even with JIT.
- Whether the iOS 7 boot path hits CPU instructions the interpreter or
  translator doesn't implement yet. The existing decoders were checked
  against the iOS 6.1.6 kernel.
