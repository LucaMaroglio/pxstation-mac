# Homebrew cask for PxStation Mac. The release workflow updates `version` and
# `sha256` whenever a version tag is pushed.
#
#   brew tap LucaMaroglio/pxstation-mac https://github.com/LucaMaroglio/pxstation-mac
#   brew install --cask pxstation-mac
cask "pxstation-mac" do
  version "0.2.1"
  sha256 "de39cd0c93b7e123967493ca8ab02f15204d3e2ce84816c409402e244dd2f3fe"

  url "https://github.com/LucaMaroglio/pxstation-mac/releases/download/#{version}/PxStation-Mac-#{version}.dmg"
  name "PxStation Mac"
  desc "Native SPICE remote display client for Proxmox VE and QEMU virtual machines"
  homepage "https://github.com/LucaMaroglio/pxstation-mac"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "PxStation Mac.app"

  # The app is ad-hoc signed and not notarized. The download quarantine is deliberately
  # kept, so Gatekeeper still asks before the first launch (System Settings › Privacy &
  # Security › Open Anyway).
  caveats <<~EOS
    #{token} is ad-hoc signed and not notarized by Apple. On first launch macOS blocks it:
    open System Settings › Privacy & Security and click "Open Anyway".
  EOS

  zap trash: [
    "~/Library/Application Scripts/it.zenity.pxstation-mac",
    "~/Library/Containers/it.zenity.pxstation-mac",
  ]
end
