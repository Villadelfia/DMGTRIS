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


IF !DEF(GRADING_ASM)
DEF GRADING_ASM EQU 1


INCLUDE "globals.asm"


SECTION "Grade Variables", WRAM0
wDecayRate:                     ds 1
wInternalGradePoints:           ds 1
wInternalGrade:                 ds 1
wDisplayedGrade::               ds 1
wEffectTimer::                  ds 1
wRankingDisqualified::          ds 1
wDecayCounter:                  ds 1
wGradeGauge:                    ds 1
wSMult:                         ds 1
wDMult:                         ds 1
wTMult:                         ds 1
wSRate:                         ds 1
wDRate:                         ds 1
wTRate:                         ds 1
wQRate:                         ds 1
wPrevCOOL:                      ds 3
wCOOLIsActive::                 ds 1
wSubgrade:                      ds 1
wREGRETChecked::                ds 1
wGradeBoosts:                   ds 1
wCOOLBoosts:                    ds 1
wTGM1level300RequirementMet:    ds 1
wTGM1level500RequirementMet:    ds 1
wTGM1level999RequirementMet:    ds 1


SECTION "Grading Data", ROMX, BANK[BANK_GAMEPLAY]
sDMGTGrading:
    db 125, 10, 20, 40, 50 ; Grade 9   — frames/decay, single base, double base, triple base, tetris base
    db 80,  10, 20, 30, 40 ; Grade 8   — frames/decay, single base, double base, triple base, tetris base
    db 80,  10, 20, 30, 40 ; Grade 7   — frames/decay, single base, double base, triple base, tetris base
    db 40,  10, 20, 30, 40 ; Grade 6   — frames/decay, single base, double base, triple base, tetris base
    db 40,   5, 20, 30, 40 ; Grade 5   — frames/decay, single base, double base, triple base, tetris base
    db 40,   5, 20, 30, 40 ; Grade 4   — frames/decay, single base, double base, triple base, tetris base
    db 40,   5, 20, 30, 40 ; Grade 3   — frames/decay, single base, double base, triple base, tetris base
    db 40,   2, 20, 20, 30 ; Grade 2   — frames/decay, single base, double base, triple base, tetris base
    db 40,   2, 15, 20, 30 ; Grade 1   — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S1  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S2  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S3  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S4  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S5  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S6  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S7  — frames/decay, single base, double base, triple base, tetris base
    db 20,   2, 15, 20, 30 ; Grade S8  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 15, 20, 30 ; Grade S9  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 15, 20, 30 ; Grade S10 — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 15, 20, 30 ; Grade S11 — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 15, 20, 30 ; Grade S12 — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade S13 — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade m1  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade m2  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade m3  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade m4  — frames/decay, single base, double base, triple base, tetris base
    db 15,   2, 12, 15, 30 ; Grade m5  — frames/decay, single base, double base, triple base, tetris base
    db 10,   2, 12, 15, 30 ; Grade m6  — frames/decay, single base, double base, triple base, tetris base
    db 10,   2, 12, 15, 30 ; Grade m7  — frames/decay, single base, double base, triple base, tetris base
    db 10,   2, 12, 15, 30 ; Grade m8  — frames/decay, single base, double base, triple base, tetris base
    db 5,    2,  8, 13, 30 ; Grade m9  — frames/decay, single base, double base, triple base, tetris base
    db 5,    2,  8, 13, 30 ; Grade M   — frames/decay, single base, double base, triple base, tetris base
    db 5,    2,  8, 13, 30 ; Grade MK  — frames/decay, single base, double base, triple base, tetris base
    db 5,    1,  8, 13, 30 ; Grade MV  — frames/decay, single base, double base, triple base, tetris base
    db 5,    1,  8, 13, 20 ; Grade MO  — frames/decay, single base, double base, triple base, tetris base
    db 4,    1,  4, 10, 20 ; Grade MM  — frames/decay, single base, double base, triple base, tetris base
                           ; No entry for GM. We're done there.

sDMGTGaugeLUT:
    db 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3
    db 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7
    db 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 9, 10,10,10
    db 10,10,11,11,11,11,11,12,12,12,12,13,13,13,13,13
    db 14,14,14,14,14,15,15,15,15,16,16,16,16,16,17,17
    db 17,17,17,18,18,18,18,19,19,19,19,19,20,20,20,20
    db 20,21,21,21,21,21,22,22,22,22,23,23,23,23,23,24
    db 24,24,24,24,25,25,25,25,26,26,26,26,26,27,27,27
    db 27,27,28,28,28,28,29,29,29,29,29,30,30,30,30,31
    db 31,31,31,31,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32

sTGM3GaugeLUT:
    db 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5
    db 5, 5, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 9, 9, 9, 10
    db 10,10,11,11,11,12,12,12,13,13,13,14,14,14,15,15
    db 15,15,16,16,16,17,17,17,18,18,18,19,19,19,20,20
    db 20,21,21,21,22,22,22,23,23,23,23,24,24,24,25,25
    db 25,26,26,26,27,27,27,28,28,28,29,29,29,30,30,30
    db 31,31,31,31,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
    db 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32

sTGM1GradeScores:
    dw $0004 ;00 — 8
    dw $0008 ;00 — 7
    dw $0014 ;00 — 6
    dw $0020 ;00 — 5
    dw $0035 ;00 — 4
    dw $0055 ;00 — 3
    dw $0080 ;00 — 2
    dw $0120 ;00 — 1
    dw $0160 ;00 — S1
    dw $0220 ;00 — S2
    dw $0300 ;00 — S3
    dw $0400 ;00 — S4
    dw $0520 ;00 — S5
    dw $0660 ;00 — S6
    dw $0820 ;00 — S7
    dw $1000 ;00 — S8
    dw $1200 ;00 — S9

sTGM3InternalGradeSystem:
    db 125, 10, 20, 40, 50 ;Decay rate, (Internal grade points awarded for:) Single, Double, Triple, Tetris
    db 80,  10, 20, 30, 40
    db 80,  10, 20, 30, 40
    db 50,  10, 15, 30, 40
    db 45,  5,  15, 20, 40
    db 45,  5,  15, 20, 30
    db 45,  5,  10, 20, 30
    db 40,  5,  10, 15, 30
    db 40,  5,  10, 15, 30
    db 40,  5,  10, 15, 30
    db 40,  2,  12, 13, 30
    db 40,  2,  12, 13, 30
    db 30,  2,  12, 13, 30
    db 30,  2,  12, 13, 30
    db 30,  2,  12, 13, 30
    db 20,  2,  12, 13, 30
    db 20,  2,  12, 13, 30
    db 20,  2,  12, 13, 30
    db 20,  2,  12, 13, 30
    db 20,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 15,  2,  12, 13, 30
    db 10,  2,  12, 13, 30
    db 10,  2,  12, 13, 30

sTGM3GradeBoosts:
    db 0 ;9 (0 = add 0, 1 = add 1)
    db 1 ;8
    db 1 ;7
    db 1 ;6
    db 1 ;5
    db 1 ;4
    db 0 ;4
    db 1 ;3
    db 0 ;3
    db 1 ;2
    db 0 ;2
    db 0 ;2
    db 1 ;1
    db 0 ;1
    db 0 ;1
    db 1 ;S1 (yes, here you finally get into the S grades, unless you are very COOL)
    db 0 ;S1
    db 1 ;S2
    db 1 ;S3
    db 1 ;S4
    db 0 ;S4
    db 0 ;S4
    db 1 ;S5
    db 0 ;S5
    db 1 ;S6
    db 0 ;S6
    db 1 ;S7
    db 0 ;S7
    db 1 ;S8
    db 0 ;S8
    db 1 ;S9

sTGM3HowManyInternalGradesToDecrease:
    db 0 ;9 (0 = substract 0, 1 = substract 1, etc.)
    db 1 ;8
    db 1 ;7
    db 1 ;6
    db 1 ;5
    db 1 ;4
    db 2 ;4
    db 1 ;3
    db 2 ;3
    db 1 ;2
    db 2 ;2
    db 3 ;2
    db 1 ;1
    db 2 ;1
    db 3 ;1
    db 1 ;S1
    db 2 ;S1
    db 1 ;S2
    db 1 ;S3
    db 1 ;S4
    db 2 ;S4
    db 3 ;S4
    db 1 ;S5
    db 2;S5
    db 1 ;S6
    db 2 ;S6
    db 1 ;S7
    db 2 ;S7
    db 1 ;S8
    db 2 ;S8
    db 1 ;S9

sTGM3ComboMultipliers:
    db 1,  1, 1, 1, 1   ; Combo size, (Multiplier for: ) Single, Double, Triple, Tetris (Screw the fractional part, x.5 gets rounded down)
    db 2,  1, 1, 1, 1
    db 3,  1, 1, 1, 2
    db 4,  1, 1, 2, 2
    db 5,  1, 1, 2, 2
    db 6,  1, 1, 2, 2
    db 7,  1, 1, 2, 2
    db 8,  1, 1, 2, 2
    db 9,  1, 1, 2, 3
    db 10, 2, 2, 3, 3

sTGM3LevelMultiplier:
    db 2 ; 250-499
    db 3 ; 500-749
    db 4 ; 750-999

sTGM3BaselineCOOL:
    db 00,52 ;070 (minutes, seconds)
    db 00,52 ;170
    db 00,49 ;270
    db 00,45 ;370
    db 00,45 ;470
    db 00,42 ;570
    db 00,42 ;670
    db 00,38 ;770
    db 00,38 ;870

sTGM3REGRETConditions:
    db 1, 30 ;minutes, seconds
    db 1, 15
    db 1, 15
    db 1, 8
    db 1, 0
    db 1, 0
    db 0, 50
    db 0, 50
    db 0, 50
    db 0, 50

sTGM3StaffrollGrading: ;subgrades awarded per line clear
    db 1 ;Single
    db 2 ;Double
    db 3 ;Triple
    db 10 ;Tetris
    db 16 ;Clear


SECTION "Grading Functions Unbanked", ROM0
GradeInit::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call GradeInitB
    jp RSTRestoreBank

UpdateGrade::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call UpdateGradeB
    jp RSTRestoreBank

DecayGradeProcess::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call DecayGradeProcessB
    jp RSTRestoreBank

DecayGradeDelay::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call DecayGradeDelayB
    jp RSTRestoreBank

TGM3REGRETHandler::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call TGM3REGRETHandlerB
    jp RSTRestoreBank

TGM3COOLHandler::
    ld b, BANK_GAMEPLAY
    rst RSTSwitchBank
    call TGM3COOLHandlerB
    jp RSTRestoreBank


SECTION "Grading Functions Banked", ROMX, BANK[BANK_GAMEPLAY]
    ; Wipe the grading variables.
GradeInitB:
    xor a, a
    ld [wDecayRate], a
    ld [wInternalGrade], a
    ld [wInternalGradePoints], a
    ld [wDisplayedGrade], a
    ld [wRankingDisqualified], a
    ld [wEffectTimer], a
    ld [wDecayCounter], a
    ld [wGradeGauge], a
    ld [wSubgrade], a
    ld [wGradeBoosts], a
    ld [wCOOLBoosts], a
    ld [wCOOLIsActive], a
    ld [wREGRETChecked], a
    ld [wPrevCOOL], a
    ld [wPrevCOOL+1], a
    ld [wPrevCOOL+2], a
    ld [wTGM1level300RequirementMet], a
    ld [wTGM1level500RequirementMet], a
    ld [wTGM1level999RequirementMet], a

    ; Most modes begin ungraded.
    ld a, GRADE_NONE
    ld [wDisplayedGrade], a

    ; TGM1, TGM3, and DMGT are the exceptions.
    ld a, [wSpeedCurveState]
    cp a, SCURVE_TGM1
    jr z, .grade9start
    cp a, SCURVE_TGM3
    jr z, .grade9start
    cp a, SCURVE_DMGT
    jr z, .grade9start
    jr .end

.grade9start
    ld a, GRADE_9
    ld [wDisplayedGrade], a

.end
    ; Falls through intentionally.


    ; Jumps to the grade update function for the current mode.
UpdateGradeB:
    ld hl, .gradejumptable
    ld a, [wSpeedCurveState]
    ld b, a
    add a, b
    add a, b
    ld b, 0
    ld c,  a
    add hl, bc
    jp hl

.gradejumptable
    jp UpdateGradeDMGT ;DMGT
    jp UpdateGradeTGM1 ;TGM1
    jp UpdateGradeTGM3 ;TGM3
    jp UpdateGradeDEAT ;DEAT
    jp UpdateGradeSHIR ;SHIR
    no_jump            ;CHIL
    no_jump            ;MYCO


    ; Jumps to the grade decay function for the current mode.
    ; Called once per frame where a piece is in motion.
DecayGradeProcessB:
    ld hl, .gradejumptable
    ld a, [wSpeedCurveState]
    ld b, a
    add a, b
    add a, b
    ld b, 0
    ld c,  a
    add hl, bc
    jp hl

.gradejumptable
    jp DecayGradeDMGT ;DMGT
    no_jump           ;TGM1
    jp DecayGradeTGM3 ;TGM3
    no_jump           ;DEAT
    no_jump           ;SHIR
    no_jump           ;CHIL
    no_jump           ;MYCO


    ; Jumps to the grade decay function for the current mode.
    ; Called once per frame during ARE and line clear delay.
DecayGradeDelayB:
    ld hl, .gradejumptable
    ld a, [wSpeedCurveState]
    ld b, a
    add a, b
    add a, b
    ld b, 0
    ld c,  a
    add hl, bc
    jp hl

.gradejumptable
    no_jump           ;DMGT
    no_jump           ;TGM1
    jp DecayGradeTGM3 ;TGM3
    no_jump           ;DEAT
    no_jump           ;SHIR
    no_jump           ;CHIL
    no_jump           ;MYCO


    ; Get the four most significant figures of the score in BC as BCD.
PrepareScore:
    ldh a, [hScore+SCORE_HUNDREDS]
    ld b, a
    ldh a, [hScore+SCORE_THOUSANDS]
    swap a
    or b
    ld c, a
    ldh a, [hScore+SCORE_TENTHOUSANDS]
    ld b, a
    ldh a, [hScore+SCORE_HUNDREDTHOUSANDS]
    swap a
    or b
    ld b, a
    ret

DrawGradeProgressDMGT:
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    jr nz, :+
    ld a, $FF
    ld [wGradeGauge], a
:   ld hl, sDMGTGaugeLUT
    ld a, [wGradeGauge]
    ld b, 0
    ld c, a
    add hl, bc

    ld a, [hl]
    call SetProgress
    ret

DrawGradeProgressTGM3:
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    jr nz, :+
    ld a, $FF
    ld [wInternalGradePoints], a
:   ld hl, sTGM3GaugeLUT
    ld a, [wInternalGradePoints]
    ld b, 0
    ld c, a
    add hl, bc

    ld a, [hl]
    call SetProgress
    ret

UpdateGradeDMGT:
    ; Check if the torikan hasn't been calculated.
    ld a, [wRankingDisqualified]
    cp a, $FF
    jr z, .checklineclears

    ; Have we hit the torikan level?
    ldh a, [hCLevel+CLEVEL_HUNDREDS]
    cp a, 5
    jr nz, .checklineclears

    ; Mark it as checked and do the check.
    ld a, $FF
    ld [wRankingDisqualified], a

    ; There's a 8:00 torikan at 500.
    ld b, 8
    ld c, 0
    call CheckTorikan

    ; If we failed it: DIE.
    cp a, $FF
    jp z, .checklineclears
    ld a, $FF
    ld [wLockLevel], a
    ld a, 5
    ldh [hCLevel+1], a
    ldh [hNLevel+1], a
    xor a, a
    ldh [hCLevel], a
    ldh [hNLevel], a
    ldh [hCLevel+2], a
    ldh [hNLevel+2], a
    ldh [hCLevel+3], a
    ldh [hNLevel+3], a
    jp TriggerKillScreen


    ; Did we have line clears?
.checklineclears
    ldh a, [hLineClearCt]
    or a, a
    jp z, DrawGradeProgressDMGT

    ; Bail if we're already GM.
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    jp z, DrawGradeProgressDMGT

    ; Get grade in BC.
    ld b, 0
    ld c, a

    ; Point HL to decay rate.
    ld hl, sDMGTGrading
    add hl, bc
    add hl, bc
    add hl, bc
    add hl, bc
    add hl, bc

    ; What is our single/double/triple/quad rate?
.clearrate
    inc hl
    ld a, [hl+]
    ld [wSRate], a
    ld a, [hl+]
    ld [wDRate], a
    ld a, [hl+]
    ld [wTRate], a
    ld a, [hl]
    ld [wQRate], a

    ; What is our single/double/triple multiplier?
.combomult
    ld a, [hComboCt]
    cp a, 13
    jr nc, .combo13
    cp a, 8
    jr nc, .combo8
    jr .combo1

.combo13
    ld a, 2
    ld [wSMult], a
    ld a, 3
    ld [wDMult], a
    ld a, 3
    ld [wTMult], a
    jr .prelevel

.combo8
    ld a, 1
    ld [wSMult], a
    ld a, 2
    ld [wDMult], a
    ld a, 2
    ld [wTMult], a
    jr .prelevel

.combo1
    ld a, 1
    ld [wSMult], a
    ld a, 1
    ld [wDMult], a
    ld a, 1
    ld [wTMult], a

    ; Branch on line clear count.
.prelevel
    ldh a, [hLineClearCt]
    ld d, a
    cp a, 4
    jr z, .tetris
    cp a, 3
    jr z, .triple
    cp a, 2
    jr z, .double

    ; Singles are worth the single rate x1 or x2.
.single
    ld a, [wSRate]
    ld d, a
    ld a, [wSMult]
    cp a, 1
    jr z, .levelmult
    ld a, d
    add a, d
    ld d, a
    jr .levelmult

    ; Doubles are worth the double rate x1, x2 or x3.
.double
    ld a, [wDRate]
    ld d, a
    ld a, [wDMult]
    cp a, 1
    jr z, .levelmult
    cp a, 2
    ld a, d
    jr z, .adddonce
    add a, d
.adddonce
    add a, d
    ld d, a
    jr .levelmult

    ; Triples are worth the triple rate x1, x2 or x3.
.triple
    ld a, [wTRate]
    ld d, a
    ld a, [wTMult]
    cp a, 1
    jr z, .levelmult
    cp a, 2
    ld a, d
    jr z, .addtonce
    add a, d
.addtonce
    add a, d
    ld d, a
    jr .levelmult

    ; Tetris are worth just tetris.
.tetris
    ld a, [wQRate]
    ld d, a

    ; What is our level multiplier?
    ; Running counter is in in D now.
.levelmult
    ld a, [hCLevel+CLEVEL_THOUSANDS] ; thousands
    cp a, 1
    jr nc, .mult4
    ld a, [hCLevel+CLEVEL_HUNDREDS] ; hundreds
    cp a, 9
    jr nc, .mult4
    cp a, 5
    jr nc, .mult3
    cp a, 2
    jr nc, .mult2
    jr .mult1

.mult4
    ld a, d
    add a, d
    add a, d
    add a, d
    jr .processgrade

.mult3
    ld a, d
    add a, d
    add a, d
    jr .processgrade

.mult2
    ld a, d
    add a, d
    jr .processgrade

.mult1
    ld a, d

    ; Increase the gauge.
    ; The value to add to the gauge is in A
.processgrade
    ld d, a
    ld a, [wGradeGauge]
    add a, d
    ld [wGradeGauge], a

    ; Did we overflow? Failsafe.
    jr nc, .increasegrademaybe
    xor a, a
    ld [wGradeGauge], a

    ; Increment the grade.
    ld a, [wDisplayedGrade]
    inc a
    ld [wDisplayedGrade], a

    ; GM?
    cp a, GRADE_GM
    jr z, .gotgm

    ; No, play the normal jingle.
    call SFXKill
    ld a, SFX_RANKUP
    call SFXEnqueue
    ld a, $0F
    ld [wEffectTimer], a
    jp DrawGradeProgressDMGT

.increasegrademaybe
    ; Do we have 150 in the gauge?
    ld a, [wGradeGauge]
    cp a, 150
    ret c

    ; Yes, take 150 away.
    sub a, 150
    ld [wGradeGauge], a

    ; Increment the grade.
    ld a, [wDisplayedGrade]
    inc a
    ld [wDisplayedGrade], a

    ; GM?
    cp a, GRADE_GM
    jr z, .gotgm

    ; No, play the normal jingle.
    call SFXKill
    ld a, SFX_RANKUP
    call SFXEnqueue
    ld a, $0F
    ld [wEffectTimer], a
    ret

.gotgm
    call SFXKill
    ld a, SFX_RANKGM
    call SFXEnqueue
    ld a, $0F
    ld [wEffectTimer], a
    ret


DecayGradeDMGT:
    ; Bail if the gauge is empty.
    ld a, [wGradeGauge]
    or a, a
    jp z, DrawGradeProgressDMGT

    ; Bail if we're already GM.
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    jp z, DrawGradeProgressDMGT

    ; Get grade in BC.
    ld b, 0
    ld c, a

    ; Point HL to decay rate.
    ld hl, sDMGTGrading
    add hl, bc
    add hl, bc
    add hl, bc
    add hl, bc
    add hl, bc

    ; Increment the decay.
    ld a, [wDecayCounter]
    inc a

    ; Did we hit the rate?
    ld b, a
    ld a, [hl]
    cp a, b
    jr z, .decay

    ; Nope, don't decay, but do save.
.nodecay
    ld a, b
    ld [wDecayCounter], a
    jp DrawGradeProgressDMGT

    ; Yes, decay.
.decay
    ld a, [wGradeGauge]
    dec a
    ld [wGradeGauge], a
    xor a, a
    ld [wDecayCounter], a
    jp DrawGradeProgressDMGT


UpdateGradeTGM1:
    ; Bail if we're already GM.
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    ret z

    ; Bail if we didn't make the 999 check.
    ld a, [wTGM1level999RequirementMet]
    or a, a
    ret nz

    ; Skip to GM check if already S9.
    ld a, [wDisplayedGrade]
    cp a, GRADE_S9
    jp nc, .check999

.trygradeup
    ; Otherwise, check if we can increase the grade.
    ; Get our score into BC
    call PrepareScore

    ; Double our current grade and use it as an offset into the scoring table.
    ld a, [wDisplayedGrade]
    add a
    ld d, 0
    ld e, a

    ; Have HL point to the next required score and get it into DE.
    ld hl, sTGM1GradeScores
    add hl, de

    ; LSB
    ld a, [hl+]
    ld e, a

    ; MSB
    ld a, [hl]
    ld d, a

    ; Check if BC >= DE...
    ; Return if B < D.
    ld a, b
    cp a, d
    ret c

    ; We can confidently increase the grade if B > D.
    jr nz, .increasegrade

    ; If B == D, we need to check C and E...

    ; Return if C < E. Otherwise increase the grade.
    ld a, c
    cp a, e
    jr c, .check300

.increasegrade
    ; Add 1 to the grade.
    ld a, [wDisplayedGrade]
    inc a
    ld [wDisplayedGrade], a

    ; Play the jingle, if not already doing so.
    ldh a, [hCurrentlyPlaying]
    cp a, SFX_RANKUP
    jr z, .skipjingle
    call SFXKill
    ld a, SFX_RANKUP
    call SFXEnqueue

    ; Prepare the effect stuff
.skipjingle
    ld a, $0F
    ld [wEffectTimer], a

    ; Loop and see if we can increment more grades.
    ld a, [wDisplayedGrade]
    cp a, GRADE_S9 ; Don't go past S9.
    jr nz, .trygradeup


.check300
    ; Are we at level 300?
    ld a, [hCLevel+CLEVEL_HUNDREDS]
    cp a, 3
    ret c

    ; Have we judged the requirement before?
    ld a, [wTGM1level300RequirementMet]
    or a, a
    jr nz, .check500

    ; Rank?
    ld a, [wDisplayedGrade]
    cp a, GRADE_1
    jr c, .fail300

    ; Time?
    ld b, 4
    ld c, 15
    call CheckTorikan
    cp a, $FF
    jr nz, .fail300

.success300
    ld a, $FF
    ld [wTGM1level300RequirementMet], a
    jr .check500

.fail300
    ld a, $01
    ld [wTGM1level300RequirementMet], a
    jr .check500


.check500
    ; Are we at level 500?
    ld a, [hCLevel+CLEVEL_HUNDREDS]
    cp a, 5
    ret c

    ; Have we judged the requirement before?
    ld a, [wTGM1level500RequirementMet]
    or a, a
    jr nz, .check999

    ; Rank?
    ld a, [wDisplayedGrade]
    cp a, GRADE_S4
    jr c, .fail500

    ; Time?
    ld b, 7
    ld c, 30
    call CheckTorikan
    cp a, $FF
    jr nz, .fail500

.success500
    ld a, $FF
    ld [wTGM1level500RequirementMet], a
    jr .check999

.fail500
    ld a, $01
    ld [wTGM1level500RequirementMet], a
    jr .check999


.check999
    ; Level needs to be 999.
    ld a, [hCLevel+CLEVEL_HUNDREDS]
    cp a, 9
    ret nz
    ld a, [hCLevel+CLEVEL_TENS]
    cp a, 9
    ret nz
    ld a, [hCLevel+CLEVEL_ONES]
    cp a, 9
    ret nz

    ; Have we judged the requirement before?
    ld a, [wTGM1level999RequirementMet]
    or a, a
    ret nz

    ; Did both other checks succeed?
    ld a, [wTGM1level300RequirementMet]
    cp a, $FF
    jr nz, .fail999
    ld a, [wTGM1level500RequirementMet]
    cp a, $FF
    jr nz, .fail999

    ; Rank? (This is technically slightly wrong but it's nearly impossible to miss the real requirement but make this one, 6000 points.)
    ld a, [wDisplayedGrade]
    cp a, GRADE_S9
    jr c, .fail999

    ; Time?
    ld b, 13
    ld c, 30
    call CheckTorikan
    cp a, $FF
    jr nz, .fail999

.success999
    ld a, $FF
    ld [wTGM1level999RequirementMet], a

    ; Set the grade to GM
    ld a, GRADE_GM
    ld [wDisplayedGrade], a

    ; Sound effect
    call SFXKill
    ld a, SFX_RANKGM
    jp SFXEnqueue

    ; Prepare the effect stuff
    ld a, $0F
    ld [wEffectTimer], a

    ; Return
    ret

.fail999
    ld a, $01
    ld [wTGM1level999RequirementMet], a
    ret


UpdateGradeDEAT:
    ; If we're disqualified, don't update the grade.
    ld a, [wRankingDisqualified]
    cp a, $FF
    ret z

    ; If we are already GM, don't do anything.
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    ret z

.notgm
    ; If we're M, check if we should be GM.
    cp a, GRADE_M
    jr nz, .notm

    ; We should be GM if we're at or past level 999.
    ldh a, [hCLevel+CLEVEL_HUNDREDS] ; Level, hundreds digit.
    cp a, 9
    ret c ; If hundreds are less than 9, return.
    ldh a, [hCLevel+CLEVEL_TENS] ; Level, tens digit.
    cp a, 9
    ret c ; If tens are less than 9,
    ldh a, [hCLevel+CLEVEL_ONES] ; Level, ones digit.
    cp a, 9
    ret c ; If ones are less than 9, return

    ; Otherwise give the grade!
    ld a, GRADE_GM
    ld [wDisplayedGrade], a

    ; Play the jingle.
    call SFXKill
    ld a, SFX_RANKGM
    call SFXEnqueue

    ; Prepare the effect stuff
    ld a, $0F
    ld [wEffectTimer], a
    ret

.notm
    ; If we're not M, check if we should be M.
    ldh a, [hCLevel+CLEVEL_HUNDREDS] ; Level, hundreds digit.
    cp a, 5
    ret c ; If less than 500, return.

    ; There's a 3:25 torikan for M.
    ld b, 3
    ld c, 25
    call CheckTorikan

    ; If we failed the Torikan, disqualify from ranking.
    cp a, $FF
    jr nz, .disqualify

    ; Otherwise award M.
    ld a, GRADE_M
    ld [wDisplayedGrade], a

    ; Play the jingle.
    call SFXKill
    ld a, SFX_RANKUP
    call SFXEnqueue

    ; Prepare the effect stuff
    ld a, $0F
    ld [wEffectTimer], a
    ret

.disqualify
    ; Disqualify from ranking.
    ld a, $FF
    ld [wLockLevel], a
    ld [wRankingDisqualified], a
    ld a, 5
    ldh [hCLevel+1], a
    ldh [hNLevel+1], a
    xor a, a
    ldh [hCLevel], a
    ldh [hNLevel], a
    ldh [hCLevel+2], a
    ldh [hNLevel+2], a
    ldh [hCLevel+3], a
    ldh [hNLevel+3], a
    jp TriggerKillScreen


UpdateGradeSHIR:
    ; If we're disqualified, don't update the grade any higher.
    ld a, [wRankingDisqualified]
    cp a, $FF
    ret z

    ; If we are already GM, don't do anything.
    ld a, [wDisplayedGrade]
    cp a, GRADE_S13
    ret z

    ; We don't give out a grade until level 100.
    ldh a, [hCLevel+CLEVEL_HUNDREDS] ; Level, hundreds digit.
    or a, a
    ret z

    ; Get the hundreds and thousands of the level as a hex number.
    ld b, a ; Hundreds
    ldh a, [hCLevel+CLEVEL_THOUSANDS] ; Thousands
    swap a
    or b

    ; Convert the BCD to hex.
    ld c, a     ; C = A
    and a, $F0  ; A = A & $F0. A is now $00 to $90 if the number was correct BCD.
    srl a       ; A = A >> 1
    ld b, a     ; B = A
    srl a
    srl a       ; A = A >> 2
    add a, b    ; A += B
    ld b, a     ; B = A. At this point B is 10, 20, 30, ... 90.
    ld a, c     ; A = C
    and a, $0F  ; A = A & $0F. A is now $00 to $09 if the number was correct BCD.
    add a, b    ; Adding B to A gives us the converted number.

    ; Adding GRADE_1 to this will give us the grade.
    add a, GRADE_1
    ld b, a
    ld a, [wDisplayedGrade]
    cp a, b
    ret z ; If the grade is already correct, return.
    ld a, b
    ld [wDisplayedGrade], a ; Otherwise, set the grade.

    ; Play the jingle.
    call SFXKill
    ld a, SFX_RANKUP
    call SFXEnqueue

    ; Prepare the effect stuff
    ld a, $0F
    ld [wEffectTimer], a

    ; There's a few torikans for Shirase.
    ld a, [wDisplayedGrade]
.s5torikan
    cp a, GRADE_S5
    jr nz, .s10torikan

    ; There's a 2:28 torikan after S5.
    ld b, 2
    ld c, 28
    call CheckTorikan

    ; If we failed the Torikan, disqualify from ranking up further.
    cp a, $FF
    jr nz, .disqualify
    ret

.s10torikan
    cp a, GRADE_S10
    ret nz

    ; There's a 4:56 torikan after S10.
    ld b, 4
    ld c, 56
    call CheckTorikan

    ; If we failed the Torikan, disqualify from ranking up further.
    cp a, $FF
    jr nz, .disqualify
    ret

.disqualify
    ; Disqualify from ranking.
    ld a, $FF
    ld [wLockLevel], a
    ld [wRankingDisqualified], a
    ld a, [wDisplayedGrade]
    cp a, GRADE_S5
    jr z, .l500

.l1000
    ld a, 1
    ldh [hCLevel], a
    ldh [hNLevel], a
    xor a, a
    ldh [hCLevel+1], a
    ldh [hNLevel+1], a
    ldh [hCLevel+2], a
    ldh [hNLevel+2], a
    ldh [hCLevel+3], a
    ldh [hNLevel+3], a
    jp TriggerKillScreen

.l500
    ld a, 5
    ldh [hCLevel+1], a
    ldh [hNLevel+1], a
    xor a, a
    ldh [hCLevel], a
    ldh [hNLevel], a
    ldh [hCLevel+2], a
    ldh [hNLevel+2], a
    ldh [hCLevel+3], a
    ldh [hNLevel+3], a
    jp TriggerKillScreen


UpdateGradeTGM3:
    ; Are we in the Staff Roll?
    ld a, [wInStaffRoll]
    cp a, $FF
    jp z, TGM3StaffRollGradeUpdate
    ; First things first, Update our grade points.
.GradePoints
    ; Load the Table address to HL.
    ld hl, sTGM3InternalGradeSystem
    ; Get the correct offset using the lines cleared on the frame and our current Internal Grade.
    ; Make sure the offsets are set properly and that the amount of Cleared lines isn't 0.
    ld a, [wInternalGrade] ; Example: 3
    cp a, 0 ; If it's 0, we don't need to do weird math.
    jr z, .GetOffset
    ld d, a ; ld d, 3
    ld b, 5
    ld a, b ; ld a, 5
    dec d ;dec 3 to 2, so we don't accidentally add more than intended
:   add a, b ; 5+5 = 10 ; 10+5 = 15
    dec d
    jr nz, :- ; go back if d isn't 0
    ld b, a ; ld b, 15

.GetOffset
    ld a, [hLineClearCt]
    cp a, 0 ; If no lines were cleared, we don't need to do anything, just continue
    jp z, .IncreaseInternalGrade
    add a, b
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl]
    ld e, a ; We will use almost all registers to get the multipliers, so we need to keep the points we should add in a safe spot
    jp .multipliers

.loadpoints
    ld hl, wInternalGradePoints
    add a, [hl]
    ld [wInternalGradePoints], a
    ; Draw the progress
    call DrawGradeProgressTGM3
    jp .IncreaseInternalGrade

.multipliers
    ; There are some multipliers to help us increase our grade faster
    ld hl, sTGM3ComboMultipliers
    ld a, [hComboCt] ; Example: 3
    cp a, 0 ; If we got no combo, skip all this part
    jr z, .levelmultiplier
    cp a, 11 ; If the combo is greater than 10, make it 10
    jr c, .notover10
    ld a, 10
.notover10
    ld d, a ; ld d, 3
    ld b, 5
    ld a, b ; ld a, 5
    dec d ;dec 3 to 2, so we don't accidentally add more than intended
:   add a, b ; 5+5 = 10 ; 10+5 = 15
    dec d
    jr nz, :- ; go back if d isn't 0
    sub a, 4 ; Decrease 4 so we don't get the pointer wrong 
    ld b, a ; ld b, 15
    ld a, [hLineClearCt]
    cp a, 0 ; If no lines were cleared, we don't need to do anything, just continue
    jr z, .levelmultiplier
    add a, b
    ld b, 0
    dec a 
    ld c, a
    add hl, bc
    ld a, [hl] ; Now we got our multiplier!, let's apply it.
    dec a ; A multiplier of 1 shouldn't change anything, so let's get rid of them
    cp a, 0
    jr z, .levelmultiplier; Continue
    ld b, a ; Load the multiplier into B
    ld a, e ; Remember the points we got earlier?, here they are
    ld c, a ; We will add from C
:   add a, c
    dec b
    jr nz, :-
    ; Finally!, we can now load the points, right?, NO!, there is yet another multiplier...
    ; We have to keep the points safe again...
    ld e, a

.levelmultiplier
    ; Make HL point to the table that contains the level multipliers
    ld hl, sTGM3LevelMultiplier
    ; Get our level into BC
    ld a, [hCLevel+3]
    ld b, a
    ld a, [hCLevel+2]
    swap a
    or b
    ld c, a
    ld a, [hCLevel+1]
    ld b, a
    ld a, [hCLevel]
    swap a
    or b
    ld b, a

.Level750
    ; Is our level 750 or higher?
    ld a, b
    cp a, LEVEL_MULT_3A
    ; If B is less than 7, that means we are not even in level 700, so check for 500
    jr c, .Level500
    ; If B is NOT less than 7, we might be in level 750 or greater, so check the remaining digits.
    ld a, c
    cp a, LEVEL_MULT_3B
    ; If C is less than 50, we didn't reach level 750 yet, but we are for sure in the 7** Section, load the corresponding offset.
    jp .under750
    ; If C is equal or greater than 50, then congrats!, load the corresponding offset
    ld b, 0
    ld c, 2
    add hl, bc
    ld a, [hl]
    jp .Multiply

.under750
    ld b, 0
    ld c, 1
    add hl, bc
    ld a, [hl]

.Level500
    ; Is our level 500 or higher?
    ld a, b
    cp a, LEVEL_MULT_2A
    ; If B is less than 5, that means we are not even in level 500, so check for 250
    jr c, .Level250
    ; If B is NOT less than 5, we are in level 500 or greater
    ld b, 0
    ld c, 2
    add hl, bc
    ld a, [hl]
    jp .Multiply

.Level250 ; There is no Offset, so just get the multiplier
    ; Is our level 750 or higher?
    ld a, b
    cp a, LEVEL_MULT_1A
    ; If B is less than 2, that means we are not even in level 200, so no multiplier
    jr c, .under250
    ; If B is NOT less than 2, we might be in level 250 or greater, so check the remaining digits.
    ld a, c
    cp a, LEVEL_MULT_1B
    ; If C is less than 50, we didn't reach level 250 yet, so no multiplier
    jp .under250
    ; If C is equal or greater than 50, then congrats!, load the corresponding offset (I said there is no Offset!)
    ld a, [hl]
    jp .Multiply

.under250 ; There is no multiplier, so just load the points
    ld a, e
    jp .loadpoints

.Multiply ; FINALLY!!!!!, This took forever!
    ld b, a ; Load the multiplier into B
    ld a, e ; Remember the points we got earlier?, here they are... Again.
    ld c, a ; We will add from C
:   add a, c
    dec b
    jr nz, :-
    ; AND NOW WE ARE DONE!, LOAD THOSE POINTS!
    jp .loadpoints

.IncreaseInternalGrade
    ; Are we on level *00-*05?
    ld a, [hCLevel+CLEVEL_TENS]
    cp a, 0
    jr nz, .nocool
    ld a, [hCLevel+CLEVEL_ONES]
    cp a, 6
    ; If we are, jump to the update COOL grade funcion just in case we have to apply a section COOL
    call c, CheckCOOL
    ; If not, continue
.nocool
    ; Do we have 100 Grade Points?
    ld a, [wInternalGradePoints]
    cp a, 100
    ret c ; If the Internal Grade Points is less than 100, return, we don't have to change our Grade
    xor a, a ; Reset the points to 0 and increase the internal grade
    ld [wInternalGradePoints], a
    ld a, [wInternalGrade]
    inc a
    ld [wInternalGrade], a
    call DrawGradeProgressTGM3
    ; This falls to the next function, this is intentional


TGM3UpdateDisplayedGrade:
    ld a, [wGradeBoosts] ; If we are an S9 Grade, return
    cp a, GRADE_S9
    ret z
    ld a, GRADE_9 ; Load the lowest grade into a
    ld b, a ; Then save it into b
    ld hl, sTGM3GradeBoosts ; Make HL point to the Grade boosts table
    ld a, [wInternalGrade] ; Get the offset
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl] ; Load the boosts to add into a...
    ld b, a ; And then into b.

.update
    ld a, [wGradeBoosts] ; Load the boosts variable into A
    add a, b ;Add the boosts
    ld [wGradeBoosts], a ; And load them.
    ld b, a
    ld a, [wCOOLBoosts] ; Add our Section COOL boosts
    add a, b
    ld b, a

    ld a, [wDisplayedGrade]
    cp a, b
    ret z ; If the grade is the same, return.
    ld a, b

    ; Is our Grade S10 or higher?
    cp a, GRADE_S10
    jr c, .notaboves10 ; No, it isn't
    add a, GRADE_S10_PLUS ; Yes, it is

.notaboves10
    ld [wDisplayedGrade], a ; Otherwise, set the grade.
    ; ...Play the jingle.
    ld a, SFX_RANKUP
    call SFXEnqueue
    ; Prepare the effect stuff
    ld a, $0f
    ld [wEffectTimer], a
    ret


CheckCOOL:
    ld a, [wCOOLIsActive] ; Did the player get a cool on this section?
    cp a, 1
    ret nz
    ; If it did, check if we are at level *00-*05
    ld a, [hCLevel+CLEVEL_TENS]
    cp a, 0
    ret nz
    ld a, [hCLevel+CLEVEL_ONES]
    cp a, 5
    jr c, .cool
    ret nz ; If not, proceed as normal

.cool
    ld a, [wCOOLBoosts] ; Load our COOL Boosts into A
    inc a ; Increase A
    ld [wCOOLBoosts], a ; And load the result
    ; Now let's display our new grade!
    ld b, a
    ld a, [wDisplayedGrade]
    inc a
    ; Does it result in an S10 grade?
    cp a, GRADE_S10
    jr nz, .nots10 ; No, it doesn't
    add a, GRADE_S10_PLUS ; Yes, it does
.nots10
    ld [wDisplayedGrade], a ; Load the boosts into the displayed grade
    xor a, a
    ld [wCOOLIsActive], a ; Make the cool no longer be active
    jp SkipSection


DecayGradeTGM3:
    ; Check if we can decrease the Grade points, if not, decrease the timer
    ld a, [wDecayRate]
    cp a, 0
    jr z, .points
    ld b, a ; Save the timer
    ldh a, [hComboCt] ; If there is an active combo, do not decrease the counter, check if we can increase our internal grade instead
    dec a
    and a
    call nz, UpdateGradeTGM3.IncreaseInternalGrade
    ld a, b ; Load the timer back
    dec a
    ld [wDecayRate], a
    ret

.points
    ld a, [wInternalGradePoints] ; Do we have 0 grade points?
    cp a, 0
    ret z ; If so, return
    dec a
    cp a, 0 ; Do we have 0 now?
    jr z, .lpoints ; If so, load the points, since we don't have any points to decay
    ; Else, load the points and the corresponding Decay Rate
    ld [wInternalGradePoints], a
    call DrawGradeProgressTGM3
    ; Get the Decay Rate required
    ld hl, sTGM3InternalGradeSystem
    ld a, [wInternalGrade] ; Example: 3
    cp a, 0 ; If it's 0, we don't need to do weird math.
    jr z, .GetOffset
    ld d, a ; ld d, 3
    ld b, 5
    ld a, b ; ld a, 5
    dec d ;dec 3 to 2, so we don't accidentally add more than intended
:   add a, b ; 5+5 = 10 ; 10+5 = 15
    dec d
    jr nz, :- ; go back if d isn't 0

.GetOffset
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl] ; Load the rate into a...
    ld [wDecayRate], a ; ... and then into the timer
    ret

.lpoints
    ld [wInternalGradePoints], a
    jp DrawGradeProgressTGM3


TGM3COOLHandlerB:
    ; First check our previous cool
    ld a, [wPrevCOOL] ; Are the minutes 0?
    cp a, 0
    jr nz, .checkCOOL
    ; If so, check the seconds
    ld a, [wPrevCOOL+1]
    cp a, 0
    jr nz, .checkCOOL
    ; The seconds are 0 too?, hmm, check the frames
    ld a, [wPrevCOOL+2]
    cp a, 0
    jr nz, .checkCOOL
    ; No cool???, check the baseline cool then...
    ld hl, sTGM3BaselineCOOL
    ld a, [hCLevel+1]
    add a
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl+]
    ld b, a
    ld a, [hl]
    ld c, a
    jp .checkBaselineCOOL

.checkCOOL
    ; Load the minutes.
    ld a, [wPrevCOOL]
    ld b, a

    ; Load the seconds.
    ld a, [wPrevCOOL+1]
    add a, 2 ; Give the player 2 seconds to spare
    cp a, 60 ; Are we above 60 now?
    jr c, .nocarry ; If so, add 1 to the minutes and subtract 60 from the seconds
    inc b
    sub a, 60
.nocarry
    ld c, a

    ; Load the frames.
    ld a, [wPrevCOOL+2]
    ld d, a

.checkBaselineCOOL
    call CheckCOOL_REGRET
    cp a, $ff
    jp nz, .nocool

.cool ; If the player got a cool, set the active cool variable to 1, also set the previous cool variables to the correct value
    ld a, 1
    ld [wCOOLIsActive], a
    ld a, [wSectionMinutes]
    ld [wPrevCOOL], a
    ld a, [wSectionSeconds]
    ld [wPrevCOOL+1], a
    ld a, [wSectionFrames]
    ld [wPrevCOOL+2], a
    ld a, 1 ; Leave a value in A so we know if the code ran
    ret ; Done

.nocool ; If the player misses a cool, set the previous cool variables to 0, then return
    ld [wPrevCOOL], a
    ld [wPrevCOOL+1], a
    ld [wPrevCOOL+2], a
    ld a, 1 ; Leave a value in A so we know if the code ran
    ret


TGM3REGRETHandlerB: ; Check if we took too much time to complete a section
    ld a, [wREGRETChecked] ; First, make sure we haven't checked before
    cp a, 1
    ret z ; If we did, just return
    ld hl, sTGM3REGRETConditions
    ld a, [hCLevel+1]
    dec a
    add a
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl+]
    ld b, a
    ld a, [hl]
    ld c, a
    call CheckCOOL_REGRET
    cp a, 0
    ret nz

.regret
    ld a, [wInternalGrade]
    cp a, 0
    ret z
    xor a, a
    ld [wInternalGradePoints], a
    ld a, [wGradeBoosts]
    dec a
    ld [wGradeBoosts], a
    ld hl, sTGM3HowManyInternalGradesToDecrease ; Make HL point to the..., yeah.
    ld a, [wInternalGrade] ; Get the offset
    ld d, a ; save the internal grade because we need it later
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl] ; Load the amount of internal grades to decrease into a
    sub a, d ; Decrease the internal grades
    ld [wInternalGrade], a ; Load them
    ld a, [wGradeBoosts] ; Load the boosts variable into A
    ld [wDisplayedGrade], a ; Load the boosts into the displayed grade
    ld a, 1
    ld [wREGRETChecked], a
    ret ; Done


TGM3StaffRollGradeUpdate::
    ; Is the player already a GM?
    ld a, [wDisplayedGrade]
    cp a, GRADE_GM
    ret z ; If so, return
    ; Make HL Point to the Staffroll Table
    ld hl, sTGM3StaffrollGrading
    ; Get the offset, if no lines were cleared, return
    ld a, [hLineClearCt]
    and a
    ret z
    dec a
    ld b, 0
    ld c, a
    add hl, bc
    ; Load the value into A
    ld a, [hl]
    ; And then add that to the subgrade variable
    ld b, a
    ld a, [wSubgrade]
    add a, b
    ld [wSubgrade], a

.UpdateGrade
    cp a, $a
    ret c
    sub a, $a
    ld [wSubgrade], a
    ld a, [wDisplayedGrade]
    inc a
    ; will the grade be S10?
    cp a, GRADE_S10
    jr nz, .nots10 ;If not, continue as normal
    ld a, GRADE_M1
.nots10
    ld [wDisplayedGrade], a
    ret


ENDC
