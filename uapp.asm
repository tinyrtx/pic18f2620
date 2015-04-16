        TITLE "UAPP - tinyRTX PICdem2plus Demo Release 1.0"
        LIST
;*******************************************************************************
; tinyRTX Filename: uapp.asm (User APPlication)
;
; Copyright 2014 Sycamore Software, Inc.  ** www.tinyRTX.com **
; Distributed under the terms of the GNU Lesser General Purpose License v3
;
; This file is part of tinyRTX. tinyRTX is free software: you can redistribute
; it and/or modify it under the terms of the GNU Lesser General Public License
; version 3 as published by the Free Software Foundation.
;
; tinyRTX is distributed in the hope that it will be useful, but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
; A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; (filename copying.lesser.txt) and the GNU General Public License (filename
; copying.txt) along with tinyRTX.  If not, see <http://www.gnu.org/licenses/>.
;
; Revision History:
;  15Oct03  SHiggins@tinyRTX.com  Created from scratch.
;  31Oct03  SHiggins@tinyRTX.com  Split out USER interface calls.
;  27Jan04  SHiggins@tinyRTX.com  Split out UADC, updated comments.
;  30Jan04  SHiggins@tinyRTX.com  Refined initialization.
;  29Jul14  SHiggins@tinyRTX.com  Moved UAPP_Timer1Init to MACRO to save stack.
;  13Aug14  SHiggins@tinyRTX.com  Converted from PIC16877 to PIC18F452.
;  14Apr15  Stephen_Higgins@KairosAutonomi.com  Converted from PIC18F452 to PIC18F2620.
;
;*******************************************************************************
;
; Hardware: PICdem 2 Plus circuit board.
;           Microchip PIC18F2620 processor with 4 MHz input crystal.
;           TC74 digital temperature meter with I2C bus clocked at 100 kHz.
;
; Functions:
;  1) Read 1 A/D channel, convert A/D signal to engineering units and ASCII.
;  2) Read TC74 temperature value using I2C bus, convert to ASCII.
;  3) (NO PORT D... Send ASCII text and commands to LCD display using 4-bit bus.)
;
;*******************************************************************************
;
; Complete PIC16F877 (40-pin device) pin assignments for PICDEM 2 Plus Demo Board:
;
;  1) MCLR*/Vpp         = Reset/Programming connector(1): (active low, with debounce H/W)
;  2) RA0/AN0           = Analog In: Potentiometer Voltage 
;  3) RA1/AN1           = Discrete Out: LCD E (SLCD_CTRL_E)
;  4) RA2/AN2/Vref-     = Discrete Out: LCD RW (SLCD_CTRL_RW)
;  5) RA3/AN3/Vref+     = Discrete Out: LCD RS (SLCD_CTRL_RS)
;  6) RA4/TOCKI         = Discrete In:  Pushbutton S2 (active low, no debounce H/W)
;  7) RA5/AN4/SS*       = No Connect: (configured as Discrete In)
;  8) Vss               = Programming connector(3) (Ground) 
;  9) OSC1/CLKIN        = 4 MHz clock in (4 MHz/4 = 1 MHz = 1us instr cycle)
; 10) OSC2/CLKOUT       = (non-configurable output)
; 11) RC0/T1OSO/T1CKI   = No Connect: (configured as Discrete In) (possible future Timer 1 OSO)
; 12) RC1/T1OSI         = No Connect: (configured as Discrete In) (possible future Timer 1 OSI)
; 13) RC2/CCP1          = Discrete Out: Peizo Buzzer (when J9 in place) (TEMPORARILY DISCRETE IN)
; 14) RC3/SCK/SCL       = I2C SCL: MSSP implementation of I2C requires pin as Discrete In. (Not used for SPI.)
; 15) RC4/SDI/SDA       = I2C SDA: MSSP implementation of I2C requires pin as Discrete In. (Not used for SPI.)
; 16) RC5/SDO           = No Connect: (configured as Discrete In) (Not used for SPI.)
; 17) RC6/TX/CK         = USART TX: RS-232 driver, USART control of this pin requires pin as Discrete In.
; 18) RC7/RX/DT         = USART RX: RS-232 driver, USART control of this pin requires pin as Discrete In.
; 19) Vss               = Programming connector(3) (Ground)
; 20) Vdd               = Programming connector(2) (+5 VDC)
; 21) RB0/INT           = Discrete Out: LED RB0 (when J6 in place)
;                       = Discrete In: RB0/INT also Pushbutton S3 (active low, with debounce H/W)
; 22) RB1               = Discrete Out: LED RB1 (when J6 in place)
; 23) RB2               = Discrete Out: LED RB2 (when J6 in place)
; 24) RB3/PGM           = Discrete Out: LED RB3 (when J6 in place)
; 25) RB4               = No Connect: (configured as Discrete In)
; 26) RB5               = No Connect: (configured as Discrete In)
; 27) RB6/PGC           = Programming connector(5) (PGC) ICD2 control of this pin requires pin as Discrete In.
; 28) RB7/PGD           = Programming connector(4) (PGD) ICD2 control of this pin requires pin as Discrete In.
;
;*******************************************************************************
;
        errorlevel -302	
        #include    <p18f2620.inc>
;
;*******************************************************************************
;
;  User application RAM variable definitions.
;
UAPP_UdataSec   UDATA
;
UAPP_Temp       res     1   ; General purpose scratch register (unused).
;
;*******************************************************************************
;
; User application Power-On Reset initialization.
;
UAPP_CodeSec    CODE
;
        GLOBAL  UAPP_POR_Init
UAPP_POR_Init
;
; PORTA cleared so any bits later programmed as output now initialized to 0.
; TRISA value of 0x3f sets all PORTA to inputs.
;
        banksel PORTA
        clrf    PORTA       ; Clear initial data values in port.
;
        banksel TRISA
        movlw   0x3f
        movwf   TRISA       ; Set all bits as discrete inputs.
;
; PORTB cleared so any bits later programmed as output now initialized to 0.
; Set TRISB RB0-RB3 to outputs for LED's.
; Set TRISB RB4-RB7 to inputs.  PGC and PGD need to be configured as high-impedance inputs.
;
        banksel PORTB
        clrf    PORTB       ; Clear initial data values in port.
;
        banksel TRISB
        movlw   0xf0
        movwf   TRISB       ; Set RB0-RB3 to discrete outputs, RB4-RB7 to discrete inputs.
;
; PORTC cleared so any bits later programmed as output now initialized to 0.
; Set TRISC to all inputs.  SDA and SCL must be configured as inputs for I2C.
;
        banksel PORTC
        clrf    PORTC       ; Clear initial data values in port.
;
        banksel TRISC
        movlw   0xff
        movwf   TRISC       ; Set all bits as discrete inputs.
;
; PIE1 changed: ADIE, SSPIE, CCP1IE, TMR2IE, TMR1IE disabled.
;
        banksel PIE1
        movlw   (0<<ADIE)|(0<<SSPIE)|(0<<CCP1IE)|(0<<TMR2IE)|(0<<TMR1IE)
        movwf   PIE1
;
; PIR1 changed: ADIF, SSPIF, CCP1IF, TMR2IF, TMR1IF cleared.
;
        banksel PIR1
        movlw   (0<<ADIF)|(0<<SSPIF)|(0<<CCP1IF)|(0<<TMR2IF)|(0<<TMR1IF)
        movwf   PIR1
;
; PIE2 untouched; EEIE, BCLIE disabled.
; PIR2 untouched; EEIR, BCLIF remain cleared.
;
; INTCON changed: GIE, PEIE enabled; TMR0IE, INT0IE, RBIE disabled; TMR0IF, INT0IF, RBIF cleared.
;
        banksel INTCON
        movlw   (1<<GIE)|(1<<PEIE)|(0<<TMR0IE)|(0<<INT0IE)|(0<<RBIE)|(0<<TMR0IF)|(0<<INT0IF)|(0<<RBIF)
        movwf   INTCON
;
; IPEN cleared so disable priority levels on interrupts (PIC16 compatiblity mode.)
; RI set; TO set; PD set; POR set; BOR set; subsequent hardware resets will clear these bits.
;
        movlw   (0<<IPEN)|(1<<NOT_RI)|(1<<NOT_TO)|(1<<NOT_PD)|(1<<NOT_POR)|(1<<NOT_BOR)        
        banksel RCON
        movwf   RCON
        return
;
        end