
# Smooth-Player

An audio sample player for the Game Boy and Game Boy Color.

## Features

- 4-bit spike-less sound samples
- Can be fed compressed sound data
- Customizable playback rates (8 kiHz possible at \~50% CPU usage)
- Heavier CPU usage (scales with playback rate)
- Works on all Game Boy and Game Boy Color models (except GBA for now, read "Pitfalls" below)

Feature requests and bug reports can be submitted in the repo's [issues](https://github.com/ISSOtm/smooth-player/issues), I look at them often.

## Usage

### Including

The project is designed to be able to be imported as a Git submodule, but grabbing the whole directory or just the first two `.asm` files is fine as well. The assembler targeted is RGBDS, and this was built with version 0.3.8.

`sample_player.asm` should be imported in ROM0, and ran as part of the timer interrupt handler. The code is bare so that there is no need to call it (saving precious cycles), and can be wrapped in anything you want (notably, ROM bank restoring). Just my two cents, but it's probably a bad idea to put this in ROMX :)

`sample_lib.asm` contains functions to interface with the sample player (currently, a single routine to set up sample playback); these are full functions with `ret`s and everything, but no `SECTION` definition. Where the functions will go and how they will be called is up to you.

`sample_macros.asm` contains macros to help you use Smooth-Player. They are separate because you may want to include this file in a different place than `sample_lib.asm`.

### Runtime

First, make sure you disabled sound playback. How is up to your sound driver and its implementation; what you must be sure of is that none of the sound registers are tampered with. (Exceptions are made in the "interface" section.)

Then, call `StartSample` with the sample's starting address in `hl` and Z set unless you're running on a Game Boy Advance, and make sure to set NR50 afterwards (this is not performed by the routine out of customization concerns, but be aware that if you do nothing volume will be zero). Please be advised that for the playback to operate correctly, the APU is turned off momentarily.

Now, make sure you don't disable the timer interrupt. The interrupt **must** be serviced regularly

### Interface

There's not much in the way of interface right now, but you can write to hardware registers directly to alter playback.

- `NR50`: the volume register is left untouched during playback, only set to $77 when starting up
- `hSampleReadBank`: sample playback ends immediately when this becomes strictly greater than `hSampleLastBank`

### Sound format

Roughly stereo 4-bit signed PCM. (It's actually a little different, but I need to refine this and the conversion script...)

The script `make_sample.py` is there to assist you in creating sound samples. Feed it a **RAW signed 8-bit PCM** file and it will output a suitable file to stdout. Example command: `./make_sample.py never_gonna.raw > src/res/samples/rick.sample`

## Customization

It may be necessary to tamper with the sound playback routine; the code is licensed under the MIT license, which allows you to, basically as long as you keep the license notice and don't delete my name. Backlinking is welcome :)

## Pitfalls

### Compatibility

This sample player relies on fairly edgy hardware behavior, and therefore is not well emulated. As far as I know, only [SameBoy](/LIJI32/SameBoy) emulates this properly. Another iteration of smooth-player has been theorized, that may be easier to emulate, but the project has not been started yet.

The Game Boy Advance does have a Game Boy Color retro-compatibility mode, but the sound hardware functions noticeably differently, causing corrupted output. Smooth-Player has been improved to almost support the GBA, but the output is noticeably crunchy for a reason I couldn't determine. This should hopefully be fixed in a future update.

### Known bugs

- Samples ending on bank $FF will misbehave; samples cannot cross the 127-128 bank boundary if using a 512-bank MBC5 ROM. Fix: ensure this doesn't happen. `include_sample` will warn you if this occurs.
- One extra byte is read when a sample finishes playing, which may switch to an invalid ROM bank. This byte is written to NR51 *after* the APU is turned off, therefore it's ignored. Turning the APU on resets that register, too.
- Sound output on GBA is horrible. See [above](#compatibility).
- `include_sample` can fail if the supplied label contains trailing colons (for example to define global labels). This is [a RGBDS bug](/rednex/rgbds/issues/362) present as of 0.3.8, I do not have a fix beyond not putting the colons and using a manual `EXPORT` if you need one, or `-E`. Sorry, but not my fault.

## Acknowledgements

[Liji](/LIJI32) helped a lot and was very patient with my repeated mistakes; his [SameBoy](/LIJI32/SameBoy) emulator helped a lot during debugging.

## Technical details

An explanation of how the whole thing works can be found [on my blog](//eldred.fr/projects/smooth-player).
