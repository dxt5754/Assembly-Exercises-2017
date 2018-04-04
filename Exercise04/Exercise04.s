    TTL CMPE Iteration and Subroutines
;****************************************************************
; This program uses a subroutine to perform a division operation
;Name:  Dean Trivisani
;Date:  9/19/17
;Class:  CMPE-250
;Section:  02 Tuesday 11:00am
;---------------------------------------------------------------
;Keil Simulator Template for KL46
;R. W. Melton
;January 23, 2015
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;EQUates
MAX_DATA 	EQU	25
;Vectors
VECTOR_TABLE_SIZE EQU 0x000000C0
VECTOR_SIZE       EQU 4           ;Bytes per vector
;Stack
SSTACK_SIZE EQU  0x00000100
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
			IMPORT InitData
			IMPORT LoadData
			IMPORT TestData
Reset_Handler  PROC {},{}
main
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
;Disable interrupts
			CPSID I
			
			BL InitData				;data initialization subroutine		
DIV_START			
			BL LoadData				;subroutine that loads P and Q
			ldr R7,=butts
			
			BCS QUIT				;Exit if carry flag is set
			;load addresses of p and q
			LDR 	R1,=P
			LDR 	R0,=Q
			;initialize registers
			LDR 	R0,[R0,#0]
			LDR 	R1,[R1,#0]
			
			BL 		DIVU			;division subroutine
			
			BCC 	VALID			;If carry is clear, answer is valid, store it
			BCS 	INVALID			;if carry is set, answer is invalid, set P and Q to 0xFFFFFFFF

VALID
			;load adresses of p and q
			LDR 	R2,=P
			LDR 	R3,=Q
			;set P and Q to the R0 and R1
			STR 	R0,[R2,#0]
			STR 	R1,[R3,#0]
			B		RUNTEST
INVALID
			;load adresses of p and q
			LDR 	R2,=P
			LDR 	R3,=Q
			;set P and Q to 0xFFFFFFFF
			LDR 	R4,=0xFFFFFFFF
			STR 	R4,[R2,#0]
			STR 	R4,[R3,#0]

RUNTEST
			BL 		TestData
			
			B 		DIV_START
		
				
QUIT
;>>>>>   end main program code <<<<<
;Stay here
            B       .
			ENDP
;---------------------------------------------------------------
;>>>>> begin subroutine code <<<<<

DIVU        PROC    {R2-R14},{}
;Computes R1 / R0 into R0 remainder R1	
			PUSH 	{R3,R4}			; store values of R3 and R4

			CMP 	R0, #0			;compare divisor to 0
			BEQ		SET_CAR			;if divisor is 0, go to special case
			CMP 	R1, #0			;compare dividend to zero
			BEQ		ZERODIV			;if dividend is 0, 
			B 		BRK 			;go to special case
SET_CAR
			MRS		R3,APSR			;set C flag to 1
			MOVS	R4,#0x20
			LSLS	R4,R4,#24
			ORRS	R3,R3,R4
			MSR		APSR,R3
			B 		ENDDIV
BRK		
			MOVS 	R3, #0 			;put quotient in R3
			
DIVWHILE			
			CMP 	R0, R1			;compare R0 and R1
			BHI 	ENDDIVWHILE		;if R0<R1 exit the loop
			ADDS 	R3, R3, #1 		;quotient ++
			SUBS 	R1, R1, R0 		;R1 = R1 - R0
			B 	DIVWHILE
			
ZERODIV
			MOVS	R3,#0			;IF dividend is zero, remainder is always zero
ENDDIVWHILE
			MOVS 	R0, R3			;R0 <- quotient, remainder = R1
			MRS		R3,APSR			;clear C flag to 0
			MOVS	R4,#0x20
			LSLS	R4,R4,#24
			BICS	R3,R3,R4
			MSR		APSR,R3
			
ENDDIV		
			POP 	{R3,R4}			;clear changes from registers
			BX 		LR 				;quit subroutine
			ENDP
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;reset vector
            SPACE  (VECTOR_TABLE_SIZE - (2 * VECTOR_SIZE))
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
butts	dcd	0x05
;>>>>>   end constants here <<<<<
;****************************************************************
            AREA    |.ARM.__at_0x1FFFE000|,DATA,READWRITE,ALIGN=3
            EXPORT  __initial_sp
			EXPORT	P
			EXPORT	Q
			EXPORT	Results
;Allocate system stack
            IF      :LNOT::DEF:SSTACK_SIZE
SSTACK_SIZE EQU     0x00000100
            ENDIF
Stack_Mem   SPACE   SSTACK_SIZE
__initial_sp
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
P		SPACE	4
Q		SPACE	4
Results	SPACE	50
;>>>>>   end variables here <<<<<
            END