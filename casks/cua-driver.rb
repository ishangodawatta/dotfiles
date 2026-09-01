cask "cua-driver" do
  arch arm: "arm64", intel: "x86_64"

  version "0.22.2"
  sha256 arm:   "ac05a34ff2416830ec56f44d9986cf04ffb1f6a15a5df6f4dd9bec13ac198d63",
         intel: "8480f7efcfee28c60bde1adfcd88125fc619f9719e17b0bd745b4dbc9d33166c"

  url "https://github.com/trycua/cua/releases/download/cua-driver-rs-v#{version}/" \
      "cua-driver-rs-#{version}-darwin-#{arch}.tar.gz"
  name "Cua Driver"
  desc "Background computer-use driver for macOS apps"
  homepage "https://github.com/trycua/cua"

  livecheck do
    url "https://github.com/trycua/cua.git"
    regex(/^cua-driver-rs[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :git
  end

  depends_on macos: :ventura

  app "cua-driver-rs-#{version}-darwin-#{arch}/CuaDriver.app"

  # Link the executable inside the bundle, not the loose one beside it. Both are
  # Developer ID signed, but only the bundled copy carries a stapled
  # notarisation ticket; the loose binary is killed on exec while quarantined.
  # Running in-bundle also attributes TCC grants to com.trycua.driver, which is
  # what the driver needs anyway.
  binary "#{appdir}/CuaDriver.app/Contents/MacOS/cua-driver"

  uninstall quit: "com.trycua.driver"

  zap trash: [
    "~/.cua-driver",
    "~/.cua-driver-rs",
    "~/Library/Application Support/Cua Driver",
    "~/Library/Caches/cua-driver",
    "~/Library/LaunchAgents/com.trycua.cua-driver.plist",
  ]
end
