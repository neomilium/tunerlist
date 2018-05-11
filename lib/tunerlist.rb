require 'tunerlist/frame_codec'

module TunerList
  module CDC
    # Payload types
    BOOTING       = 0x11
    BOOT_OK       = 0x15
    STATUS        = 0x20
    CD_OPERATION  = 0x21
    RANDOM_STATUS = 0x25
    TRAY_STATUS   = 0x26
    CD_SUMMARY    = 0x46
    PLAYING       = 0x47
  end

  module CD
    NO_CD_LOADED = 0x01
    PAUSED = 0x03
    LOADING_TRACK = 0x04
    PLAYING = 0x05
    CUEING_FWD = 0x07
    REWINDING = 0x08
    CD_READY = 0x09
    SEARCHING_TRACK = 0x0a
  end

  module Tray
    NO_TRAY = 0x02
    LOADING_CD = 0x04
    CD_READY = 0x03
    UNLOADING_CD = 0x05
  end

  module RandomStatus
    OFF = 0x03
    ON  = 0x07
  end
end
