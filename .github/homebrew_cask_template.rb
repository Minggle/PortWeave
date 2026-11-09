cask "portweave" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/chen08209/FlClash/releases/download/v#{version}/PortWeave-#{version}-macos-#{arch}.dmg"
  end

  name "PortWeave"
  desc "Multi-platform proxy client based on ClashMeta"
  homepage "https://github.com/chen08209/FlClash"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "PortWeave.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/PortWeave.app"],
        writable_paths: ["PortWeave.app"],
        writable_base:  :appdir
  end

  uninstall quit: "io.github.minggle.portweave"

  zap trash: [
    "~/Library/Application Support/io.github.minggle.portweave",
    "~/Library/Caches/io.github.minggle.portweave",
    "~/Library/Preferences/io.github.minggle.portweave.plist",
    "~/Library/Saved Application State/io.github.minggle.portweave.savedState",
  ]
end
