
; include_sample label, path, size, first_bank
; A colon can be appended to the name, or a pair of them to export the sample
include_sample: MACRO
SAMPLE_BANK = \4
CUR_POS = 0
LABEL_DEFINED = 0
    ; Ensure sample ends on a bankswitch
    IF CUR_POS % $4000
        sample_slice \1, \2, CUR_POS % $4000
    ENDC

    REPT (\3) / $4000
        sample_slice \1, \2, $4000
    ENDR

End\1: ; Define end of sample label

    IF LOW(SAMPLE_BANK) == $FF
        WARN "Smooth-Player may glitch out if a sample ends on bank $FF or $1FF"
    ELIF HIGH(\4) != HIGH(SAMPLE_BANK)
        WARN "Smooth-Player does not natively support playback of samples across banks 127 and 128"
    ENDC
ENDM

; sample_slice label, path, size
; DO NOT CALL YOURSELF!
sample_slice: MACRO
    SECTION "\1 sample bank {SAMPLE_BANK}", ROMX[$8000 - (\3)],BANK[SAMPLE_BANK]
    IF !LABEL_DEFINED
LABEL_DEFINED = 1
\1:
    ENDC
    INCBIN \2, CUR_POS, \3

CUR_POS = CUR_POS + (\3)
SAMPLE_BANK = SAMPLE_BANK + 1
ENDM


; play_sample label
; Calls `PlaySample` with the right arguments in `hl` and `de`
; Make sure the Z flag is set as described by `StartSample` first!
play_sample: MACRO
    ld hl, \1
    ld bc, BANK(\1) << 8 | BANK(End\1)
    call StartSample
ENDM
