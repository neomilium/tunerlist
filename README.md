# Tunerlist

_Tunerlist_ is a _ruby gem_ developed to plug a _Music Player Daemon_ to for the _TUNER List_ headunit installed in _Renault Megane_, 1.2 version (End of 1999).

This _gem_ contains a working implementation of _Music Player_ client that interacts with headunit, acting as _CDC_: `bin/mpcdc`.

This was used during months with great pleasure :-)

## Thanks

Without the following site, this project would probably not have been: http://tlcdcemu.sourceforge.net

So, big thanks to their contributors. Even some information were not applicable to my headunit version, its really helps to start the project as I did not own a real _CDC_ to sniff communication.

## Reverse-engineering, debug and tests

During development, these executables were used to reverse-engine the headunit communication, debug wrong frames and keep trace during connected sessions:

* `bin/cdcemu`: _Compact Disk Changer Emulator_
* `bin/huemu`: _Headunit Emulator_

Note: To loop the local headunit emulator and _CDC_ emulator, `socat` can be used:

```shell
socat -x PTY,link=$PWD/ttyHU,rawer PTY,link=$PWD/ttyCDC,rawer
```
