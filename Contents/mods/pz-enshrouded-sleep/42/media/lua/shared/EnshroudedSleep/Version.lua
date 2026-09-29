-- Enshrouded Sleep - build version
-- Enshrouded Sleep for Project Zomboid Build 42.20+
--
-- The one place the runtime build version is defined. Keep it equal to the
-- repository VERSION file; tools/validate-package.sh checks this. Server
-- CONFIG lines, load banners, and the buildVersion field in server-to-client
-- state messages all read it from here, so clients and servers can detect a
-- mixed-version install (see "Build stamp and version handshake" in
-- docs/DESIGN.md).

local Version = {
    BUILD_VERSION = "1.0.2",
}

return Version
