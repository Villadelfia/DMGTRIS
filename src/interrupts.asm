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


IF !DEF(INTERRUPTS_ASM)
DEF INTERRUPTS_ASM EQU 1


INCLUDE "globals.asm"


DEF INIT_SCY EQU 3
DEF INIT_LYC EQU 3


SECTION "High Interrupt Variables", HRAM
hLCDCCtr:: ds 1


SECTION "Interrupt Initialization Functions", ROM0
EnableScreenSquish::
    di
    nop
    xor a, a
    ldh [hLCDCCtr], a
    ld a, STATF_LYC
    ldh [rSTAT], a
    ld a, INIT_LYC
    ldh [rLYC], a
    ld a, INIT_SCY
    ldh [rSCY], a
    ld a, IEF_STAT
    ldh [rIE], a
    xor a, a
    ldh [rIF], a
    ei
    ret

DisableScreenSquish::
    di
    nop
    xor a, a
    ldh [rIE], a
    ldh [rIF], a
    ldh [rSCY], a
    ei
    ret


SECTION "LCDC Interrupt", ROM0[INT_HANDLER_STAT]
    ; This interrupt handler will be called every 7 scanlines, scrolling up the tile map by 1 line. This has the
    ; effect of making the tiles appear as 8x7 pixels, and making 20 rows fit on the screen.
LCDCInterrupt:
    push af
    push hl

    ld hl, rSTAT
LCDCInterrupt_WaitUntilNotBusy:
    bit STATB_BUSY, [hl]
    jr nz, LCDCInterrupt_WaitUntilNotBusy

    ; Increment SCY
    ldh a, [rSCY]
    inc a
    ldh [rSCY], a

    ; Increment LYC by 7
    ldh a, [rLYC]
    add a, 7
    ldh [rLYC], a

    ; Check our interrupt counter
    cp a, 144
    jr c, LCDCInterrupt_End
    ld a, INIT_LYC
    ldh [rLYC], a
    ld a, INIT_SCY
    ldh [rSCY], a

LCDCInterrupt_End:
    pop hl
    pop af
    reti


ENDC
