
    ; Read one byte of the sound sample
    ldh a, [hSampleReadPtr+1]
    ld h, a
    ldh a, [hSampleReadPtr]
    ld l, a
    bit 7, h ; Check if we went past the end of the bank
    jr z, .noWrap ; If we're still in ROM0, keep going
    ; Switch to next bank
    ld hl, hSampleReadBank
    inc [hl]
    ; Check if sample end has been reached
    ldh a, [hSampleLastBank]
    cp [hl]
    ld hl, $4000 ; Wrap back to beginning of ROMX (hardcoded but there's no choice)
    jr nc, .noWrap ; c means `last bank < cur bank`
    ; Kill sample playback by killing the interrupt source
    xor a
    ldh [rTAC], a
    ; Kill sound at all
    ldh [rNR52], a
    ; One invalid byte will be read but it'll be ignored since the APU is off now
.noWrap

    ldh a, [hSampleReadBank]
    ld [rROMB0], a
    ldh a, [hSampleXORMask]
    xor [hl]
    ldh [rNR51], a

    ; Reset phase of pulse channels to make them play constant offsets
    ld a, $80
    ldh [rNR14], a
    ldh [rNR24], a

    inc hl
    ld a, l
    ldh [hSampleReadPtr], a
    ld a, h
    ldh [hSampleReadPtr+1], a
