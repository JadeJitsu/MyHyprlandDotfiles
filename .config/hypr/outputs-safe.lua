-- Replacement for the DMS-generated dms/outputs.lua (AI-generated 2026-11-19).
--
-- Why: the T14s eDP panel reports its 60 Hz mode as either 60.001 or 60.003
-- across boots. DMS pins whichever value it last saw into dms/outputs.lua and
-- regenerates that file whenever it detects a running Hyprland. When the pinned
-- value does not match what the kernel reports this boot, Hyprland cannot match
-- the mode, disables the panel (or crashes on hot-reload) -> black screen.
-- Pinning the resolution without a refresh rate lets the kernel pick the
-- native mode regardless of the jitter.
--
-- If you ever regenerate the Hyprland config via DMS, re-point hyprland.lua at
-- this file: replace require("dms.outputs") with require("outputs-safe").
-- Test: ~/.config/hypr/scripts/tests/dms-outputs-shim-test.sh

hl.monitor({
    output   = "desc:Lenovo Group Limited N140JCA-ELP",
    mode     = "1920x1200",
    position = "0x0",
    scale    = 1.25,
})
