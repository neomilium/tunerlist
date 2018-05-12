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

  module HU
    START_PLAY = 0x13
    NEXT_TRACK = 0x17
    STOP_PLAY = 0x19
    PAUSE = 0x1C
    FAST_FWD = 0x20
    FAST_REW = 0x21
    PREV_TRACK = 0x22
    NEXT_CD = 0x24
    LOAD_CD = 0x26
    RANDOM = 0x27
    REQ_CD_INFO = 0x86
    HU_ON = 0x93
    CD_CHECK = 0x94
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
