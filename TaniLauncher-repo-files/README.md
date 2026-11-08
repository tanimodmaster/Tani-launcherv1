# Tani Launcher

A Minecraft: Java Edition launcher for iPhone and iPad, built on the open-source
PojavLauncher iOS codebase (its maintained successor, [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)).
It looks and works like PojavLauncher, with these changes:

- **Named "Tani Launcher"**, with bundle id `com.tani.launcher`.
- **Fabric built in.** On first launch it creates and selects a ready-to-play
  **Fabric** profile for the latest stable Minecraft. In Profiles → **+** there's
  also **"Fabric (Latest, 1-tap)"**, next to the full Fabric/Quilt, Forge and Modpack installers.
- **All versions.** Every release, snapshot, old beta and old alpha from Mojang's version manifest.

## Getting the IPA

GitHub Actions builds it on every push to `main`:

1. Open the **Releases** page of this repo and download `TaniLauncher.ipa`
   (or `TaniLauncher-TrollStore.tipa` if you use TrollStore).
2. Sideload it with SideStore, AltStore, Sideloadly or TrollStore.
3. Turn on JIT (for example with StikDebug). Minecraft can't run without JIT.
4. Sign in with your Microsoft account and press Play.

To rebuild by hand, go to **Actions → Build Tani Launcher → Run workflow**.

## How the build works

- `tani/tani-fabric.patch`: the built-in Fabric feature, applied on top of a pinned upstream commit
- `tani/rebrand.sh`: sets the name, bundle id and text
- `tani/fetch-jres.sh`: downloads the iOS Java 8/17/21/25 runtimes, trying several sources

## License

The upstream code is licensed under the GNU GPL v3 (see `LICENSE`), and so is this derivative.
"Minecraft" is a trademark of Mojang/Microsoft. This project is not affiliated with them.
You need a legitimately purchased copy of Minecraft: Java Edition to play.
