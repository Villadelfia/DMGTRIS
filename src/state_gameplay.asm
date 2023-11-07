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


IF !DEF(STATE_GAMEPLAY_ASM)
DEF STATE_GAMEPLAY_ASM EQU 1


INCLUDE "globals.asm"
INCLUDE "res/gameplay_data.inc"
INCLUDE "res/gameplay_big_data.inc"


SECTION "High Gameplay Variables", HRAM
hCurrentPiece:: ds 1
hCurrentPieceX:: ds 1
hCurrentPieceY:: ds 1
hCurrentPieceRotationState:: ds 1
hHeldPiece:: ds 1
hHoldSpent:: ds 1
hMode:: ds 1
hModeCounter: ds 1
hPrePause: ds 1
hRequestedJingle: ds 1


SECTION "Gameplay Function Trampolines", ROM0
    ; Trampolines to the banked function.
SwitchToGameplay::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call SwitchToGameplayB
    jp RSTRestoreBank

    ; Trampolines to the banked function.
SwitchToGameplayBig::
    ld b, BANK_GAMEPLAY_BIG
    rst RSTSwitchBank
    call SwitchToGameplayBigB
    jp RSTRestoreBank

    ; Banks and jumps to the actual handler.
GamePlayEventLoopHandler::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call GamePlayEventLoopHandlerB
    rst RSTRestoreBank
    jp EventLoopPostHandler

    ; Banks and jumps to the actual handler.
GamePlayBigEventLoopHandler::
    ld b, BANK_GAMEPLAY_BIG
    rst RSTSwitchBank
    call GamePlayBigEventLoopHandlerB
    rst RSTRestoreBank
    jp EventLoopPostHandler


SECTION "Gameplay Function Banked", ROMX, BANK[BANK_GAMEPLAY]
    ; Change to game play mode. The event loop will call the event loop and vblank handlers for this mode after this returns.
SwitchToGameplayB:
    ; Turn the screen off if it's on.
    ldh a, [rLCDC]
    and LCDCF_ON
    jr z, .loadtilemap ; Screen is already off.
    wait_vram
    xor a, a
    ldh [rLCDC], a

    ; Load the gameplay tilemap.
.loadtilemap
    ld de, sGameplayTileMap
    ld hl, $9800
    ld bc, sGameplayTileMapEnd - sGameplayTileMap
    call UnsafeMemCopy

    ; And the tiles.
    call LoadGameplayTiles

    ; Zero out SCX.
    ld a, -2
    ldh [rSCX], a

    ; Clear OAM.
    call ClearOAM
    call SetNumberSpritePositions
    call ApplyTells

    ; Set up the palettes.
    ld a, PALETTE_REGULAR
    set_bg_palette
    set_obj0_palette
    ld a, PALETTE_LIGHTER_1
    set_obj1_palette

    ; Initialize the RNG.
    call RNGInit

    ; Initialize the score, level and field.
    call ScoreInit
    call LevelInit
    call FieldInit
    call GradeInit

    ; We don't start with hold spent.
    xor a, a
    ldh [hHoldSpent], a

    ; Leady mode.
    ld a, MODE_LEADY
    ldh [hMode], a
    ld a, LEADY_TIME
    ldh [hModeCounter], a

    ; GBC init
    call GBCGameplayInit

    ; Install the event loop handlers.
    ld a, STATE_GAMEPLAY
    ldh [hGameState], a

    ; And turn the LCD back on before we start.
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_BLK01
    ldh [rLCDC], a

    ; Music end
    call SFXKill

    ; Make sure the first game loop starts just like all the future ones.
    wait_vblank
    wait_vblank_end
    ret


    ; Main gameplay event loop.
GamePlayEventLoopHandlerB::
    ; What mode are we in?
    ld hl, .modejumps
    ldh a, [hMode]
    ld b, 0
    ld c, a
    add hl, bc
    jp hl

.modejumps
    jp .leadyMode
    jp .goMode
    jp .postGoMode
    jp .prefetchedPieceMode
    jp .spawnPieceMode
    jp .pieceInMotionMode
    jp .delayMode
    jp .gameOverMode
    jp .preGameOverMode
    jp .pauseMode


    ; Draw "READY" and wait a bit.
.leadyMode
    call ResetGameTime
    ldh a, [hModeCounter]
    cp a, LEADY_TIME
    jr nz, .firstleadyiterskip
    call SFXKill
    ld a, SFX_READYGO
    call SFXEnqueue
    ldh a, [hModeCounter]
.firstleadyiterskip
    dec a
    jr nz, .notdoneleady
    ld a, MODE_GO
    ldh [hMode], a
    ld a, GO_TIME
.notdoneleady
    ldh [hModeCounter], a
    ld de, sLeady
    ld hl, wField+(14*10)
    ld bc, 10
    call UnsafeMemCopy
    jp .drawStaticInfo


    ; Draw "GO" and wait a bit.
.goMode
    call ResetGameTime
    ldh a, [hModeCounter]
    dec a
    jr nz, .notdonego
    ld a, MODE_POSTGO
    ldh [hMode], a
    xor a, a
.notdonego
    ldh [hModeCounter], a
    ld de, sGo
    ld hl, wField+(14*10)
    ld bc, 10
    call UnsafeMemCopy
    jp .drawStaticInfo


    ; Clear the field, fetch the piece, ready for gameplay.
.postGoMode
    ld a, MODE_PREFETCHED_PIECE
    ldh [hMode], a
    call FieldClear
    call ToShadowField
    ldh a, [hNextPiece]
    ldh [hCurrentPiece], a
    call GetNextPiece
    call ResetGameTime
    jp .drawStaticInfo


    ; Fetch the next piece.
.prefetchedPieceMode
    ; A piece will spawn in the middle, at the top of the screen, not rotated by default.
    ld a, $FF
    ldh [hRequestedJingle], a
    ld a, PIECE_SPAWN_X
    ldh [hCurrentPieceX], a
    ld a, PIECE_SPAWN_Y
    ldh [hCurrentPieceY], a
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a
    ldh [hHoldSpent], a

    ; Check if IHS is requested.
    ; Apply the hold if so.
.checkIHS
    ldh a, [hSelectState]
    cp a, 0
    jr z, .loaddefaultjingle
    call DoHold
    jr .postjingle

    ; Enqueue the jingle.
.loaddefaultjingle
    ldh a, [hNextPiece]
    ldh [hRequestedJingle], a

    ; Check if IRS is requested.
    ; Apply the rotation if so.
.checkIRSA
    ld a, [wSwapABState]
    cp a, 0
    jr z, .lda1
.ldb1
    ldh a, [hBState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hBState], a
    jr .cp1
.lda1
    ldh a, [hAState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hAState], a
.cp1
    ld a, ROTATION_STATE_CCW
    ldh [hCurrentPieceRotationState], a
    ldh a, [hNextPiece]
    ld b, a
    ld a, SFX_IRS
    or a, b
    ldh [hRequestedJingle], a
    jr .postjingle

.checkIRSB
    ld a, [wSwapABState]
    cp a, 0
    jr z, .ldb2
.lda2
    ldh a, [hAState]
    cp a, 0
    jr z, .postjingle
    ld a, $FF
    ldh [hAState], a
    jr .cp2
.ldb2
    ldh a, [hBState]
    cp a, 0
    jr z, .postjingle
    ld a, $FF
    ldh [hBState], a
.cp2
    ld a, ROTATION_STATE_CW
    ldh [hCurrentPieceRotationState], a
    ldh a, [hNextPiece]
    ld b, a
    ld a, SFX_IRS
    or a, b
    ldh [hRequestedJingle], a
    jr .postjingle

.postjingle
    ld a, MODE_SPAWN_PIECE
    ldh [hMode], a
    ; State falls through to the next.


    ; Spawn the piece.
.spawnPieceMode
    call TrySpawnPiece
    cp a, $FF
    jr z, .canspawn
    ld a, MODE_PRE_GAME_OVER
    ldh [hMode], a
    jp .drawStaticInfo
.canspawn
    ld a, MODE_PIECE_IN_MOTION
    ldh [hMode], a

    ; Play the next jingle... maybe!
    ldh a, [hHoldSpent]
    cp a, $FF
    jr z, .pieceInMotionMode
    ldh a, [hRequestedJingle]
    cp a, $FF
    jr z, .pieceInMotionMode
    call SFXEnqueue


    ; This mode lasts for as long as the piece is in motion.
    ; Field will let us know when it has locked in place.
.pieceInMotionMode
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nopauserequested
    call ToBackupField
    ldh a, [hMode]
    ldh [hPrePause], a
    ld a, MODE_PAUSED
    ldh [hMode], a
    jp .drawStaticInfo

.nopauserequested
    call FieldProcess

    ; Do we hold?
    ldh a, [hSelectState]
    cp a, 1
    jr nz, .nohold
    ldh a, [hHoldSpent]
    cp a, $FF
    jr z, .nohold
    ; Reset position and rotation.
    ld a, PIECE_SPAWN_X
    ldh [hCurrentPieceX], a
    ld a, PIECE_SPAWN_Y
    ldh [hCurrentPieceY], a
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a
    call DoHold
    ld a, MODE_SPAWN_PIECE
    ldh [hMode], a

    ; Do we go into delay state?
.nohold
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 0
    jp nz, .drawStaticInfo
    ld a, MODE_DELAY
    ldh [hMode], a
    ; No fall through this time.

    jp .drawStaticInfo


.delayMode
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nodelaypauserequested
    call ToBackupField
    ldh a, [hMode]
    ldh [hPrePause], a
    ld a, MODE_PAUSED
    ldh [hMode], a
    jp .drawStaticInfo

.nodelaypauserequested
    call FieldDelay

    ldh a, [hRemainingDelay]
    cp a, 0
    jp nz, .drawStaticInfo
    ld a, MODE_PREFETCHED_PIECE
    ldh [hMode], a
    jp .drawStaticInfo


.preGameOverMode
    ; Spawn the failed piece.
    call ForceSpawnPiece

    ; Draw the field in grey.
    ; Yes. This really unrolls the loop that many times.
    ld hl, wField+(3*10)
    REPT 70
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty1\@
        ld a, GAME_OVER_OTHER+1
        ld [hl+], a
        jr .skip1\@
.notempty1\@
        ld a, GAME_OVER_OTHER
        ld [hl+], a
.skip1\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty2\@
        ld a, GAME_OVER_R10+10+off
        ld [hl+], a
        jr .skip2\@
.notempty2\@
        ld a, GAME_OVER_R10+off
        ld [hl+], a
.skip2\@
        DEF off += 1
    ENDR
    REPT 10
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty3\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip3\@
.notempty3\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip3\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty4\@
        ld a, GAME_OVER_R12+10+off
        ld [hl+], a
        jr .skip4\@
.notempty4\@
        ld a, GAME_OVER_R12+off
        ld [hl+], a
.skip4\@
        DEF off += 1
    ENDR
    REPT 10
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty5\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip5\@
.notempty5\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip5\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty6\@
        ld a, GAME_OVER_R14+10+off
        ld [hl+], a
        jr .skip6\@
.notempty6\@
        ld a, GAME_OVER_R14+off
        ld [hl+], a
.skip6\@
        DEF off += 1
    ENDR
    REPT 90
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty7\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip7\@
.notempty7\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip7\@
    ENDR

    ld a, MODE_GAME_OVER
    ldh [hMode], a


.gameOverMode
    ; Retry?
    ldh a, [hAState]
    cp a, 10 ; 10 frame hold
    jr nz, .noretry
    call RNGInit
    call ScoreInit
    call LevelInit
    call FieldInit
    call GradeInit
    xor a, a
    ldh [hHoldSpent], a
    ld a, MODE_LEADY
    ldh [hMode], a
    ld a, LEADY_TIME
    ldh [hModeCounter], a
    jp .drawStaticInfo

    ; Quit
.noretry
    ldh a, [hBState]
    cp a, 10 ; 10 frame hold
    jp nz, .drawStaticInfo
    jp SwitchToTitle


.pauseMode
    ; Quick reset.
    ldh a, [hAState]
    cp a, 0
    jr z, .noqr
    ldh a, [hBState]
    cp a, 0
    jr z, .noqr
    ldh a, [hSelectState]
    cp a, 0
    jr z, .noqr
    jp SwitchToTitle

    ; Unpause
.noqr
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nounpause
    call FromBackupField
    ldh a, [hPrePause]
    ldh [hMode], a
    xor a, a
    ldh [hLeftState], a
    ldh [hRightState], a
    jp .drawStaticInfo

    ; Draw PAUSE all over the field.
.nounpause
    ld de, sPause
    ld hl, wField+(0*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sPause
    ld hl, wField+(4*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sPause
    ld hl, wField+(8*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sPause
    ld hl, wField+(12*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sPause
    ld hl, wField+(16*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sPause
    ld hl, wField+(20*10)
    ld bc, 40
    call UnsafeMemCopy


    ; Always draw the score, level, next piece, and held piece.
.drawStaticInfo
    ldh a, [hNextPiece]
    call ApplyNext

    ldh a, [hHeldPiece]
    call ApplyHold

    ld hl, wSPRScore1
    ld de, hScore
    call ApplyNumbers8

    ld hl, wSPRCLevel1
    ld de, hCLevel
    call ApplyNumbers4

    ld hl, wSPRNLevel1
    ld de, hNLevel
    call ApplyNumbers4

    call SetNumberSpritePositions
    call ApplyTells
    call ApplyTime

    jp GBCGameplayProcess


    ; Do the hold action.
DoHold:
    ; Mark hold as spent.
    ld a, $FF
    ldh [hHoldSpent], a

    ; Check if IRS is requested.
    ; Apply the rotation if so.
.checkIRSA
    ld a, [wSwapABState]
    cp a, 0
    jr z, .lda3
.ldb3
    ldh a, [hBState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hBState], a
    jr .cp3
.lda3
    ldh a, [hAState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hAState], a
.cp3
    ld a, ROTATION_STATE_CCW
    ldh [hCurrentPieceRotationState], a
    call SFXKill
    ld a, SFX_IRS | SFX_IHS
    call SFXEnqueue
    jr .doHoldOperation

.checkIRSB
    ld a, [wSwapABState]
    cp a, 0
    jr z, .ldb4
.lda4
    ldh a, [hAState]
    cp a, 0
    jr z, .noRotation
    ld a, $FF
    ldh [hAState], a
    jr .cp4
.ldb4
    ldh a, [hBState]
    cp a, 0
    jr z, .noRotation
    ld a, $FF
    ldh [hBState], a
.cp4
    ld a, ROTATION_STATE_CW
    ldh [hCurrentPieceRotationState], a
    call SFXKill
    ld a, SFX_IRS | SFX_IHS
    call SFXEnqueue
    jr .doHoldOperation

.noRotation
    call SFXKill
    ld a, SFX_IHS
    call SFXEnqueue
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a

.doHoldOperation
    ldh a, [hHeldPiece]
    ld b, a
    ldh a, [hCurrentPiece]
    ldh [hHeldPiece], a
    ld a, b
    ldh [hCurrentPiece], a
    ret



SECTION "Gameplay Function Big Banked", ROMX, BANK[BANK_GAMEPLAY_BIG]
; Change to game play mode. The event loop will call the event loop and vblank handlers for this mode after this returns.
SwitchToGameplayBigB:
    ; Turn the screen off if it's on.
    ldh a, [rLCDC]
    and LCDCF_ON
    jr z, .loadtilemap ; Screen is already off.
    wait_vram
    xor a, a
    ldh [rLCDC], a

    ; Load the gameplay tilemap.
.loadtilemap
    ld de, sBigGameplayTileMap
    ld hl, $9800
    ld bc, sBigGameplayTileMapEnd - sBigGameplayTileMap
    call UnsafeMemCopy

    ; And the tiles.
    call LoadGameplayTiles

    ; Zero out SCX.
    ld a, -2
    ldh [rSCX], a

    ; Clear OAM.
    call ClearOAM
    call SetNumberSpritePositions
    call ApplyTells

    ; Set up the palettes.
    ld a, PALETTE_REGULAR
    set_bg_palette
    set_obj0_palette
    ld a, PALETTE_LIGHTER_1
    set_obj1_palette

    ; Initialize the RNG.
    call RNGInit

    ; Initialize the score, level and field.
    call ScoreInit
    call LevelInit
    call BigFieldInit
    call GradeInit

    ; We don't start with hold spent.
    xor a, a
    ldh [hHoldSpent], a

    ; Leady mode.
    ld a, MODE_LEADY
    ldh [hMode], a
    ld a, LEADY_TIME
    ldh [hModeCounter], a

    ; GBC init
    call GBCGameplayInit

    ; Install the event loop handlers.
    ld a, STATE_GAMEPLAY_BIG
    ldh [hGameState], a

    ; And turn the LCD back on before we start.
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_BLK01
    ldh [rLCDC], a

    ; Music end
    call SFXKill

    ; Make sure the first game loop starts just like all the future ones.
    wait_vblank
    wait_vblank_end
    ret


    ; Main gameplay event loop.
GamePlayBigEventLoopHandlerB:
    ; What mode are we in?
    ld hl, .modejumps
    ldh a, [hMode]
    ld b, 0
    ld c, a
    add hl, bc
    jp hl

.modejumps
    jp .leadyMode
    jp .goMode
    jp .postGoMode
    jp .prefetchedPieceMode
    jp .spawnPieceMode
    jp .pieceInMotionMode
    jp .delayMode
    jp .gameOverMode
    jp .preGameOverMode
    jp .pauseMode


    ; Draw "READY" and wait a bit.
.leadyMode
    call ResetGameTime
    ldh a, [hModeCounter]
    cp a, LEADY_TIME
    jr nz, .firstleadyiterskip
    call SFXKill
    ld a, SFX_READYGO
    call SFXEnqueue
    ldh a, [hModeCounter]
.firstleadyiterskip
    dec a
    jr nz, .notdoneleady
    ld a, MODE_GO
    ldh [hMode], a
    ld a, GO_TIME
.notdoneleady
    ldh [hModeCounter], a
    ld de, sBigLeady
    ld hl, wWideBlittedField+(10*10)
    ld bc, 10
    call UnsafeMemCopy
    jp .drawStaticInfo


    ; Draw "GO" and wait a bit.
.goMode
    call ResetGameTime
    ldh a, [hModeCounter]
    dec a
    jr nz, .notdonego
    ld a, MODE_POSTGO
    ldh [hMode], a
    xor a, a
.notdonego
    ldh [hModeCounter], a
    ld de, sBigGo
    ld hl, wWideBlittedField+(10*10)
    ld bc, 10
    call UnsafeMemCopy
    jp .drawStaticInfo


    ; Clear the field, fetch the piece, ready for gameplay.
.postGoMode
    ld a, MODE_PREFETCHED_PIECE
    ldh [hMode], a
    call BigFieldClear
    call BigToShadowField
    ldh a, [hNextPiece]
    ldh [hCurrentPiece], a
    call GetNextPiece
    call ResetGameTime
    jp .drawStaticInfo


    ; Fetch the next piece.
.prefetchedPieceMode
    ; A piece will spawn in the middle, at the top of the screen, not rotated by default.
    ld a, $FF
    ldh [hRequestedJingle], a
    ld a, PIECE_SPAWN_X_BIG
    ldh [hCurrentPieceX], a
    ld a, PIECE_SPAWN_Y_BIG
    ldh [hCurrentPieceY], a
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a
    ldh [hHoldSpent], a

    ; Check if IHS is requested.
    ; Apply the hold if so.
.checkIHS
    ldh a, [hSelectState]
    cp a, 0
    jr z, .loaddefaultjingle
    call BigDoHold
    jr .postjingle

    ; Enqueue the jingle.
.loaddefaultjingle
    ldh a, [hNextPiece]
    ldh [hRequestedJingle], a

    ; Check if IRS is requested.
    ; Apply the rotation if so.
.checkIRSA
    ld a, [wSwapABState]
    cp a, 0
    jr z, .lda1
.ldb1
    ldh a, [hBState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hBState], a
    jr .cp1
.lda1
    ldh a, [hAState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hAState], a
.cp1
    ld a, ROTATION_STATE_CCW
    ldh [hCurrentPieceRotationState], a
    ldh a, [hNextPiece]
    ld b, a
    ld a, SFX_IRS
    or a, b
    ldh [hRequestedJingle], a
    jr .postjingle

.checkIRSB
    ld a, [wSwapABState]
    cp a, 0
    jr z, .ldb2
.lda2
    ldh a, [hAState]
    cp a, 0
    jr z, .postjingle
    ld a, $FF
    ldh [hAState], a
    jr .cp2
.ldb2
    ldh a, [hBState]
    cp a, 0
    jr z, .postjingle
    ld a, $FF
    ldh [hBState], a
.cp2
    ld a, ROTATION_STATE_CW
    ldh [hCurrentPieceRotationState], a
    ldh a, [hNextPiece]
    ld b, a
    ld a, SFX_IRS
    or a, b
    ldh [hRequestedJingle], a
    jr .postjingle

.postjingle
    ld a, MODE_SPAWN_PIECE
    ldh [hMode], a
    ; State falls through to the next.


    ; Spawn the piece.
.spawnPieceMode
    call BigTrySpawnPiece
    cp a, $FF
    jr z, .canspawn
    ld a, MODE_PRE_GAME_OVER
    ldh [hMode], a
    jp .drawStaticInfo
.canspawn
    ld a, MODE_PIECE_IN_MOTION
    ldh [hMode], a

    ; Play the next jingle... maybe!
    ldh a, [hHoldSpent]
    cp a, $FF
    jr z, .pieceInMotionMode
    ldh a, [hRequestedJingle]
    cp a, $FF
    jr z, .pieceInMotionMode
    call SFXEnqueue


    ; This mode lasts for as long as the piece is in motion.
    ; Field will let us know when it has locked in place.
.pieceInMotionMode
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nopauserequested
    call BigToBackupField
    ldh a, [hMode]
    ldh [hPrePause], a
    ld a, MODE_PAUSED
    ldh [hMode], a
    jp .drawStaticInfo

.nopauserequested
    call BigFieldProcess

    ; Do we hold?
    ldh a, [hSelectState]
    cp a, 1
    jr nz, .nohold
    ldh a, [hHoldSpent]
    cp a, $FF
    jr z, .nohold
    ; Reset position and rotation.
    ld a, PIECE_SPAWN_X_BIG
    ldh [hCurrentPieceX], a
    ld a, PIECE_SPAWN_Y_BIG
    ldh [hCurrentPieceY], a
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a
    call BigDoHold
    ld a, MODE_SPAWN_PIECE
    ldh [hMode], a

    ; Do we go into delay state?
.nohold
    ldh a, [hCurrentLockDelayRemaining]
    cp a, 0
    jp nz, .drawStaticInfo
    ld a, MODE_DELAY
    ldh [hMode], a
    ; No fall through this time.


.delayMode
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nodelaypauserequested
    call BigToBackupField
    ldh a, [hMode]
    ldh [hPrePause], a
    ld a, MODE_PAUSED
    ldh [hMode], a
    jp .drawStaticInfo

.nodelaypauserequested
    call BigFieldDelay

    ldh a, [hRemainingDelay]
    cp a, 0
    jp nz, .drawStaticInfo
    ld a, MODE_PREFETCHED_PIECE
    ldh [hMode], a
    jp .drawStaticInfo


.preGameOverMode
    ; Spawn the failed piece.
    call BigForceSpawnPiece
    call BigWidenField

    ; Draw the field in grey.
    ; Yes. This really unrolls the loop that many times.
    ld hl, wWideBlittedField
    REPT 60
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty1\@
        ld a, GAME_OVER_OTHER+1
        ld [hl+], a
        jr .skip1\@
.notempty1\@
        ld a, GAME_OVER_OTHER
        ld [hl+], a
.skip1\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty2\@
        ld a, GAME_OVER_R10+10+off
        ld [hl+], a
        jr .skip2\@
.notempty2\@
        ld a, GAME_OVER_R10+off
        ld [hl+], a
.skip2\@
        DEF off += 1
    ENDR
    REPT 10
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty3\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip3\@
.notempty3\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip3\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty4\@
        ld a, GAME_OVER_R12+10+off
        ld [hl+], a
        jr .skip4\@
.notempty4\@
        ld a, GAME_OVER_R12+off
        ld [hl+], a
.skip4\@
        DEF off += 1
    ENDR
    REPT 10
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty5\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip5\@
.notempty5\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip5\@
    ENDR
    DEF off = 0
    REPT 10
        ld a, [hl]
        cp a, TILE_FIELD_EMPTY
        jr nz, .notempty6\@
        ld a, GAME_OVER_R14+10+off
        ld [hl+], a
        jr .skip6\@
.notempty6\@
        ld a, GAME_OVER_R14+off
        ld [hl+], a
.skip6\@
        DEF off += 1
    ENDR
    REPT 110
    ld a, [hl]
    cp a, TILE_FIELD_EMPTY
    jr nz, .notempty7\@
    ld a, GAME_OVER_OTHER+1
    ld [hl+], a
    jr .skip7\@
.notempty7\@
    ld a, GAME_OVER_OTHER
    ld [hl+], a
.skip7\@
    ENDR

    ld a, MODE_GAME_OVER
    ldh [hMode], a


.gameOverMode
    ; Retry?
    ldh a, [hAState]
    cp a, 10 ; 10 frame hold
    jr nz, .noretry
    call RNGInit
    call ScoreInit
    call LevelInit
    call BigFieldInit
    call GradeInit
    xor a, a
    ldh [hHoldSpent], a
    ld a, MODE_LEADY
    ldh [hMode], a
    ld a, LEADY_TIME
    ldh [hModeCounter], a
    jp .drawStaticInfo

    ; Quit
.noretry
    ldh a, [hBState]
    cp a, 10 ; 10 frame hold
    jp nz, .drawStaticInfo
    jp SwitchToTitle


.pauseMode
    ; Quick reset.
    ldh a, [hAState]
    cp a, 0
    jr z, .noqr
    ldh a, [hBState]
    cp a, 0
    jr z, .noqr
    ldh a, [hSelectState]
    cp a, 0
    jr z, .noqr
    jp SwitchToTitle

    ; Unpause
.noqr
    ldh a, [hStartState]
    cp a, 1
    jr nz, .nounpause
    call BigFromBackupField
    ldh a, [hPrePause]
    ldh [hMode], a
    xor a, a
    ldh [hLeftState], a
    ldh [hRightState], a
    jr .drawStaticInfo

    ; Draw PAUSE all over the field.
.nounpause
    ld de, sBigPause
    ld hl, wWideBlittedField+(0*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sBigPause
    ld hl, wWideBlittedField+(4*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sBigPause
    ld hl, wWideBlittedField+(8*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sBigPause
    ld hl, wWideBlittedField+(12*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sBigPause
    ld hl, wWideBlittedField+(16*10)
    ld bc, 40
    call UnsafeMemCopy
    ld de, sBigPause
    ld hl, wWideBlittedField+(20*10)
    ld bc, 20
    call UnsafeMemCopy


    ; Always draw the score, level, next piece, and held piece.
.drawStaticInfo
    ldh a, [hNextPiece]
    call ApplyNext

    ldh a, [hHeldPiece]
    call ApplyHold

    ld hl, wSPRScore1
    ld de, hScore
    call ApplyNumbers8

    ld hl, wSPRCLevel1
    ld de, hCLevel
    call ApplyNumbers4

    ld hl, wSPRNLevel1
    ld de, hNLevel
    call ApplyNumbers4

    call SetNumberSpritePositions
    call ApplyTells
    call ApplyTime

    jp GBCBigGameplayProcess


    ; Do the hold action.
BigDoHold:
    ; Mark hold as spent.
    ld a, $FF
    ldh [hHoldSpent], a

    ; Check if IRS is requested.
    ; Apply the rotation if so.
.checkIRSA
    ld a, [wSwapABState]
    cp a, 0
    jr z, .lda3
.ldb3
    ldh a, [hBState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hBState], a
    jr .cp3
.lda3
    ldh a, [hAState]
    cp a, 0
    jr z, .checkIRSB
    ld a, $FF
    ldh [hAState], a
.cp3
    ld a, ROTATION_STATE_CCW
    ldh [hCurrentPieceRotationState], a
    call SFXKill
    ld a, SFX_IRS | SFX_IHS
    call SFXEnqueue
    jr .doHoldOperation

.checkIRSB
    ld a, [wSwapABState]
    cp a, 0
    jr z, .ldb4
.lda4
    ldh a, [hAState]
    cp a, 0
    jr z, .noRotation
    ld a, $FF
    ldh [hAState], a
    jr .cp4
.ldb4
    ldh a, [hBState]
    cp a, 0
    jr z, .noRotation
    ld a, $FF
    ldh [hBState], a
.cp4
    ld a, ROTATION_STATE_CW
    ldh [hCurrentPieceRotationState], a
    call SFXKill
    ld a, SFX_IRS | SFX_IHS
    call SFXEnqueue
    jr .doHoldOperation

.noRotation
    call SFXKill
    ld a, SFX_IHS
    call SFXEnqueue
    xor a, a ; ROTATION_STATE_DEF
    ldh [hCurrentPieceRotationState], a

.doHoldOperation
    ldh a, [hHeldPiece]
    ld b, a
    ldh a, [hCurrentPiece]
    ldh [hHeldPiece], a
    ld a, b
    ldh [hCurrentPiece], a
    ret


ENDC
