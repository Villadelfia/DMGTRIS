; DMGTRIS
; Copyright (C) 2023 - Randy Thiemann <randy.thiemann@gmail.com>

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.


IF !DEF(FIELD_ASM)
DEF FIELD_ASM EQU 1


INCLUDE "globals.asm"


DEF DELAY_STATE_DETERMINE_DELAY EQU 0
DEF DELAY_STATE_LINE_CLEAR      EQU 1
DEF DELAY_STATE_LINE_PRE_CLEAR  EQU 2
DEF DELAY_STATE_ARE             EQU 3
DEF DELAY_STATE_PRE_ARE         EQU 4


SECTION "Field Variables", WRAM0
wField:: ds (10*24)
wBackupField:: ds (10*24)
wPreShadowField:: ds (14*2)
wShadowField:: ds (14*26)
wWideField:: ds (5*11)
wWideBlittedField:: ds (22*10)
wDelayState: ds 1
wLeftSlamTimer: ds 1
wRightSlamTimer: ds 1
wMovementLastFrame: ds 1
wReturnToSmall:: ds 1


SECTION "High Field Variables", HRAM
hPieceDataBase: ds 2
hPieceDataBaseFast: ds 2
hPieceDataOffset: ds 1
hCurrentLockDelayRemaining:: ds 1
hGrounded: ds 1
hWantedTile: ds 1
hWantedG: ds 1
hActualG: ds 1
hGravityCtr: ds 1
hWantX: ds 1
hYPosAtStartOfFrame: ds 1
hWantRotation: ds 1
hRemainingDelay:: ds 1
hClearedLines: ds 4
hLineClearCt:: ds 1
hComboCt:: ds 1
hLockDelayForce: ds 1
hDownFrames: ds 1
hAwardDownBonus: ds 1
hStalePiece: ds 1
hBravo: ds 1
hShouldLockIfGrounded: ds 1


SECTION "Field Function Unbanked", ROM0
    ; Blits the field onto the tile map.
    ; On the GBC, this chain calls into a special version that takes
    ; advantage of the GBC's CPU.
BlitField::
    ld a, [wInitialA]
    cp a, $11
    jp z, GBCBlitField

    ; What to copy
    ld de, wField + 30
    ; Where to put it
    ld hl, FIELD_TOP_LEFT
    ; How much to increment hl after each row
    ld bc, 32-10

    ; The first 14 rows can be blitted without checking for vram access.
    REPT 14
        REPT 10
            ld a, [de]
            ld [hl+], a
            inc de
        ENDR
        add hl, bc
    ENDR

.waitendvbloop
    ldh a, [rLY]
    or a, a
    jr nz, .waitendvbloop

    ; The last 6 rows need some care.
    REPT 7
        ; Wait until start of drawing, then insert nops.
:       ldh a, [rSTAT]
        or a, $FF - STATF_LCD
        inc a
        jr nz, :-
        REPT 40
            nop
        ENDR

        ; Blit a line.
        REPT 10
            ld a, [de]
            ld [hl+], a
            inc de
        ENDR

        ; Increment HL so that the next line can be blitted.
        add hl, bc
    ENDR

    ; This function is actually called as the vblank handler for the gameplay state.
    ; This is why it jumps straight back to the event loop.
    jp EventLoop


    ; Blits the big field onto the tile map.
    ; On the GBC, this chain calls into a special version that takes
    ; advantage of the GBC's CPU.
BigBlitField::
    ld a, [wInitialA]
    cp a, $11
    jp z, GBCBlitField

    ; What to copy
    ld de, wWideBlittedField+10
    ; Where to put it
    ld hl, FIELD_TOP_LEFT
    ; How much to increment hl after each row
    ld bc, 32-10

    ; The first 14 rows can be blitted without checking for vram access.
    REPT 14
        REPT 10
            ld a, [de]
            ld [hl+], a
            inc de
        ENDR
        add hl, bc
    ENDR

.waitendvbloop
    ldh a, [rLY]
    or a, a
    jr nz, .waitendvbloop

    ; The last 6 rows need some care.
    REPT 7
        ; Wait until start of drawing, then insert nops.
:       ldh a, [rSTAT]
        or a, $FF - STATF_LCD
        inc a
        jr nz, :-
        REPT 40
            nop
        ENDR

        ; Blit a line.
        REPT 10
            ld a, [de]
            ld [hl+], a
            inc de
        ENDR

        ; Increment HL so that the next line can be blitted.
        add hl, bc
    ENDR

    ; This function is actually called as the vblank handler for the gameplay state.
    ; This is why it jumps straight back to the event loop.
    jp EventLoop



SECTION "Field Function Banked Gameplay", ROMX, BANK[BANK_GAMEPLAY]
    ; Initializes the field completely blank.
    ; Initializes the combo counter to 1.
    ; Initializes the bravo counter to 0.
    ; Initializes the shadow field.
FieldInit::
    xor a, a
    ldh [hBravo], a
    ldh [hLineClearCt], a
    ld [wMovementLastFrame], a
    ld a, 1
    ldh [hComboCt], a
    ld hl, wField
    ld bc, 10*24
    ld d, TILE_BLANK
    call UnsafeMemSet
    ld hl, wShadowField
    ld bc, 14*26
    ld d, $FF
    call UnsafeMemSet
    ld hl, wPreShadowField
    ld bc, 14*2
    ld d, $FF
    call UnsafeMemSet
    ld a, SLAM_ANIMATION_LEN
    ld [wLeftSlamTimer], a
    ld [wRightSlamTimer], a
    ret


    ; Fills the field with the empty tile.
FieldClear::
    ld hl, wField
    ld bc, 10*24
    ld d, TILE_FIELD_EMPTY
    jp UnsafeMemSet


    ; Backs up the field.
    ; This backup field is used for pausing the game.
ToBackupField::
    ld de, wField
    ld hl, wBackupField
    ld bc, 10*24
    jp UnsafeMemCopy


    ; Restores the backup of the field for ending pause mode.
FromBackupField::
    ld hl, wField
    ld de, wBackupField
    ld bc, 10*24
    jp UnsafeMemCopy

GoBig::
    ld a, $FF
    ld [wReturnToSmall], a
    ld hl, wWideBlittedField
    ld bc, 10*22
    ld d, TILE_BLANK
    call UnsafeMemSet
    ld hl, wField
    ld bc, 10*24
    ld d, 0
    call UnsafeMemSet
    DEF row = 0
    REPT 14
        ld hl, wField + (row*10)
        ld bc, 5
        ld d, TILE_FIELD_EMPTY
        call UnsafeMemSet
        DEF row += 1
    ENDR
    ld a, STATE_GAMEPLAY_BIG
    ldh [hGameState], a
    ret

    ; Copies the field to the shadow field.
    ; This shadow field is used to calculate whether or not the piece can fit.
ToShadowField::
    ld hl, wField
    ld de, wShadowField+2
    ld c, 24
.outer
    ld b, 10
.inner
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .inner
    inc de
    inc de
    inc de
    inc de
    dec c
    jr nz, .outer
    ret


    ; Restores the shadow field to the main field.
FromShadowField:
    ld hl, wField
    ld de, wShadowField+2
    ld c, 24
.outer
    ld b, 10
.inner
    ld a, [de]
    ld [hl+], a
    inc de
    dec b
    jr nz, .inner
    inc de
    inc de
    inc de
    inc de
    dec c
    jr nz, .outer
    ret


    ; The current piece ID is used to get the offset into the rotation states
    ; corresponding to that piece's zero rotation.
SetPieceData:
    ldh a, [hCurrentPiece]
    add a, a
    add a, a
    add a, a
    add a, a
    ld c, a
    ld b, 0

    ld hl, sPieceRotationStates
    add hl, bc
    ld a, l
    ldh [hPieceDataBase], a
    ld a, h
    ldh [hPieceDataBase+1], a

    ld hl, sPieceFastRotationStates
    add hl, bc
    ld a, l
    ldh [hPieceDataBaseFast], a
    ld a, h
    ldh [hPieceDataBaseFast+1], a
    ret


    ; The rotation state is a further offset of 4 bytes.
SetPieceDataOffset:
    ldh a, [hCurrentPieceRotationState]
    add a, a
    add a, a
    ldh [hPieceDataOffset], a
    ret


    ; Converts piece Y in B and a piece X in A to a pointer to the shadow field in HL.
XYToSFieldPtr:
    ld hl, wShadowField
    ld de, 14
    inc a
    inc b
.a
    dec b
    jr z, .b
    add hl, de
    jr .a
.b
    dec a
    ret z
    inc hl
    jr .b


    ; Converts piece Y in B and a piece X in A to a pointer to the field in HL.
XYToFieldPtr:
    ld hl, wField-2
    ld de, 10
    inc a
    inc b
.a
    dec b
    jr z, .b
    add hl, de
    jr .a
.b
    dec a
    ret z
    inc hl
    jr .b


    ; This function makes HL point to the correct offset into the rotation data.
    ; This version of the data is used for thorough checking (T, J, and L have
    ; a middle column exception.)
GetPieceData:
    ldh a, [hPieceDataBase]
    ld l, a
    ldh a, [hPieceDataBase+1]
    ld h, a
    ldh a, [hPieceDataOffset]
    ld c, a
    ld b, 0
    add hl, bc
    ret


    ; Same as the above but for the fast data. This data is used when the exact
    ; cell that failed isn't important.
GetPieceDataFast:
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hPieceDataOffset]
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    ret


    ; Checks if the piece can fit at the current position.
    ; HL should point to the piece's rotation state data.
    ; DE should be pointing to the right place in the SHADOW field.
    ; This will return with $FF in A if the piece fits, or with the
    ; exact cell that caused the first failure in A.
CanPieceFit:
    xor a, a
    ld b, a

    ; Row 1
    bit 3, [hl]
    jr z, .skipr1a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr1b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr1c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r1end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

.r1end
    REPT 11
        inc de
    ENDR

    ; Row 2
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr2a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr2b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr2c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r2end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

.r2end
    REPT 11
        inc de
    ENDR

    ; Row 3
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr3a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr3b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr3c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r3end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ret nz

.r3end
    REPT 11
        inc de
    ENDR

    ; Row 4
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr4a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr4b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr4c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r4end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

    ; If we got here, the piece can fit.
.r4end
    ld a, $FF
    ret


    ; Checks if the piece can fit at the current position, but fast.
    ; HL should point to the piece's fast rotation state data.
    ; DE should be pointing to the right place in the SHADOW field.
    ; This will return with $FF in A if the piece fits, or with a non-$FF
    ; value if it doesn't.
CanPieceFitFast:
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip1
    xor a, a
    ret
.skip1
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip2
    xor a, a
    ret
.skip2
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip3
    xor a, a
    ret
.skip3
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip4
    xor a, a
    ret
.skip4
    ld a, $FF
    ret


    ; This function will draw the piece even if it can't fit.
    ; We use this to draw a final failed spawn before going game
    ; over.
ForceSpawnPiece::
    call SetPieceData
    call SetPieceDataOffset
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToFieldPtr
    ld d, h
    ld e, l
    call GetPieceData
    ld b, GAME_OVER_OTHER
    push hl
    push de
    pop hl
    pop de
    jp DrawPiece


    ; Initialize the state for a new piece and attempts to spawn it.
    ; On return, A will be $FF if the piece fit.
TrySpawnPiece::
    ; Always reset these for a new piece.
    xor a, a
    ldh [hStalePiece], a
    ldh [hDownFrames], a
    ldh [hAwardDownBonus], a
    ldh [hLockDelayForce], a
    ldh [hShouldLockIfGrounded], a
    ldh [hGravityCtr], a
    ldh [hGrounded], a
    ld [wMovementLastFrame], a
    ld a, SLAM_ANIMATION_LEN
    ld [wLeftSlamTimer], a
    ld [wRightSlamTimer], a
    ld a, -2
    ldh [rSCX], a
    ldh a, [hCurrentLockDelay]
    ldh [hCurrentLockDelayRemaining], a
    ld a, $FF
    ldh [hRemainingDelay], a
    ld a, DELAY_STATE_DETERMINE_DELAY
    ld [wDelayState], a

    ; Point the piece data to the correct piece.
    call SetPieceData
    call SetPieceDataOffset

    ; Get the piece's spawn position.
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr

    ; Check if the piece can spawn.
    ld d, h
    ld e, l
    call GetPieceDataFast
    call CanPieceFitFast

    ; A will be $FF if the piece can fit.
    cp a, $FF
    ret z

    ; If we didn't try to IRS in the first place, too bad. Game over.
    ldh a, [hCurrentPieceRotationState]
    or a, a
    ret z

    ; Try rotation state 0.
.try0
    xor a, a
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    call GetPieceDataFast
    jp CanPieceFitFast


    ; Draws the piece onto the field.
    ; B is the tile.
    ; DE should point to the piece's rotation state data.
    ; HL should be pointing to the right place in the NORMAL field.
DrawPiece:
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr1a
    ld [hl], b
.skipr1a
    inc hl
    bit 2, a
    jr z, .skipr1b
    ld [hl], b
.skipr1b
    inc hl
    bit 1, a
    jr z, .skipr1c
    ld [hl], b
.skipr1c
    inc hl
    bit 0, a
    jr z, .r1end
    ld [hl], b

.r1end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr2a
    ld [hl], b
.skipr2a
    inc hl
    bit 2, a
    jr z, .skipr2b
    ld [hl], b
.skipr2b
    inc hl
    bit 1, a
    jr z, .skipr2c
    ld [hl], b
.skipr2c
    inc hl
    bit 0, a
    jr z, .r2end
    ld [hl], b

.r2end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr3a
    ld [hl], b
.skipr3a
    inc hl
    bit 2, a
    jr z, .skipr3b
    ld [hl], b
.skipr3b
    inc hl
    bit 1, a
    jr z, .skipr3c
    ld [hl], b
.skipr3c
    inc hl
    bit 0, a
    jr z, .r3end
    ld [hl], b

.r3end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr4a
    ld [hl], b
.skipr4a
    inc hl
    bit 2, a
    jr z, .skipr4b
    ld [hl], b
.skipr4b
    inc hl
    bit 1, a
    jr z, .skipr4c
    ld [hl], b
.skipr4c
    inc hl
    bit 0, a
    ret z
    ld [hl], b
    ret


    ; Find the deepest the piece can go.
    ; We cache this pointer, cause it otherwise takes too much time.
FindMaxG:
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr

    push hl
    ld a, 1
    ldh [hActualG], a
.try
    ld de, 14
    pop hl
    add hl, de
    push hl
    ld d, h
    ld e, l
    call GetPieceDataFast
    call CanPieceFitFast
    cp a, $FF
    jr nz, .found
    ldh a, [hActualG]
    inc a
    ldh [hActualG], a
    jr .try

.found
    pop hl
    ldh a, [hActualG]
    dec a
    ldh [hActualG], a
    ret


    ; This is the main function that will process input, gravity, and locking.
    ; It should be ran once per frame as long as lock delay is greater than 0.
FieldProcess::
    ; **************************************************************
    ; SETUP
    ; Grade decay?
    call DecayGradeProcess

    ; Apply screen shake if needed.
.leftslam
    ld a, [wLeftSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr z, .rightslam
    ld b, 0
    ld c, a
    ld hl, sLeftDasSlam
    add hl, bc
    inc a
    ld [wLeftSlamTimer], a
    ld a, [hl]
    ldh [rSCX], a
    jr .wipe

.rightslam
    ld a, [wRightSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr z, .wipe
    ld b, 0
    ld c, a
    ld hl, sRightDasSlam
    add hl, bc
    inc a
    ld [wRightSlamTimer], a
    ld a, [hl]
    ldh [rSCX], a

    ; Wipe out the piece.
.wipe
    ldh a, [hCurrentPieceY]
    ldh [hYPosAtStartOfFrame], a
    call FromShadowField

    ; Cleanup from last frame.
    ldh a, [hCurrentPieceRotationState]
    ldh [hWantRotation], a

    ; Is this the first frame of the piece?
.firstframe
    ldh a, [hStalePiece]
    or a, a
    jr nz, .handleselect
    ld a, $FF
    ldh [hStalePiece], a
    jp .skipmovement


    ; **************************************************************
    ; HANDLE SELECT
    ; Check if we're about to hold. Return if so.
.handleselect
    ldh a, [hSelectState]
    cp a, 1
    jr nz, .wantrotccw
    ldh a, [hHoldSpent]
    cp a, $FF
    ret nz


    ; **************************************************************
    ; HANDLE ROTATION
    ; Want rotate CCW?
.wantrotccw
    ld a, [wSwapABState]
    or a, a
    jr z, .ldb1
.lda1
    ldh a, [hAState]
    jr .cp1
.ldb1
    ldh a, [hBState]
.cp1
    cp a, 1
    jr nz, .wantrotcw
    ldh a, [hWantRotation]
    inc a
    and a, $03
    ldh [hWantRotation], a
    jr .tryrot

    ; Want rotate CW?
.wantrotcw
    ld a, [wSwapABState]
    or a, a
    jr z, .lda2
.ldb2
    ldh a, [hBState]
    jr .cp2
.lda2
    ldh a, [hAState]
.cp2
    cp a, 1
    jp nz, .norot
    ldh a, [hWantRotation]
    dec a
    and a, $03
    ldh [hWantRotation], a

    ; Try the rotation.
.tryrot
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBase]
    ld l, a
    ldh a, [hPieceDataBase+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFit ; This does have to be the "slow" version.
    cp a, $FF
    jr nz, .maybekick
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try kicks if the piece isn't I or O. And in the case of J L and T, only if the blocked side is the left or right.
.maybekick
    ld c, a
    ; No kicks for NES mode.
    ld a, [wRotModeState]
    cp a, ROT_MODE_NES
    jp z, .norot

    ldh a, [hCurrentPiece]
    ; O pieces never kick, obviously.
    cp a, PIECE_O
    jp z, .norot

    ; MYCO always tries to kick.
    ld a, [wRotModeState]
    cp a, ROT_MODE_MYCO
    jp z, .trykickright
    ldh a, [hCurrentPiece]

    ; S/Z always kick.
    cp a, PIECE_S
    jr z, .trykickright
    cp a, PIECE_Z
    jr z, .trykickright

    ; I piece only kicks in ARS2
    cp a, PIECE_I
    jr nz, .tljexceptions
    ld a, [wRotModeState]
    cp a, ROT_MODE_ARSTI
    jp nz, .norot
    ldh a, [hWantRotation]
    bit 0, a
    jp nz, .checki
    jr .trykickright

    ; T/L/J only kick if not through the middle axis.
.tljexceptions
    ld a, c
    cp a, 1
    jp z, .maybetgm3rot
    cp a, 5
    jp z, .maybetgm3rot
    cp a, 9
    jr z, .maybetgm3rot

    ; A step to the right.
.trykickright
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    inc a
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jr nz, .trykickleft
    ldh a, [hCurrentPieceX]
    inc a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; And a step to the left.
.trykickleft
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    or a, a
    jr z, .maybetgm3rot
    dec a
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jr nz, .maybetgm3rot
    ldh a, [hCurrentPieceX]
    dec a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; In ARS2 mode, there are a few other kicks possible.
.maybetgm3rot
    ld a, [wRotModeState]
    cp a, ROT_MODE_ARSTI
    jp nz, .norot

    ; In the case of a T piece, try the space above.
.checkt
    ldh a, [hCurrentPiece]
    cp a, PIECE_T
    jr nz, .checki

.tkickup
    ldh a, [hCurrentPieceY]
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jp nz, .norot
    ldh a, [hCurrentPieceY]
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .tkickupalreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.tkickupalreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; In the case of an I piece...
.checki
    ldh a, [hCurrentPiece]
    cp a, PIECE_I
    jp nz, .norot

    ; What direction do we want to end up?
.ikicks
    ldh a, [hWantRotation]
    bit 0, a
    jp z, .tryiright2   ; Flat? Sideways kicks are fine.
                        ; Upright? Only up kicks.

    ; Are we grounded? Don't kick if we aren't.
    ldh a, [hActualG]
    or a, a
    jp nz, .norot

    ; Try up once.
.tryiup1
    ldh a, [hCurrentPieceY]
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jr nz, .tryiup2
    ldh a, [hCurrentPieceY]
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .ikickup1alreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.ikickup1alreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try up twice.
.tryiup2
    ldh a, [hCurrentPieceY]
    dec a
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jr nz, .norot
    ldh a, [hCurrentPieceY]
    dec a
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .ikickup2alreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.ikickup2alreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try right twice.
.tryiright2
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    inc a
    inc a
    call XYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call CanPieceFitFast
    cp a, $FF
    jr nz, .norot
    ldh a, [hCurrentPieceX]
    inc a
    inc a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call SetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a


    ; **************************************************************
    ; HANDLE MOVEMENT
    ; Do we want to move left?
.norot
    ldh a, [hCurrentPieceX]
    ldh [hWantX], a

.wantleft
    ldh a, [hCurrentPieceX]
    or a, a
    jr z, .precheckright
    ldh a, [hLeftState] ; Check if held for 1 frame. If so we move.
    cp a, 1
    jr z, .doleft
    or a, a             ; We never want to move if the button wasn't held.
    jr z, .wantright
    ld b, a
.checkdasleft
    ldh a, [hCurrentDAS]
    ld c, a
    ld a, b
    cp a, c
    jr c, .wantright
.doleft
    ldh a, [hWantX]
    dec a
    ldh [hWantX], a
    jr .trymove

.precheckright
    ldh a, [hRightState]
    or a, a
    jr z, .nomove

    ; Do we want to move right?
.wantright
    ldh a, [hRightState] ; Check if held for 1 frame. If so we move.
    cp a, 1
    jr z, .doright
    or a, a             ; We never want to move if the button wasn't held.
    jr z, .noeffect
    ld b, a
.checkdasright
    ldh a, [hCurrentDAS]
    ld c, a
    ld a, b
    cp a, c
    jr c, .noeffect
.doright
    ldh a, [hWantX]
    inc a
    ldh [hWantX], a

    ; Try the movement.
.trymove
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hWantX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    call GetPieceDataFast
    call CanPieceFitFast
    cp a, $FF
    jr nz, .nomove
    ld a, $FF
    ld [wMovementLastFrame], a
    ldh a, [hWantX]
    ldh [hCurrentPieceX], a
    jr .donemanipulating

.nomove
    ld a, [wMovementLastFrame]
    or a, a
    jr z, .noeffect

    ; We moved last frame but couldn't move this frame. That means we slammed into a wall.
    ; First check if either effect is playing and that we're not in 20G.
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr z, .noeffect
    ld a, [wLeftSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr nz, .noeffect
    ld a, [wRightSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr nz, .noeffect

    ; Which wall did we slam into?
    ldh a, [hWantX]
    ld b, a
    ldh a, [hCurrentPieceX]
    cp a, b
    jr c, .slamright

.slamleft
    xor a, a
    ld [wLeftSlamTimer], a
    jr .noeffect

.slamright
    xor a, a
    ld [wRightSlamTimer], a

.noeffect
    xor a, a
    ld [wMovementLastFrame], a


    ; **************************************************************
    ; HANDLE MAXIMUM FALL
    ; This little maneuver is going to cost us 51 years.
.skipmovement
.donemanipulating
    call FindMaxG


    ; **************************************************************
    ; HANDLE UP
    ; Assume 1G or lower.
    ld a, 1
    ldh [hWantedG], a

    ; Is a hard/sonic drop requested?
    ldh a, [hUpState]
    cp a, 1
    jr nz, .postdrop

    ; What kind, if any?
    ld a, [wDropModeState]
    cp a, DROP_MODE_NONE
    jr z, .postdrop
    cp a, DROP_MODE_LOCK
    jr z, .harddrop
    cp a, DROP_MODE_HARD
    jr z, .harddrop

    ; Sonic drop.
.sonicdrop
    ; Skip in 20G mode.
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr z, .postdrop
    ld a, [wDropModeState]
    cp a, DROP_MODE_SNIC
    jr z, .sonicneutrallockskip
    ld a, $FF
    ldh [hShouldLockIfGrounded], a
.sonicneutrallockskip
    ld a, $FF
    ldh [hAwardDownBonus], a
    ld a, 20
    ldh [hWantedG], a
    jr .grav

    ; Hard drop.
.harddrop
    ld a, $FF
    ldh [hAwardDownBonus], a
    ld a, 20
    ldh [hWantedG], a
    ld b, a
    ldh a, [hActualG]
    cp a, b
    jr nc, .donedeterminingharddropdistance
    ld b, a
.donedeterminingharddropdistance
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    xor a, a
    ldh [hCurrentLockDelayRemaining], a
    ld a, $FF
    ldh [hGrounded], a
    ld a, SFX_LOCK
    call SFXTriggerNoise
    jp .draw

    ; If we press down, we want to do a soft drop.
.postdrop
    ldh a, [hDownState]
    or a, a
    jr z, .checkregulargravity
    ldh a, [hDownFrames]
    inc a
    ldh [hDownFrames], a
    ld a, $FF
    ldh [hGravityCtr], a
    ld a, [wDropModeState]
    cp a, DROP_MODE_HARD
    jr nz, .checkregulargravity
    ld a, $FF
    ldh [hShouldLockIfGrounded], a

    ; Gravity?
.checkregulargravity
    ldh a, [hCurrentFractionalGravity]
    cp a, $00 ; 0 is the sentinel value that should be interpreted as "every frame"
    jr z, .alwaysgravitysentinel
    ld b, a
    ldh a, [hGravityCtr]
    add a, b
    ldh [hGravityCtr], a
    jr nc, .nograv
.alwaysgravitysentinel
    ldh a, [hCurrentIntegerGravity]
    ldh [hWantedG], a

    ; Can we drop the full requested distance?
.grav
    ldh a, [hWantedG]
    ld b, a
    ldh a, [hActualG]
    cp a, b
    jr c, .smallg

    ; Yes. Do it.
.bigg
    ldh a, [hWantedG]
    ld b, a
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    ldh a, [hAwardDownBonus]
    cp a, $FF
    jr nz, .postgrav
    ld a, b
    ldh [hAwardDownBonus], a
    jr .postgrav

    ; No. Smaller distance.
.smallg
    ldh a, [hActualG]
    ld b, a
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    ldh a, [hAwardDownBonus]
    cp a, $FF
    jr nz, .postgrav
    ld a, b
    ldh [hAwardDownBonus], a


    ; **************************************************************
    ; HANDLE LOCKING
    ; Are we grounded?
.postgrav
.nograv
    xor a, a
    ldh [hGrounded], a
    ldh a, [hYPosAtStartOfFrame]
    ld b, a
    ldh a, [hCurrentPieceY]
    cp a, b
    jr z, .noreset
    ldh a, [hCurrentLockDelay]
    ldh [hCurrentLockDelayRemaining], a
.noreset
    ldh a, [hCurrentPieceY]
    inc a
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToSFieldPtr
    ld d, h
    ld e, l
    call GetPieceDataFast
    call CanPieceFitFast
    cp a, $FF
    jp z, .notgrounded

    ; We're grounded.
.grounded
    ld a, $FF
    ldh [hGrounded], a
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hYPosAtStartOfFrame]
    cp a, b
    jr z, .postcheckforfirmdropsound ; Never play the sound if we didn't change rows.
    ldh a, [hDownState]
    or a, a
    jr nz, .postcheckforfirmdropsound ; Don't play the sound if we're holding down.

    ; Play the firm drop sound.
.playfirmdropsound
    ld a, SFX_LAND
    call SFXTriggerNoise

    ; If the down button is held, lock.
.postcheckforfirmdropsound
    ldh a, [hDownState]
    or a, a
    jr z, .neutralcheck

    ; Don't lock on down for hard drop mode immediately.
    ld a, [wDropModeState]
    cp a, DROP_MODE_HARD
    jr nz, .downlock20gexceptioncheck
    ld a, $FF
    ldh [hShouldLockIfGrounded], a
    jr .dontforcelock

    ; Lock on down in modes <20G.
.downlock20gexceptioncheck
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr nz, .forcelock

    ; In 20G mode, only lock if down has been pressed for exactly 1 frame.
    ldh a, [hDownState]
    cp a, 1
    jr z, .forcelock
    jr .dontforcelock

    ; If the down button is not held, check if we're neutral and if that should lock.
.neutralcheck
    ldh a, [hShouldLockIfGrounded]
    or a, a
    jr z, .dontforcelock

    ; Check for neutral.
    ldh a, [hUpState]
    or a, a
    jr nz, .dontforcelock
    ldh a, [hLeftState]
    or a, a
    jr nz, .dontforcelock
    ldh a, [hRightState]
    or a, a
    jr nz, .dontforcelock

    ; Lock on neutral for a few modes.
    ld a, [wDropModeState]
    cp a, DROP_MODE_FIRM
    jr z, .forcelock
    cp a, DROP_MODE_HARD
    jr z, .forcelock
    jr .dontforcelock

    ; Set the lock delay to 0 and save it.
.forcelock
    xor a, a
    ldh [hCurrentLockDelayRemaining], a
    jr .dolock

    ; Load the lock delay.
    ; Decrement it by one and save it.
.dontforcelock
    ldh a, [hCurrentLockDelayRemaining]
    dec a
    ldh [hCurrentLockDelayRemaining], a

    ; Are we out of lock delay?
.checklockdelay
    or a, a
    jr nz, .checkfortgm3lockexception ; If not, check if the TGM3 exception applies.
    jr .dolock ; Otherwise, lock!

    ; TGM3 sometimes forces a piece to immediately lock.
.checkfortgm3lockexception
    ldh a, [hLockDelayForce]
    cp a, 2
    jr nz, .draw ; It's not forced, so go to drawing.
    xor a, a ; It is forced, so force it!
    ldh [hCurrentLockDelayRemaining], a

    ; Play the locking sound and draw the piece.
.dolock
    ld a, SFX_LOCK
    call SFXTriggerNoise
    jr .draw

    ; If we weren't grounded, reset the lock force.
.notgrounded
    xor a, a
    ldh [hShouldLockIfGrounded], a


    ; **************************************************************
    ; HANDLE DRAWING
    ; Draw the piece.
.draw
    ; If the piece is locked, skip the ghost piece.
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr z, .postghost

    ; If the gravity is <= 1G, draw a ghost piece.
    ldh a, [hWantedG]
    cp a, 1
    jr nz, .postghost
    ld a, [wInitialA] ; Let's not do the flickering on the GBC.
    cp a, $11
    jr z, .ghost
    ldh a, [hEvenFrame]
    cp a, 1
    jr nz, .postghost

.ghost
    ldh a, [hYPosAtStartOfFrame]
    ld b, a
    ldh a, [hActualG]
    add a, b
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToFieldPtr
    ld d, h
    ld e, l
    call GetPieceData
    ld a, TILE_GHOST
    ld b, a
    push hl
    push de
    pop hl
    pop de
    call DrawPiece

    ; Bones?
.postghost
    ld a, [wBonesActive]
    cp a, $FF
    jr nz, .nobone
    ld a, TILE_BONE
    ld [hWantedTile], a

    ; Is lock delay 0 and is invis mode active?
    ld a, [wInvisActive]
    cp a, $FF
    jr nz, .drawpiece
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr nz, .drawpiece

    ; Then bones are made invis.
    ld a, TILE_INVIS
    ld [hWantedTile], a
    jr .drawpiece

    ; If the lock delay is at the highest value, draw the piece normally.
.nobone
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0
    add a, b
    ldh [hWantedTile], a
    ldh a, [hCurrentLockDelay]
    ld b, a
    ldh a, [hCurrentLockDelayRemaining]
    cp a, b
    jr z, .drawpiece

    ; If we're not grounded, draw the piece normally.
    ldh a, [hGrounded]
    cp a, $FF
    jr nz, .drawpiece

    ; If the lock delay is 0, draw the piece in the final color.
    ldh a, [hWantedTile]
    add a, 7
    ldh [hWantedTile], a
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr nz, .notlocked

    ; This might be invisible!
    ld a, [wInvisActive]
    cp a, $FF
    jr nz, .drawpiece
    ld a, TILE_INVIS
    ld [hWantedTile], a
    jr .drawpiece

    ; Otherwise, look it up.
.notlocked
    call GetTileShade

.drawpiece
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call XYToFieldPtr
    ld d, h
    ld e, l
    call GetPieceData
    ldh a, [hWantedTile]
    ld b, a
    push hl
    push de
    pop hl
    pop de
    jp DrawPiece


    ; Performs a lookup to see how "locked" the piece is.
GetTileShade:
    ldh a, [hCurrentLockDelay]
    cp a, 30
    jr nc, .max30
    cp a, 20
    jr nc, .max20
    cp a, 10
    jr nc, .max10
    jr .max0

.max30
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 4
    ret c
    cp a, 8
    jp c, .s6
    cp a, 12
    jr c, .s5
    cp a, 16
    jr c, .s4
    cp a, 20
    jr c, .s3
    cp a, 24
    jr c, .s2
    cp a, 28
    jr c, .s1
    jr .s0

.max20
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 2
    ret c
    cp a, 5
    jr c, .s6
    cp a, 7
    jr c, .s5
    cp a, 10
    jr c, .s4
    cp a, 12
    jr c, .s3
    cp a, 15
    jr c, .s2
    cp a, 17
    jr c, .s1
    jr .s0

.max10
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 1
    ret c
    cp a, 2
    jr c, .s6
    cp a, 3
    jr c, .s5
    cp a, 5
    jr c, .s4
    cp a, 6
    jr c, .s3
    cp a, 7
    jr c, .s2
    cp a, 8
    jr c, .s1
    jr .s0

.max0
    jr .s4

.s0
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0
    add a, b
    ldh [hWantedTile], a
    ret

.s1
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(2*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s2
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(3*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s3
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(4*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s4
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(5*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s5
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(6*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s6
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(7*7)
    add a, b
    ldh [hWantedTile], a
    ret


    ; This is called every frame after a piece has been locked until the delay state ends.
    ; Lines are cleared, levels and score are awarded, and ARE time is waited out.
FieldDelay::
    ; Grade decay?
    call DecayGradeDelay

    ; In delay state, DAS increments double speed.
.incl
    ldh a, [hLeftState]
    or a, a
    jr z, .incr
    inc a
    ldh [hLeftState], a

.incr
    ldh a, [hRightState]
    or a, a
    jr z, .noinc
    inc a
    ldh [hRightState], a

    ; Switch on the delay state.
.noinc
    ld a, [wDelayState]
    cp DELAY_STATE_DETERMINE_DELAY
    jr z, .determine
    cp DELAY_STATE_LINE_PRE_CLEAR
    jr z, .prelineclear
    cp DELAY_STATE_LINE_CLEAR
    jp z, .lineclear
    cp DELAY_STATE_PRE_ARE
    jp z, .preare
    jp .are


    ; Check if there were line clears.
    ; If so, we need to do a line clear delay.
    ; Otherwise, we skip to ARE delay.
.determine
    ; Increment bravo by 4.
    ldh a, [hBravo]
    add a, 4
    ldh [hBravo], a

    ; Kill screen?
    ld a, [wInStaffRoll]
    cp a, $FF
    jr z, .noskip
    ld a, [wKillScreenActive]
    cp a, $FF
    jr z, .skip

    ; Are there line clears?
.noskip
    call ToShadowField
    call FindClearedLines
    ldh a, [hClearedLines]
    ld b, a
    ldh a, [hClearedLines+1]
    ld c, a
    ldh a, [hClearedLines+2]
    ld d, a
    ldh a, [hClearedLines+3]
    and a, b
    and a, c
    and a, d
    cp a, $FF
    jr z, .skip
    ld a, DELAY_STATE_LINE_PRE_CLEAR ; If there were line clears, do a line clear delay, then a LINE_ARE delay.
    ld [wDelayState], a
    ldh a, [hCurrentLineClearDelay]
    ldh [hRemainingDelay], a
    call MarkClear
    jp .prelineclear
.skip
    ld a, DELAY_STATE_PRE_ARE ; If there were no line clears, do an ARE delay.
    ld [wDelayState], a
    ldh a, [hCurrentARE]
    ldh [hRemainingDelay], a
    jp .preare

    ; Pre-line clear delay.
    ; If we had line clears, immediately hand out the score and the levels.
.prelineclear
    ld a, DELAY_STATE_LINE_CLEAR
    ld [wDelayState], a

    ldh a, [hLineClearCt]
    or a, a
    jp z, .lineclear ; If not, just skip the phase.

    ; There were line clears! Clear the level counter breakpoint.
    xor a, a
    ldh [hRequiresLineClear], a

    ; Decrement bravo by 10 for each line clear.
    ldh a, [hLineClearCt]
    ld b, a
    ldh a, [hBravo]
.bravodecloop
    sub a, 10
    dec b
    jr nz, .bravodecloop
    ldh [hBravo], a

    ; Increment the level counter by the amount of lines.
.applylines
    ldh a, [hLineClearCt]
    ld b, a
    ld a, [wSpeedCurveState]
    cp a, 2
    jr z, .addbonus
    cp a, 4
    jr z, .addbonus
    ld a, b
    jr .neither 
.addbonus
    ld a, b
    cp a, 3
    jr z, .istriple
    cp a, 4
    jr z, .istetris
    jr .neither
.istriple
    inc a
    jr .neither
.istetris
    inc a
    inc a
    jr .neither
.neither
    ld e, a
    call LevelUp

    ; Score the line clears.
    ; Get the new level.
    ldh a, [hLevel]
    ld l, a
    ldh a, [hLevel+1]
    ld h, a

    ; Divide by 4.
    srl h
    rr l
    srl h
    rr l

    ; Add 1.
    inc hl

    ; Add soft drop points.
    ldh a, [hDownFrames]
    ld c, a
    ldh a, [hAwardDownBonus]
    add a, a
    add a, c
    ld c, a
    xor a, a
    ld b, a

    ; Final total pre-multipliers.
.premultiplier
    add hl, bc

    ; Copy the running total for multiplication.
    ld b, h
    ld c, l

    ; Do we have a bravo? x4 if so.
.bravo
    ldh a, [hBravo]
    or a, a
    jr nz, .lineclears
    add hl, bc
    jr c, .forcemax
    add hl, bc
    jr c, .forcemax
    add hl, bc
    jr c, .forcemax
    ld b, h
    ld c, l

    ; x line clears
.lineclears
    ldh a, [hLineClearCt]
    dec a
    jr z, .combo
.lineclearloop
    add hl, bc
    jr c, .forcemax
    dec a
    jr nz, .lineclearloop
    ld b, h
    ld c, l

    ; x combo
.combo
    ldh a, [hComboCt]
    dec a
    jr z, .applyscore
.comboloop
    add hl, bc
    jr c, .forcemax
    dec a
    jr nz, .comboloop
    jr .applyscore

    ; Overflow = 65535
.forcemax
    ld a, $FF
    ld h, a
    ld l, a

    ; And apply the score.
.applyscore
    ld a, l
    ldh [hScoreIncrement], a
    ld a, h
    ldh [hScoreIncrement+1], a
    call IncreaseScore

    ; Update the combo counter.
    ldh a, [hLineClearCt]
    dec a
    jr z, .dont
    cp a, $ff
    jr z, .dont
.applycombo
    ldh a, [hComboCt] ; Old combo count.
    inc a
    ldh [hComboCt], a
.dont

    ; Line clear delay.
    ; Count down the delay. If we're out of delay, clear the lines and go to LINE_ARE.
.lineclear
    ldh a, [hRemainingDelay]
    dec a
    ldh [hRemainingDelay], a
    or a, a
    ret nz

    call ClearLines
    ld a, SFX_LINE_CLEAR
    call SFXTriggerNoise

    ldh a, [hCurrentLineARE]
    ldh [hRemainingDelay], a

    ; Pre-ARE delay.
.preare
    ld a, DELAY_STATE_ARE
    ld [wDelayState], a

    ; Copy over the newly cleaned field.
    call ToShadowField

    ; Rank checks.
    call UpdateGrade

    ; Don't do anything if there were line clears
    ldh a, [hLineClearCt]
    or a, a
    jr nz, .are

    ; Otherwise, reset the combo.
    ld a, 1
    ldh [hComboCt], a

    ; ARE delay.
    ; Count down the delay. If it hits 0, award levels and score if necessary, then end the delay phase.
.are
    ldh a, [hRemainingDelay]
    dec a
    ldh [hRemainingDelay], a
    or a, a
    ret nz

    ; Add one level if we're not at a breakpoint and not in MYCO speed curve.
    ldh a, [hRequiresLineClear]
    cp a, $FF
    jr z, .generatenextpiece
    ld a, [wSpeedCurveState]
    cp a, SCURVE_MYCO
    jr z, .generatenextpiece
    cp a, SCURVE_CHIL
    jr z, .generatenextpiece
    ld e, 1
    call LevelUp

    ; Cycle the RNG.
.generatenextpiece
    ld a, [wInStaffRoll]
    cp a, $FF
    jr z, .doit
    ld a, [wShouldGoStaffRoll]
    cp a, $FF
    ret z

.doit
    ldh a, [hNextPiece]
    ldh [hCurrentPiece], a
    call GetNextPiece

    ; Kill the sound for the next piece.
    jp SFXKill


    ; Shifts B into the line clear list.
    ; Also increments the line clear count.
AppendClearedLine:
    ldh a, [hLineClearCt]
    inc a
    ldh [hLineClearCt], a
    ldh a, [hClearedLines+2]
    ldh [hClearedLines+3], a
    ldh a, [hClearedLines+1]
    ldh [hClearedLines+2], a
    ldh a, [hClearedLines]
    ldh [hClearedLines+1], a
    ld a, b
    ldh [hClearedLines], a
    ret


    ; Scans the field for lines that are completely filled with non-empty spaces.
    ; Every time one is found, it is added to a list.
FindClearedLines:
    xor a, a
    ldh [hLineClearCt], a
    ld a, $FF
    ld c, 0
    ldh [hClearedLines], a
    ldh [hClearedLines+1], a
    ldh [hClearedLines+2], a
    ldh [hClearedLines+3], a

    DEF row = 23
    REPT 24
        ld hl, wShadowField+2+(row*14)
        ld b, 11
:       ld a, [hl+]
        dec b
        cp a, $FF
        jr z, :+
        cp a, TILE_FIELD_EMPTY
        jr nz, :-
:       xor a, a
        cp a, b
        jr nz, .next\@
        ld b, 23-row
        call AppendClearedLine
        inc c
        ld a, 4
        cp a, c
        ret z
        DEF row -= 1
.next\@
    ENDR

    ret

    ; Goes through the list of cleared lines and marks those lines with the "line clear" tile.
MarkClear:
    ldh a, [hClearedLines]
    cp a, $FF
    ret z
    ld hl, wField+(24*10)
.markclear1loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear1loop
    ld bc, 10
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+1]
    cp a, $FF
    ret z
    ld hl, wField+(24*10)
.markclear2loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear2loop
    ld bc, 10
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+2]
    cp a, $FF
    ret z
    ld hl, wField+(24*10)
.markclear3loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear3loop
    ld bc, 10
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+3]
    cp a, $FF
    ret z
    ld hl, wField+(24*10)
.markclear4loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear4loop
    ld bc, 10
    ld d, TILE_CLEARING
    jp UnsafeMemSet


    ; Once again, scans the field for cleared lines, but this time removes them.
ClearLines:
    ld de, 0

    DEF row = 23
    REPT 24
        ; Check if the row begins with a clearing tile.
        ld hl, wField+(row*10)
        ld a, [hl]
        cp a, TILE_CLEARING

        ; If it does, increment the clearing counter, but skip this line.
        jr nz, .clear\@
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        jr .r\@

.clear\@
        ; If there's 0 lines that need to be moved down, skip this line.
        xor a, a
        cp a, e
        jr z, .r\@

        ; Otherwise...
        ld bc, wField+(row*10)
        add hl, de
:       ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
.r\@
        DEF row -= 1
    ENDR

    ; Make sure there's no garbage in the top de lines.
.fixgarbo
    ld hl, wField
.fixgarboloop
    xor a, a
    or a, d
    or a, e
    ret z
    ld a, TILE_FIELD_EMPTY
    ld [hl+], a
    dec de
    jr .fixgarboloop



SECTION "Field Function Banked Gameplay Big", ROMX, BANK[BANK_GAMEPLAY_BIG]
    ; Initializes the field completely blank.
    ; Initializes the combo counter to 1.
    ; Initializes the bravo counter to 0.
    ; Initializes the shadow field.
BigFieldInit::
    xor a, a
    ldh [hBravo], a
    ldh [hLineClearCt], a
    ld [wMovementLastFrame], a
    ld a, 1
    ldh [hComboCt], a
    ld hl, wField
    ld bc, 10*24
    ld d, TILE_BLANK
    call UnsafeMemSet
    ld hl, wWideBlittedField
    ld bc, 10*22
    ld d, TILE_BLANK
    call UnsafeMemSet
    ld hl, wShadowField
    ld bc, 14*26
    ld d, $FF
    call UnsafeMemSet
    ld hl, wPreShadowField
    ld bc, 14*2
    ld d, $FF
    call UnsafeMemSet
    ld a, SLAM_ANIMATION_LEN
    ld [wLeftSlamTimer], a
    ld [wRightSlamTimer], a
    ret

    ; Fills the field with the empty tile.
BigFieldClear::
    ld hl, wField
    ld bc, 10*24
    ld d, 0
    call UnsafeMemSet
    DEF row = 0
    REPT 14
        ld hl, wField + (row*10)
        ld bc, 5
        ld d, TILE_FIELD_EMPTY
        call UnsafeMemSet
        DEF row += 1
    ENDR
    ret


GoSmall::
    xor a, a
    ldh [hBravo], a
    ldh [hLineClearCt], a
    ld [wMovementLastFrame], a
    ld a, 1
    ldh [hComboCt], a
    ld hl, wField
    ld bc, 10*24
    ld d, TILE_BLANK
    call UnsafeMemSet
    ld hl, wShadowField
    ld bc, 14*26
    ld d, $FF
    call UnsafeMemSet
    ld hl, wPreShadowField
    ld bc, 14*2
    ld d, $FF
    call UnsafeMemSet
    ld a, SLAM_ANIMATION_LEN
    ld [wLeftSlamTimer], a
    ld [wRightSlamTimer], a
    ld a, STATE_GAMEPLAY
    ldh [hGameState], a
    ret


    ; Backs up the field.
    ; This backup field is used for pausing the game.
BigToBackupField::
    ld de, wField
    ld hl, wBackupField
    ld bc, 10*24
    jp UnsafeMemCopy


    ; Restores the backup of the field for ending pause mode.
BigFromBackupField::
    ld hl, wField
    ld de, wBackupField
    ld bc, 10*24
    jp UnsafeMemCopy


    ; Copies the field to the shadow field.
    ; This shadow field is used to calculate whether or not the piece can fit.
BigToShadowField::
    ld hl, wField
    ld de, wShadowField+2
    ld c, 24
.outer
    ld b, 10
.inner
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .inner
    inc de
    inc de
    inc de
    inc de
    dec c
    jr nz, .outer
    ret


    ; Restores the shadow field to the main field.
BigFromShadowField:
    ld hl, wField
    ld de, wShadowField+2
    ld c, 24
.outer
    ld b, 10
.inner
    ld a, [de]
    ld [hl+], a
    inc de
    dec b
    jr nz, .inner
    inc de
    inc de
    inc de
    inc de
    dec c
    jr nz, .outer
    ret

    ; The current piece ID is used to get the offset into the rotation states
    ; corresponding to that piece's zero rotation.
BigSetPieceData:
    ldh a, [hCurrentPiece]
    add a, a
    add a, a
    add a, a
    add a, a
    ld c, a
    ld b, 0

    ld hl, sBigPieceRotationStates
    add hl, bc
    ld a, l
    ldh [hPieceDataBase], a
    ld a, h
    ldh [hPieceDataBase+1], a

    ld hl, sBigPieceFastRotationStates
    add hl, bc
    ld a, l
    ldh [hPieceDataBaseFast], a
    ld a, h
    ldh [hPieceDataBaseFast+1], a
    ret


    ; The rotation state is a further offset of 4 bytes.
BigSetPieceDataOffset:
    ldh a, [hCurrentPieceRotationState]
    add a, a
    add a, a
    ldh [hPieceDataOffset], a
    ret


    ; Converts piece Y in B and a piece X in A to a pointer to the shadow field in HL.
BigXYToSFieldPtr:
    ld hl, wShadowField
    ld de, 14
    inc a
    inc b
.a
    dec b
    jr z, .b
    add hl, de
    jr .a
.b
    dec a
    ret z
    inc hl
    jr .b


    ; Converts piece Y in B and a piece X in A to a pointer to the field in HL.
BigXYToFieldPtr:
    ld hl, wField-2
    ld de, 10
    inc a
    inc b
.a
    dec b
    jr z, .b
    add hl, de
    jr .a
.b
    dec a
    ret z
    inc hl
    jr .b


    ; This function makes HL point to the correct offset into the rotation data.
    ; This version of the data is used for thorough checking (T, J, and L have
    ; a middle column exception.)
BigGetPieceData:
    ldh a, [hPieceDataBase]
    ld l, a
    ldh a, [hPieceDataBase+1]
    ld h, a
    ldh a, [hPieceDataOffset]
    ld c, a
    ld b, 0
    add hl, bc
    ret


    ; Same as the above but for the fast data. This data is used when the exact
    ; cell that failed isn't important.
BigGetPieceDataFast:
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hPieceDataOffset]
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    ret


    ; Checks if the piece can fit at the current position.
    ; HL should point to the piece's rotation state data.
    ; DE should be pointing to the right place in the SHADOW field.
    ; This will return with $FF in A if the piece fits, or with the
    ; exact cell that caused the first failure in A.
BigCanPieceFit:
    xor a, a
    ld b, a

    ; Row 1
    bit 3, [hl]
    jr z, .skipr1a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr1b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr1c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr1c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r1end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

.r1end
    REPT 11
        inc de
    ENDR

    ; Row 2
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr2a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr2b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr2c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr2c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r2end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

.r2end
    REPT 11
        inc de
    ENDR

    ; Row 3
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr3a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr3b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr3c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr3c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r3end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ret nz

.r3end
    REPT 11
        inc de
    ENDR

    ; Row 4
    inc b
    inc hl
    bit 3, [hl]
    jr z, .skipr4a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4a
    inc de
    inc b
    bit 2, [hl]
    jr z, .skipr4b
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4b
    inc de
    inc b
    bit 1, [hl]
    jr z, .skipr4c
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz
.skipr4c
    inc de
    inc b
    bit 0, [hl]
    jr z, .r4end
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    ld a, b
    ret nz

    ; If we got here, the piece can fit.
.r4end
    ld a, $FF
    ret


    ; Checks if the piece can fit at the current position, but fast.
    ; HL should point to the piece's fast rotation state data.
    ; DE should be pointing to the right place in the SHADOW field.
    ; This will return with $FF in A if the piece fits, or with a non-$FF
    ; value if it doesn't.
BigCanPieceFitFast:
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip1
    xor a, a
    ret
.skip1
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip2
    xor a, a
    ret
.skip2
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip3
    xor a, a
    ret
.skip3
    ld a, [hl+]
    add a, e
    ld e, a
    adc a, d
    sub e
    ld d, a
    ld a, [de]
    cp a, TILE_FIELD_EMPTY
    jr z, .skip4
    xor a, a
    ret
.skip4
    ld a, $FF
    ret


    ; This function will draw the piece even if it can't fit.
    ; We use this to draw a final failed spawn before going game
    ; over.
BigForceSpawnPiece::
    call BigSetPieceData
    call BigSetPieceDataOffset
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceData
    ld b, GAME_OVER_OTHER
    push hl
    push de
    pop hl
    pop de
    jp BigDrawPiece


    ; Initialize the state for a new piece and attempts to spawn it.
    ; On return, A will be $FF if the piece fit.
BigTrySpawnPiece::
    ; Always reset these for a new piece.
    xor a, a
    ldh [hStalePiece], a
    ldh [hDownFrames], a
    ldh [hAwardDownBonus], a
    ldh [hLockDelayForce], a
    ldh [hShouldLockIfGrounded], a
    ldh [hGravityCtr], a
    ldh [hGrounded], a
    ld [wMovementLastFrame], a
    ld a, SLAM_ANIMATION_LEN
    ld [wLeftSlamTimer], a
    ld [wRightSlamTimer], a
    ld a, -2
    ldh [rSCX], a
    ldh a, [hCurrentLockDelay]
    ldh [hCurrentLockDelayRemaining], a
    ld a, $FF
    ldh [hRemainingDelay], a
    ld a, DELAY_STATE_DETERMINE_DELAY
    ld [wDelayState], a

    ; Point the piece data to the correct piece.
    call BigSetPieceData
    call BigSetPieceDataOffset

    ; Get the piece's spawn position.
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr

    ; Check if the piece can spawn.
    ld d, h
    ld e, l
    call BigGetPieceDataFast
    call BigCanPieceFitFast

    ; A will be $FF if the piece can fit.
    cp a, $FF
    ret z

    ; If we didn't try to IRS in the first place, too bad. Game over.
    ldh a, [hCurrentPieceRotationState]
    or a, a
    ret z

    ; Try rotation state 0.
.try0
    xor a, a
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceDataFast
    jp BigCanPieceFitFast


    ; Draws the piece onto the field.
    ; B is the tile.
    ; DE should point to the piece's rotation state data.
    ; HL should be pointing to the right place in the NORMAL field.
BigDrawPiece:
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr1a
    ld [hl], b
.skipr1a
    inc hl
    bit 2, a
    jr z, .skipr1b
    ld [hl], b
.skipr1b
    inc hl
    bit 1, a
    jr z, .skipr1c
    ld [hl], b
.skipr1c
    inc hl
    bit 0, a
    jr z, .r1end
    ld [hl], b

.r1end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr2a
    ld [hl], b
.skipr2a
    inc hl
    bit 2, a
    jr z, .skipr2b
    ld [hl], b
.skipr2b
    inc hl
    bit 1, a
    jr z, .skipr2c
    ld [hl], b
.skipr2c
    inc hl
    bit 0, a
    jr z, .r2end
    ld [hl], b

.r2end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr3a
    ld [hl], b
.skipr3a
    inc hl
    bit 2, a
    jr z, .skipr3b
    ld [hl], b
.skipr3b
    inc hl
    bit 1, a
    jr z, .skipr3c
    ld [hl], b
.skipr3c
    inc hl
    bit 0, a
    jr z, .r3end
    ld [hl], b

.r3end
    REPT 7
        inc hl
    ENDR
    ld a, [de]
    inc de

    bit 3, a
    jr z, .skipr4a
    ld [hl], b
.skipr4a
    inc hl
    bit 2, a
    jr z, .skipr4b
    ld [hl], b
.skipr4b
    inc hl
    bit 1, a
    jr z, .skipr4c
    ld [hl], b
.skipr4c
    inc hl
    bit 0, a
    ret z
    ld [hl], b
    ret


BigFindMaxG:
    ; Find the deepest the piece can go.
    ; We cache this pointer, cause it otherwise takes too much time.
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr

    push hl
    ld a, 1
    ldh [hActualG], a
.try
    ld de, 14
    pop hl
    add hl, de
    push hl
    ld d, h
    ld e, l
    call BigGetPieceDataFast
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .found
    ldh a, [hActualG]
    inc a
    ldh [hActualG], a
    jr .try

.found
    pop hl
    ldh a, [hActualG]
    dec a
    ldh [hActualG], a
    ret


    ; This is the main function that will process input, gravity, and locking.
    ; It should be ran once per frame as long as lock delay is greater than 0.
BigFieldProcess::
    ; **************************************************************
    ; SETUP
    ; Grade decay?
    call DecayGradeProcess

    ; Apply screen shake if needed.
.leftslam
    ld a, [wLeftSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr z, .rightslam
    ld b, 0
    ld c, a
    ld hl, sBigLeftDasSlam
    add hl, bc
    inc a
    ld [wLeftSlamTimer], a
    ld a, [hl]
    ldh [rSCX], a
    jr .wipe

.rightslam
    ld a, [wRightSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr z, .wipe
    ld b, 0
    ld c, a
    ld hl, sBigRightDasSlam
    add hl, bc
    inc a
    ld [wRightSlamTimer], a
    ld a, [hl]
    ldh [rSCX], a

    ; Wipe out the piece.
.wipe
    ldh a, [hCurrentPieceY]
    ldh [hYPosAtStartOfFrame], a
    call BigFromShadowField

    ; Cleanup from last frame.
    ldh a, [hCurrentPieceRotationState]
    ldh [hWantRotation], a

    ; Is this the first frame of the piece?
.firstframe
    ldh a, [hStalePiece]
    or a, a
    jr nz, .handleselect
    ld a, $FF
    ldh [hStalePiece], a
    jp .skipmovement


    ; **************************************************************
    ; HANDLE SELECT
    ; Check if we're about to hold. Return if so.
.handleselect
    ldh a, [hSelectState]
    cp a, 1
    jr nz, .wantrotccw
    ldh a, [hHoldSpent]
    cp a, $FF
    ret nz


    ; **************************************************************
    ; HANDLE ROTATION
    ; Want rotate CCW?
.wantrotccw
    ld a, [wSwapABState]
    or a, a
    jr z, .ldb1
.lda1
    ldh a, [hAState]
    jr .cp1
.ldb1
    ldh a, [hBState]
.cp1
    cp a, 1
    jr nz, .wantrotcw
    ldh a, [hWantRotation]
    inc a
    and a, $03
    ldh [hWantRotation], a
    jr .tryrot

    ; Want rotate CW?
.wantrotcw
    ld a, [wSwapABState]
    or a, a
    jr z, .lda2
.ldb2
    ldh a, [hBState]
    jr .cp2
.lda2
    ldh a, [hAState]
.cp2
    cp a, 1
    jp nz, .norot
    ldh a, [hWantRotation]
    dec a
    and a, $03
    ldh [hWantRotation], a

    ; Try the rotation.
.tryrot
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBase]
    ld l, a
    ldh a, [hPieceDataBase+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFit ; This does have to be the "slow" version.
    cp a, $FF
    jr nz, .maybekick
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try kicks if the piece isn't I or O. And in the case of J L and T, only if the blocked side is the left or right.
.maybekick
    ld c, a
    ; No kicks for NES mode.
    ld a, [wRotModeState]
    cp a, ROT_MODE_NES
    jp z, .norot

    ldh a, [hCurrentPiece]
    ; O pieces never kick, obviously.
    cp a, PIECE_O
    jp z, .norot

    ; MYCO always tries to kick.
    ld a, [wRotModeState]
    cp a, ROT_MODE_MYCO
    jp z, .trykickright
    ldh a, [hCurrentPiece]

    ; S/Z always kick.
    cp a, PIECE_S
    jr z, .trykickright
    cp a, PIECE_Z
    jr z, .trykickright

    ; I piece only kicks in ARS2
    cp a, PIECE_I
    jr nz, .tljexceptions
    ld a, [wRotModeState]
    cp a, ROT_MODE_ARSTI
    jp nz, .norot
    ldh a, [hWantRotation]
    bit 0, a
    jp nz, .checki
    jr .trykickright

    ; T/L/J only kick if not through the middle axis.
.tljexceptions
    ld a, c
    cp a, 1
    jp z, .maybetgm3rot
    cp a, 5
    jp z, .maybetgm3rot
    cp a, 9
    jr z, .maybetgm3rot

    ; A step to the right.
.trykickright
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    inc a
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .trykickleft
    ldh a, [hCurrentPieceX]
    inc a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; And a step to the left.
.trykickleft
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    or a, a
    jr z, .maybetgm3rot
    dec a
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .maybetgm3rot
    ldh a, [hCurrentPieceX]
    dec a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; In ARS2 mode, there are a few other kicks possible.
.maybetgm3rot
    ld a, [wRotModeState]
    cp a, ROT_MODE_ARSTI
    jp nz, .norot

    ; In the case of a T piece, try the space above.
.checkt
    ldh a, [hCurrentPiece]
    cp a, PIECE_T
    jr nz, .checki

.tkickup
    ldh a, [hCurrentPieceY]
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jp nz, .norot
    ldh a, [hCurrentPieceY]
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .tkickupalreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.tkickupalreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; In the case of an I piece...
.checki
    ldh a, [hCurrentPiece]
    cp a, PIECE_I
    jp nz, .norot

    ; What direction do we want to end up?
    ldh a, [hWantRotation]
    bit 0, a
    jp z, .tryiright2   ; Flat? Sideways kicks are fine.
                        ; Upright? Only up kicks.

    ; Are we grounded? Don't kick if we aren't.
    ldh a, [hActualG]
    or a, a
    jp nz, .norot

    ; Try up once.
.tryiup1
    ldh a, [hCurrentPieceY]
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .tryiup2
    ldh a, [hCurrentPieceY]
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .ikick1upalreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.ikick1upalreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try up twice.
.tryiup2
    ldh a, [hCurrentPieceY]
    dec a
    dec a
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .norot
    ldh a, [hCurrentPieceY]
    dec a
    dec a
    ldh [hCurrentPieceY], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set lock delay forcing to 1 if it's 0.
    or a, a
    jr nz, .ikick2upalreadysetforce
    inc a
    ldh [hLockDelayForce], a
    jp .norot
.ikick2upalreadysetforce
    cp a, 1                  ; Or to 2 if it's 1.
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a
    jp .norot

    ; Try right twice.
.tryiright2
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    inc a
    inc a
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    ldh a, [hPieceDataBaseFast]
    ld l, a
    ldh a, [hPieceDataBaseFast+1]
    ld h, a
    ldh a, [hWantRotation]
    add a, a
    add a, a
    push bc
    ld c, a
    xor a, a
    ld b, a
    add hl, bc
    pop bc
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .norot
    ldh a, [hCurrentPieceX]
    inc a
    inc a
    ldh [hCurrentPieceX], a
    ldh a, [hWantRotation]
    ldh [hCurrentPieceRotationState], a
    call BigSetPieceDataOffset
    ldh a, [hLockDelayForce] ; Set the forced lock delay to 2 if it's 1.
    cp a, 1
    jp nz, .norot
    inc a
    ldh [hLockDelayForce], a


    ; **************************************************************
    ; HANDLE MOVEMENT
    ; Do we want to move left?
.norot
    ldh a, [hCurrentPieceX]
    ldh [hWantX], a

.wantleft
    ldh a, [hCurrentPieceX]
    or a, a
    jr z, .precheckright
    ldh a, [hLeftState] ; Check if held for 1 frame. If so we move.
    cp a, 1
    jr z, .doleft
    or a, a             ; We never want to move if the button wasn't held.
    jr z, .wantright
    ld b, a
.checkdasleft
    ldh a, [hCurrentDAS]
    ld c, a
    ld a, b
    cp a, c
    jr c, .wantright
.doleft
    ldh a, [hWantX]
    dec a
    ldh [hWantX], a
    jr .trymove

.precheckright
    ldh a, [hRightState]
    or a, a
    jr z, .nomove

    ; Do we want to move right?
.wantright
    ldh a, [hRightState] ; Check if held for 1 frame. If so we move.
    cp a, 1
    jr z, .doright
    or a, a             ; We never want to move if the button wasn't held.
    jr z, .noeffect
    ld b, a
.checkdasright
    ldh a, [hCurrentDAS]
    ld c, a
    ld a, b
    cp a, c
    jr c, .noeffect
.doright
    ldh a, [hWantX]
    inc a
    ldh [hWantX], a

    ; Try the movement.
.trymove
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hWantX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceDataFast
    call BigCanPieceFitFast
    cp a, $FF
    jr nz, .nomove
    ld a, $FF
    ld [wMovementLastFrame], a
    ldh a, [hWantX]
    ldh [hCurrentPieceX], a
    jr .donemanipulating

.nomove
    ld a, [wMovementLastFrame]
    or a, a
    jr z, .noeffect

    ; We moved last frame but couldn't move this frame. That means we slammed into a wall.
    ; First check if either effect is playing and that we're not in 20G.
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr z, .noeffect
    ld a, [wLeftSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr nz, .noeffect
    ld a, [wRightSlamTimer]
    cp a, SLAM_ANIMATION_LEN
    jr nz, .noeffect

    ; Which wall did we slam into?
    ldh a, [hWantX]
    ld b, a
    ldh a, [hCurrentPieceX]
    cp a, b
    jr c, .slamright

.slamleft
    xor a, a
    ld [wLeftSlamTimer], a
    jr .noeffect

.slamright
    xor a, a
    ld [wRightSlamTimer], a

.noeffect
    xor a, a
    ld [wMovementLastFrame], a


    ; **************************************************************
    ; HANDLE MAXIMUM FALL
    ; This little maneuver is going to cost us 51 years.
.skipmovement
.donemanipulating
    call BigFindMaxG


    ; **************************************************************
    ; HANDLE UP
    ; Assume 1G or lower.
    ld a, 1
    ldh [hWantedG], a

    ; Is a hard/sonic drop requested?
    ldh a, [hUpState]
    cp a, 1
    jr nz, .postdrop

    ; What kind, if any?
    ld a, [wDropModeState]
    cp a, DROP_MODE_NONE
    jr z, .postdrop
    cp a, DROP_MODE_LOCK
    jr z, .harddrop
    cp a, DROP_MODE_HARD
    jr z, .harddrop

    ; Sonic drop.
.sonicdrop
    ; Skip in 20G mode.
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr z, .postdrop
    ld a, [wDropModeState]
    cp a, DROP_MODE_SNIC
    jr z, .sonicneutrallockskip
    ld a, $FF
    ldh [hShouldLockIfGrounded], a
.sonicneutrallockskip
    ld a, $FF
    ldh [hAwardDownBonus], a
    ld a, 20
    ldh [hWantedG], a
    jr .grav

    ; Hard drop.
.harddrop
    ld a, $FF
    ldh [hAwardDownBonus], a
    ld a, 20
    ldh [hWantedG], a
    ld b, a
    ldh a, [hActualG]
    cp a, b
    jr nc, .donedeterminingharddropdistance
    ld b, a
.donedeterminingharddropdistance
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    xor a, a
    ldh [hCurrentLockDelayRemaining], a
    ld a, $FF
    ldh [hGrounded], a
    ld a, SFX_LOCK
    call SFXTriggerNoise
    jp .draw

    ; If we press down, we want to do a soft drop.
.postdrop
    ldh a, [hDownState]
    or a, a
    jr z, .checkregulargravity
    ldh a, [hDownFrames]
    inc a
    ldh [hDownFrames], a
    ld a, $FF
    ldh [hGravityCtr], a
    ld a, [wDropModeState]
    cp a, DROP_MODE_HARD
    jr nz, .checkregulargravity
    ld a, $FF
    ldh [hShouldLockIfGrounded], a

    ; Gravity?
.checkregulargravity
    ldh a, [hCurrentFractionalGravity]
    cp a, $00 ; 0 is the sentinel value that should be interpreted as "every frame"
    jr z, .alwaysgravitysentinel
    ld b, a
    ldh a, [hGravityCtr]
    add a, b
    ldh [hGravityCtr], a
    jr nc, .nograv
.alwaysgravitysentinel
    ldh a, [hCurrentIntegerGravity]
    ldh [hWantedG], a

    ; Can we drop the full requested distance?
.grav
    ldh a, [hWantedG]
    ld b, a
    ldh a, [hActualG]
    cp a, b
    jr c, .smallg

    ; Yes. Do it.
.bigg
    ldh a, [hWantedG]
    ld b, a
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    ldh a, [hAwardDownBonus]
    cp a, $FF
    jr nz, .postgrav
    ld a, b
    ldh [hAwardDownBonus], a
    jr .postgrav

    ; No. Smaller distance.
.smallg
    ldh a, [hActualG]
    ld b, a
    ldh a, [hCurrentPieceY]
    add a, b
    ldh [hCurrentPieceY], a
    ldh a, [hAwardDownBonus]
    cp a, $FF
    jr nz, .postgrav
    ld a, b
    ldh [hAwardDownBonus], a


    ; **************************************************************
    ; HANDLE LOCKING
    ; Are we grounded?
.postgrav
.nograv
    xor a, a
    ldh [hGrounded], a
    ldh a, [hYPosAtStartOfFrame]
    ld b, a
    ldh a, [hCurrentPieceY]
    cp a, b
    jr z, .noreset
    ldh a, [hCurrentLockDelay]
    ldh [hCurrentLockDelayRemaining], a
.noreset
    ldh a, [hCurrentPieceY]
    inc a
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToSFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceDataFast
    call BigCanPieceFitFast
    cp a, $FF
    jp z, .notgrounded

    ; We're grounded.
.grounded
    ld a, $FF
    ldh [hGrounded], a
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hYPosAtStartOfFrame]
    cp a, b
    jr z, .postcheckforfirmdropsound ; Never play the sound if we didn't change rows.
    ldh a, [hDownState]
    or a, a
    jr nz, .postcheckforfirmdropsound ; Don't play the sound if we're holding down.

    ; Play the firm drop sound.
.playfirmdropsound
    ld a, SFX_LAND
    call SFXTriggerNoise

    ; If the down button is held, lock.
.postcheckforfirmdropsound
    ldh a, [hDownState]
    or a, a
    jr z, .neutralcheck

    ; Don't lock on down for hard drop mode immediately.
    ld a, [wDropModeState]
    cp a, DROP_MODE_HARD
    jr nz, .downlock20gexceptioncheck
    ld a, $FF
    ldh [hShouldLockIfGrounded], a
    jr .dontforcelock

    ; Lock on down in modes <20G.
.downlock20gexceptioncheck
    ldh a, [hCurrentIntegerGravity]
    cp a, 20
    jr nz, .forcelock

    ; In 20G mode, only lock if down has been pressed for exactly 1 frame.
    ldh a, [hDownState]
    cp a, 1
    jr z, .forcelock
    jr .dontforcelock

    ; If the down button is not held, check if we're neutral and if that should lock.
.neutralcheck
    ldh a, [hShouldLockIfGrounded]
    or a, a
    jr z, .dontforcelock

    ; Check for neutral.
    ldh a, [hUpState]
    or a, a
    jr nz, .dontforcelock
    ldh a, [hLeftState]
    or a, a
    jr nz, .dontforcelock
    ldh a, [hRightState]
    or a, a
    jr nz, .dontforcelock

    ; Lock on neutral for a few modes.
    ld a, [wDropModeState]
    cp a, DROP_MODE_FIRM
    jr z, .forcelock
    cp a, DROP_MODE_HARD
    jr z, .forcelock
    jr .dontforcelock

    ; Set the lock delay to 0 and save it.
.forcelock
    xor a, a
    ldh [hCurrentLockDelayRemaining], a
    jr .dolock

    ; Load the lock delay.
    ; Decrement it by one and save it.
.dontforcelock
    ldh a, [hCurrentLockDelayRemaining]
    dec a
    ldh [hCurrentLockDelayRemaining], a

    ; Are we out of lock delay?
.checklockdelay
    or a, a
    jr nz, .checkfortgm3lockexception ; If not, check if the TGM3 exception applies.
    jr .dolock ; Otherwise, lock!

    ; TGM3 sometimes forces a piece to immediately lock.
.checkfortgm3lockexception
    ldh a, [hLockDelayForce]
    cp a, 2
    jr nz, .draw ; It's not forced, so go to drawing.
    xor a, a ; It is forced, so force it!
    ldh [hCurrentLockDelayRemaining], a

    ; Play the locking sound and draw the piece.
.dolock
    ld a, SFX_LOCK
    call SFXTriggerNoise
    jr .draw

    ; If we weren't grounded, reset the lock force.
.notgrounded
    xor a, a
    ldh [hShouldLockIfGrounded], a


    ; **************************************************************
    ; HANDLE DRAWING
    ; Draw the piece.
.draw
    ; If the piece is locked, skip the ghost piece.
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr z, .postghost

    ; If the gravity is <= 1G, draw a ghost piece.
    ldh a, [hWantedG]
    cp a, 1
    jr nz, .postghost
    ld a, [wInitialA] ; Let's not do the flickering on the GBC.
    cp a, $11
    jr z, .ghost
    ldh a, [hEvenFrame]
    cp a, 1
    jr nz, .postghost

.ghost
    ldh a, [hYPosAtStartOfFrame]
    ld b, a
    ldh a, [hActualG]
    add a, b
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceData
    ld a, TILE_GHOST
    ld b, a
    push hl
    push de
    pop hl
    pop de
    call BigDrawPiece

    ; Bones?
.postghost
    ld a, [wBonesActive]
    cp a, $FF
    jr nz, .nobone
    ld a, TILE_BONE
    ld [hWantedTile], a

    ; Is lock delay 0 and is invis mode active?
    ld a, [wInvisActive]
    cp a, $FF
    jr nz, .drawpiece
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr nz, .drawpiece

    ; Then bones are made invis.
    ld a, TILE_INVIS
    ld [hWantedTile], a
    jr .drawpiece

    ; If the lock delay is at the highest value, draw the piece normally.
.nobone
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0
    add a, b
    ldh [hWantedTile], a
    ldh a, [hCurrentLockDelay]
    ld b, a
    ldh a, [hCurrentLockDelayRemaining]
    cp a, b
    jr z, .drawpiece

    ; If we're not grounded, draw the piece normally.
    ldh a, [hGrounded]
    cp a, $FF
    jr nz, .drawpiece

    ; If the lock delay is 0, draw the piece in the final color.
    ldh a, [hWantedTile]
    add a, 7
    ldh [hWantedTile], a
    ldh a, [hCurrentLockDelayRemaining]
    or a, a
    jr nz, .notlocked

    ; This might be invisible!
    ld a, [wInvisActive]
    cp a, $FF
    jr nz, .drawpiece
    ld a, TILE_INVIS
    ld [hWantedTile], a
    jr .drawpiece

    ; Otherwise, look it up.
.notlocked
    call BigGetTileShade

.drawpiece
    ldh a, [hCurrentPieceY]
    ld b, a
    ldh a, [hCurrentPieceX]
    call BigXYToFieldPtr
    ld d, h
    ld e, l
    call BigGetPieceData
    ldh a, [hWantedTile]
    ld b, a
    push hl
    push de
    pop hl
    pop de
    call BigDrawPiece
    jp BigWidenField


    ; Performs a lookup to see how "locked" the piece is.
BigGetTileShade:
    ldh a, [hCurrentLockDelay]
    cp a, 30
    jr nc, .max30
    cp a, 20
    jr nc, .max20
    cp a, 10
    jr nc, .max10
    jr .max0

.max30
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 4
    ret c
    cp a, 8
    jp c, .s6
    cp a, 12
    jr c, .s5
    cp a, 16
    jr c, .s4
    cp a, 20
    jr c, .s3
    cp a, 24
    jr c, .s2
    cp a, 28
    jr c, .s1
    jr .s0

.max20
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 2
    ret c
    cp a, 5
    jr c, .s6
    cp a, 7
    jr c, .s5
    cp a, 10
    jr c, .s4
    cp a, 12
    jr c, .s3
    cp a, 15
    jr c, .s2
    cp a, 17
    jr c, .s1
    jr .s0

.max10
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 1
    ret c
    cp a, 2
    jr c, .s6
    cp a, 3
    jr c, .s5
    cp a, 5
    jr c, .s4
    cp a, 6
    jr c, .s3
    cp a, 7
    jr c, .s2
    cp a, 8
    jr c, .s1
    jr .s0

.max0
    jr .s4

.s0
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0
    add a, b
    ldh [hWantedTile], a
    ret

.s1
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(2*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s2
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(3*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s3
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(4*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s4
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(5*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s5
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(6*7)
    add a, b
    ldh [hWantedTile], a
    ret

.s6
    ldh a, [hCurrentPiece]
    ld b, TILE_PIECE_0+(7*7)
    add a, b
    ldh [hWantedTile], a
    ret


    ; This is called every frame after a piece has been locked until the delay state ends.
    ; Lines are cleared, levels and score are awarded, and ARE time is waited out.
BigFieldDelay::
    ; Grade decay?
    call DecayGradeDelay

    ; In delay state, DAS increments double speed.
.incl
    ldh a, [hLeftState]
    or a, a
    jr z, .incr
    inc a
    ldh [hLeftState], a

.incr
    ldh a, [hRightState]
    or a, a
    jr z, .noinc
    inc a
    ldh [hRightState], a

    ; Switch on the delay state.
.noinc
    ld a, [wDelayState]
    cp DELAY_STATE_DETERMINE_DELAY
    jr z, .determine
    cp DELAY_STATE_LINE_PRE_CLEAR
    jr z, .prelineclear
    cp DELAY_STATE_LINE_CLEAR
    jp z, .lineclear
    cp DELAY_STATE_PRE_ARE
    jp z, .preare
    jp .are


    ; Check if there were line clears.
    ; If so, we need to do a line clear delay.
    ; Otherwise, we skip to ARE delay.
.determine
    ; Increment bravo by 4.
    ldh a, [hBravo]
    add a, 4
    ldh [hBravo], a

    ; Kill screen?
    ld a, [wInStaffRoll]
    cp a, $FF
    jr z, .noskip
    ld a, [wKillScreenActive]
    cp a, $FF
    jr z, .skip

    ; Are there line clears?
.noskip
    call BigToShadowField
    call BigFindClearedLines
    ldh a, [hClearedLines]
    ld b, a
    ldh a, [hClearedLines+1]
    ld c, a
    ldh a, [hClearedLines+2]
    ld d, a
    ldh a, [hClearedLines+3]
    and a, b
    and a, c
    and a, d
    cp a, $FF
    jr z, .skip
    ld a, DELAY_STATE_LINE_PRE_CLEAR ; If there were line clears, do a line clear delay, then a LINE_ARE delay.
    ld [wDelayState], a
    ldh a, [hCurrentLineClearDelay]
    ldh [hRemainingDelay], a
    call BigMarkClear
    jp .prelineclear
.skip
    ld a, DELAY_STATE_PRE_ARE ; If there were no line clears, do an ARE delay.
    ld [wDelayState], a
    ldh a, [hCurrentARE]
    ldh [hRemainingDelay], a
    jp .preare


    ; Pre-line clear delay.
    ; If we had line clears, immediately hand out the score and the levels.
.prelineclear
    ld a, DELAY_STATE_LINE_CLEAR
    ld [wDelayState], a

    ldh a, [hLineClearCt]
    or a, a
    jp z, .lineclear ; If not, just skip the phase.

    ; There were line clears! Clear the level counter breakpoint.
    xor a, a
    ldh [hRequiresLineClear], a

    ; Decrement bravo by 10 for each line clear.
    ldh a, [hLineClearCt]
    ld b, a
    ldh a, [hBravo]
.bravodecloop
    sub a, 10
    dec b
    jr nz, .bravodecloop
    ldh [hBravo], a

    ; Increment the level counter by the amount of lines.
.applylines
    ldh a, [hLineClearCt]
    ld b, a
    ld a, [wSpeedCurveState]
    cp a, 2
    jr z, .addbonus
    cp a, 4
    jr z, .addbonus
    ld a, b
    jr .neither
.addbonus
    ld a, b
    cp a, 3
    jr z, .istriple
    cp a, 4
    jr z, .istetris
    jr .neither
.istriple
    inc a
    jr .neither
.istetris
    inc a
    inc a
    jr .neither
.neither
    ld e, a
    call LevelUp

    ; Score the line clears.
    ; Get the new level.
    ldh a, [hLevel]
    ld l, a
    ldh a, [hLevel+1]
    ld h, a

    ; Divide by 4.
    srl h
    rr l
    srl h
    rr l

    ; Add 1.
    inc hl

    ; Add soft drop points.
    ldh a, [hDownFrames]
    ld c, a
    ldh a, [hAwardDownBonus]
    add a, a
    add a, c
    ld c, a
    xor a, a
    ld b, a

    ; Final total pre-multipliers.
.premultiplier
    add hl, bc

    ; Copy the running total for multiplication.
    ld b, h
    ld c, l

    ; Do we have a bravo? x4 if so.
.bravo
    ldh a, [hBravo]
    or a, a
    jr nz, .lineclears
    add hl, bc
    jr c, .forcemax
    add hl, bc
    jr c, .forcemax
    add hl, bc
    jr c, .forcemax
    ld b, h
    ld c, l

    ; x line clears
.lineclears
    ldh a, [hLineClearCt]
    dec a
    jr z, .combo
.linecleardecloop
    add hl, bc
    jr c, .forcemax
    dec a
    jr nz, .linecleardecloop
    ld b, h
    ld c, l

    ; x combo
.combo
    ldh a, [hComboCt]
    dec a
    jr z, .applyscore
.combodecloop
    add hl, bc
    jr c, .forcemax
    dec a
    jr nz, .combodecloop
    jr .applyscore

    ; Overflow = 65535
.forcemax
    ld a, $FF
    ld h, a
    ld l, a

    ; And apply the score.
.applyscore
    ld a, l
    ldh [hScoreIncrement], a
    ld a, h
    ldh [hScoreIncrement+1], a
    call IncreaseScore

    ; Update the combo counter.
    ldh a, [hLineClearCt]
    ld b, a
    ldh a, [hComboCt] ; Old combo count.
    add a, b          ; + lines
    add a, b          ; + lines
    sub a, 2          ; - 2
    ldh [hComboCt], a

    ; Line clear delay.
    ; Count down the delay. If we're out of delay, clear the lines and go to LINE_ARE.
.lineclear
    ldh a, [hRemainingDelay]
    dec a
    ldh [hRemainingDelay], a
    or a, a
    jp nz, BigWidenField

    call BigClearLines
    ld a, SFX_LINE_CLEAR
    call SFXTriggerNoise

    ldh a, [hCurrentLineARE]
    ldh [hRemainingDelay], a


    ; Pre-ARE delay.
.preare
    ld a, DELAY_STATE_ARE
    ld [wDelayState], a

    ; Copy over the newly cleaned field.
    call BigToShadowField

    ; Rank checks.
    call UpdateGrade

    ; Don't do anything if there were line clears
    ldh a, [hLineClearCt]
    or a, a
    jr nz, .are

    ; Otherwise, reset the combo.
    ld a, 1
    ldh [hComboCt], a

    ; ARE delay.
    ; Count down the delay. If it hits 0, award levels and score if necessary, then end the delay phase.
.are
    ldh a, [hRemainingDelay]
    dec a
    ldh [hRemainingDelay], a
    or a, a
    jp nz, BigWidenField

    ; Add one level if we're not at a breakpoint and not in MYCO speed curve.
    ldh a, [hRequiresLineClear]
    cp a, $FF
    jr z, .generatenextpiece
    ld a, [wSpeedCurveState]
    cp a, SCURVE_MYCO
    jr z, .generatenextpiece
    cp a, SCURVE_CHIL
    jr z, .generatenextpiece
    ld e, 1
    call LevelUp

    ; Cycle the RNG.
.generatenextpiece
    ld a, [wInStaffRoll]
    cp a, $FF
    jr z, .doit
    ld a, [wShouldGoStaffRoll]
    cp a, $FF
    ret z

.doit
    ldh a, [hNextPiece]
    ldh [hCurrentPiece], a
    call GetNextPiece

    ; Kill the sound for the next piece.
    jp SFXKill


    ; Shifts B into the line clear list.
    ; Also increments the line clear count.
BigAppendClearedLine:
    ldh a, [hLineClearCt]
    inc a
    ldh [hLineClearCt], a
    ldh a, [hClearedLines+2]
    ldh [hClearedLines+3], a
    ldh a, [hClearedLines+1]
    ldh [hClearedLines+2], a
    ldh a, [hClearedLines]
    ldh [hClearedLines+1], a
    ld a, b
    ldh [hClearedLines], a
    ret


    ; Scans the field for lines that are completely filled with non-empty spaces.
    ; Every time one is found, it is added to a list.
BigFindClearedLines:
    xor a, a
    ldh [hLineClearCt], a
    ld a, $FF
    ld c, 0
    ldh [hClearedLines], a
    ldh [hClearedLines+1], a
    ldh [hClearedLines+2], a
    ldh [hClearedLines+3], a

    DEF row = 13
    REPT 14
        ld hl, wShadowField+2+(row*14)
        ld b, 11
:       ld a, [hl+]
        dec b
        cp a, $FF
        jr z, :+
        cp a, TILE_FIELD_EMPTY
        jr nz, :-
:       xor a, a
        cp a, b
        jr nz, .next\@
        ld b, 13-row
        call BigAppendClearedLine
        inc c
        ld a, 4
        cp a, c
        ret z
        DEF row -= 1
.next\@
    ENDR
    ret


    ; Goes through the list of cleared lines and marks those lines with the "line clear" tile.
BigMarkClear:
    ldh a, [hClearedLines]
    cp a, $FF
    ret z
    ld hl, wField+(14*10)
.markclear1loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear1loop
    ld bc, 5
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+1]
    cp a, $FF
    ret z
    ld hl, wField+(14*10)
.markclear2loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear2loop
    ld bc, 5
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+2]
    cp a, $FF
    ret z
    ld hl, wField+(14*10)
.markclear3loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear3loop
    ld bc, 5
    ld d, TILE_CLEARING
    call UnsafeMemSet

    ldh a, [hClearedLines+3]
    cp a, $FF
    ret z
    ld hl, wField+(14*10)
.markclear4loop
    ld bc, -10
    add hl, bc
    dec a
    cp a, $FF
    jr nz, .markclear4loop
    ld bc, 5
    ld d, TILE_CLEARING
    jp UnsafeMemSet


    ; Once again, scans the field for cleared lines, but this time removes them.
BigClearLines:
    ld de, 0

    DEF row = 23
    REPT 23
        ; Check if the row begins with a clearing tile.
        ld hl, wField+(row*10)
        ld a, [hl]
        cp a, TILE_CLEARING

        ; If it does, increment the clearing counter, but skip this line.
        jr nz, .clear\@
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        jr .r\@

.clear\@
        ; If there's 0 lines that need to be moved down, skip this line.
        xor a, a
        cp a, e
        jr z, .r\@

        ; Otherwise...
        ld bc, wField+(row*10)
        add hl, de
:       ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
        ld a, [bc]
        ld [hl+], a
        inc bc
.r\@
        DEF row -= 1
    ENDR

    ; Make sure there's no garbage in the top de lines.
.fixgarbo
    ld hl, wField
.fixgarboloop
    xor a, a
    or a, d
    or a, e
    ret z
    ld a, TILE_FIELD_EMPTY
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    xor a, a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    dec de
    dec de
    dec de
    dec de
    dec de
    dec de
    dec de
    dec de
    dec de
    dec de
    jr .fixgarboloop


BigWidenField::
    ld de, wField+(3*10)
    ld hl, wWideField
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(4*10)
    ld hl, wWideField+5
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(5*10)
    ld hl, wWideField+10
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(6*10)
    ld hl, wWideField+15
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(7*10)
    ld hl, wWideField+20
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(8*10)
    ld hl, wWideField+25
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(9*10)
    ld hl, wWideField+30
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(10*10)
    ld hl, wWideField+35
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(11*10)
    ld hl, wWideField+40
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(12*10)
    ld hl, wWideField+45
    ld bc, 5
    call UnsafeMemCopy
    ld de, wField+(13*10)
    ld hl, wWideField+50
    ld bc, 5
    call UnsafeMemCopy

    DEF piece = 0
    REPT 55
        ld a, [wWideField+piece]
        ld hl, wWideBlittedField+((piece/5)*20)+((piece%5) * 2)
        ld [hl+], a
        ld [hl], a
        ld hl, wWideBlittedField+((piece/5)*20)+((piece%5) * 2)+10
        ld [hl+], a
        ld [hl], a
        DEF piece += 1
    ENDR
    ret


ENDC
