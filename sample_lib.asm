
; Here's some technical explanation about Game Boy sample playing:
; The "usual" way of playing sound samples on the Game Boy is to use its wave channel
; Basically, let that channel play its 32 4-bit samples, then refill it
; Problem: to refill the channel, you have to disable it then restart it
; However, when doing so, the "sample buffer" is set to 0 **and not updated**
; This means the channel outputs a spike as its first sample, creating a buzzing sound
;
; Why? That's because of how the Game Boy generates sound: each channel produces
; a digital value between 0 and 15, which is fed to a DAC (Digital to Analog Converter)
; which converts it to an analog value I don't know the range of
; And finally, all analog values get sent to the SO1 and SO2 terminals, where they get
; mixed together and scaled based on NR51 and NR50 respectively, then sent to speakers
; The problem is that DIGITAL zero maps to ANALOG maximum; therefore the channel
; doesn't play silence when starting up. (The GB's APU appears to be poorly designed)
;
; What this means is that using CH3 inherently has this spiky problem
; No solution has been found to use another channel to compensate,
; so we need to think outside the box...
; The solution used here is to make all osund channels play a DC offset (a constant)
; but a different one for each channel; then, we pick which ones get added to reach
; any constant, by selecting which channels are fed to the mixed via NR51
; This gives 4-bit PCM at a selectable frequency that also does stereo
; but that hogs all sound channels and requires more CPU

; @param hl Pointer to the first byte of the sample to be played
; @param b Bank of the first byte of the sample to be played
; @param c Bank of the last byte of the sample to be played
StartSample::
    ; Prevent sample from playing while in inconsistent state
    ld a, 0 ; Preserve flags
    ldh [rTAC], a

    ld a, l
    ldh [hSampleReadPtr], a
    ld a, h
    ldh [hSampleReadPtr+1], a
    ld a, b
    ldh [hSampleReadBank], a
    ld a, c
    ldh [hSampleLastBank], a


    ld hl, .notAGB
    jr z, .indeedNotAGB
    ld hl, .AGB
.indeedNotAGB


    ; We need to reset the APU to reset the pulse channels' duty cycle phases
    xor a
    ldh [rNR52], a
    ldh [rDIV], a ; Reset DIV for consistency
    ld a, $80
    ldh [rNR52], a
    ; As far as currently known, the values of all sound registers are zero after powering on

    ; ~ Setting up CH3 ~
    ; CH3 can be made to output a constant value without trickery
    ; We just define its wave to be, well, a constant wave
    ; We do want to do this as early as possible, because the first sample CH3 puts out is glitched
    ; More fun: on GBA **exclusively**, the output is inverted
    ; Channel starts disabled
    ld a, [hli]
    ld bc, 16 << 8 | LOW(_AUD3WAVERAM)
.writeWave
    ldh [c], a
    inc c
    dec b
    jr nz, .writeWave
    ; Enable as-is output
    ld a, 1 << 5
    ldh [rNR32], a
    ; Re-enable channel so it can play
    ld a, $87 ; Only bit 7 matters
    ldh [rNR30], a
    ; Retrigger channel so it starts playing
    ; (Frequency should be as high as possible so initial "0" sample gets pushed away as fast as possible)
    ; ld a, $87
    ldh [rNR34], a

    ; ~ Setting up CH1 and CH2 ~
    ; Those two are more complicated, because we can't use the same trick
    ; as for CH4, and they will keep playing squares
    ; The trick is to keep the channel in the same sample index by restarting it
    ; There's a small difficulty, though: the channel begins by playing a 0 no matter
    ; what, so we need to wait until that's over, then begin "tickling" the channel
    ; We use duty cycle 75% because it's the one that reaches a non-zero output the
    ; fastest
    ; We will also obviously need the frequency to be as low as possible, but only
    ; once we reach the non-zero; before that, we'll set the frequency to be higher
    ; so the initial parasit 0 goes away more quickly
    ; And finally, we want CH1 to output digital 9, and CH2 digital 10
    ;xor a ; Reminder that all regs are init'd at 0
    ;ldh [rNR13], a
    ;ldh [rNR23], a
    ; Set duty cycle to 75%
    ld a, $C0
    ldh [rNR11], a
    ldh [rNR21], a
    ; Set output levels
    ld a, [hli]
    ldh [rNR12], a
    ld a, [hli]
    ldh [rNR22], a
    ; Start the channels, with a frequency higher than normal so their first sample goes away quickly
    ld a, $84
    ldh [rNR14], a
    ldh [rNR24], a

    ; ~ Setting up CH4 ~
    ; CH4 will output digital 0 == analog max
    ; This is done by turning on its DAC, but not the LFSR circuitry
    ; The DAC is turned on by writing a non-zero value to the envelope, the LFSR by "restarting" the channel via NR44
    ; On AGB, though, this falls apart due to "DAC"s being always on; therefore, we basically invert output and
    ; instead set up the LFSR into a loop of outputting only ones (possible by changing its width at a specific
    ; time)
    ; Turn on the DAC with an output level of $F (necessary on AGB)
    ld a, $F0
    ldh [rNR42], a
    ; Set a high frequency to get this over with quickly
    ;xor a ; Smallest dividers, 15-bit mode
    ;ldh [rNR43], a
    ; Turn on the circuitry on AGB but not elsewhere
    ld a, [hli]
    di ; What happens from now on is timing-sensitive, we can't be interrupted
    ldh [rNR44], a
    ; We need the LFSR to generate a few bits, do something else in the meantime


    ; Some bits need to be inverted on AGB
    ld a, [hli]
    ldh [hSampleXORMask], a


    ; Enable timer interrupt
    ldh a, [rIE]
    or IEF_TIMER
    ldh [rIE], a
    ld a, $E0 ; $C0 for 4 kHz interrupt
    ldh [rTMA], a
    ; Make the first sample trigger late to give time to pulse channels to set up (sounds weird, I know)
    xor a
    ldh [rTIMA], a
    ; Start counting down
    ld a, $04 | $01


    ; Finish setting up CH4 on AGB
    ld hl, rNR43
    ei ; Interrupts are fine after CH4 is set up
    set 3, [hl] ; Switch to 7-bit mode while the lowest 7 bits are all set


    ; Actually start counting down
    ldh [rTAC], a
    ret

.notAGB
    db $CC ; CH3 wave RAM
    db $90 ; NR12: CH1 envelope
    db $A0 ; NR22: CH2 envelope
    db $00 ; NR44: whether to start up the LFSR
    db $00 ; XOR mask

.AGB
    db $88 ^ $FF ; GBA inverts output
    db $20
    db $40
    db $80
    db $88 ; XOR mask
