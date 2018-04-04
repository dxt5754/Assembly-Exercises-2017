;	D/A and A/D Conversion, PWM, and Servos with Mixed C and Assembly	
;****************************************************************
; creates an analog value and converst it to a digital 
;value used to set a servo to one of five positions
;Name:  Dean Trivisani
;Date:  11/27/2017
;Class:  CMPE-250
;Section:  01L5
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;September 25, 2017
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates

;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;12:UART0 IRQ mask
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;12:UART0 IRQ pending status
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
UART0_IRQ_PRIORITY    EQU  3
NVIC_IPR_UART0_MASK   EQU (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3  EQU (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;12:UART0 IRQ mask
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port A
PORT_PCR_SET_PTA1_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select
;         (PLLFLLSEL determines MCGFLLCLK' or MCGPLLCLK/2)
; 1=   16:PLLFLLSEL=PLL/FLL clock select (MCGPLLCLK/2)
SIM_SOPT2_UART0SRC_MCGPLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 EQU \
    (SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R    EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C2_T_RI   EQU  (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI  EQU  (UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  0x1F
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  0xC0
;---------------------------------------------------------------
MAX_STRING  EQU    	79  
DIV1K		EQU		0x3E8
DIV10K		EQU		0x2710
DIV100K		EQU		0x186A0
DIV1M		EQU		0xF4240
IN_PTR      EQU     0
OUT_PTR     EQU     4
BUF_STRT    EQU     8
BUF_PAST    EQU     12
BUF_SIZE    EQU     16
NUM_ENQD    EQU     17
Q_BUF_SZ  	EQU    	4        
Q_REC_SZ  	EQU    	18        

	
;Servo position determined by duty cycle
;Create constant table for desired positions
;(duty periods in terms of clock cycles)
;*need to calibrate to servo values
PWM_PERIOD_20ms 		EQU 60000
PWM_DUTY_5 				EQU 3000
PWM_DUTY_10				EQU 6000
	
;EQUates for DAC0 lookup table
DAC0_STEPS				EQU 4096
SERVO_POSITIONS			EQU	5

;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            EXPORT AddIntMultiU
			EXPORT GetStringSB
			EXPORT PutStringSB
			EXPORT Init_UART0_IRQ
			EXPORT GetChar
			EXPORT PutChar
			EXPORT PutNumHex 
			EXPORT DAC0_table_0
			EXPORT PWM_duty_table_0			
			EXPORT UART0_IRQHandler

                
;-------------------------------------------
InitQueue   PROC    {R0-R14},{}
;Initializes the queue record structure at the 
;address in R1 for the empty queue buffer at 
;the address in R0 of size, 
;(i.e., character capacity), given in R2.
;Calls:
;Input: R0, R1, R2
;Output:  
;Register Modiciations:
			PUSH    {R0-R3,LR}        		;preserve register values      
            STR     R0,[R1,#IN_PTR]         ;sets the queue buffer address to InPointer
            STR     R0,[R1,#OUT_PTR]        ;"	   "	"	   "	   "    " OutPointer
            STR     R0,[R1,#BUF_STRT]       ;sets the buffer start address to the queue buffer address
			MOVS    R2,#Q_BUF_SZ            
            ADDS    R3,R0,R2                ;adds the buffer size to the buffer starting address
            STR     R3,[R1,#BUF_PAST]       ;store this new address
            STRB    R2,[R1,#BUF_SIZE]       ;set the buffer size to 4
            MOVS    R3,#0                   ;clear R3
            STRB    R3,[R1,#NUM_ENQD]       ;clear enqueued number
            POP     {R0-R3,PC}                    ;restore register values
			
			ENDP

Dequeue PROC    {R0-R14},{}
;Attempts to get a character from the queue 
;whose record structure’s address is in R1:  
;if the queue is not empty, dequeues a single
; character from the queue to R0, and returns 
;with the PSRC bit cleared, (i.e., 0), to report 
;dequeue success; otherwise, returns with the 
;PSRC bit set, (i.e., 1) to report dequeue failure.
;Inputs: R1
;Outputs: R0, C
			PUSH 	{R1, R2, R3, R4}
			LDRB 	R3, [R1, #NUM_ENQD]		;set flag if no queued
			CMP 	R3, #0
			BEQ		INVALID
			LDR 	R0, [R1, #OUT_PTR]		;R0 <- value
			LDRB 	R0, [R0, #0]				
			LDRB 	R3, [R1, #NUM_ENQD]		;NumEnqueued -=1
			SUBS 	R3, R3, #1	
			STRB 	R3, [R1, #NUM_ENQD] 
			LDR 	R3, [R1, #OUT_PTR]		;OutPointer +=1
			ADDS 	R3, R3, #1
			STR 	R3, [R1, #OUT_PTR] 
			LDR 	R4, [R1, #BUF_PAST]		;if OutPointer >= BufferPast, wrap,
			CMP 	R3, R4
			BLO 	CLEARC
			LDR 	R3, [R1, #BUF_STRT]		;OutPointer = BufferStart
			STR 	R3, [R1, #OUT_PTR]		;wrap	
CLEARC
			MRS 	R1, APSR				;clears C
			MOVS 	R3, #0x20
			LSLS 	R1, R1, #24
			BICS 	R1, R1, R3
			MSR		APSR, R1
			B 		DQQUITT					;quit
INVALID
			MRS 	R1, APSR				;set C
			MOVS 	R3, #0x20
			LSLS 	R3, R3, #24
			ORRS 	R1, R1, R3
			MSR 	APSR, R1
			
DQQUITT
			POP 	{R1, R2, R3, R4}		;restore register values
			BX		LR						;exit subroutine
			
			ENDP
			
Enqueue PROC    {R0-R14},{}
;Attempts to put a character in the queue
; whose queue record structure’s address
; is in R1—if the queue is not full, enqueues
; the single character from R0 to the queue, 
;and returns with the PSRC cleared to 
;report enqueue success; otherwise, returns 
;with the PSRC bit set to report enqueue failure.
;Calls:
;Input: R0,R1
;Output: PSR C flag flag (0 = success, 1 = failure)
;Register Modiciations: No registers, PSR
            PUSH    {R3-R6}                 ;preserve register values
            LDRB    R3,[R1,#NUM_ENQD]       ;R3 <- NumEnqueued
            LDRB    R4,[R1,#BUF_SIZE]       ;R4 <- BufferSize
            CMP     R3,R4                   ;if value >= buffer size, go to carry
            BHS     CARRY                 	
            LDR     R5,[R1,#IN_PTR]         ;R5 <- InPointer
            LDR     R6,[R1,#BUF_PAST]       ;R6 <- BufferPast
            STRB    R0,[R5,#0]              ;store value at InPointer
            ADDS    R3,R3,#1                ;NumEnqueued += 1
            STRB    R3,[R1,#NUM_ENQD]       ;R3 <- NumEnqueued
            ADDS    R5,R5,#1                ;InPointer += 1
            CMP     R5,R6                   ;if Inpointer < BufferPast, skip reset
            BLO     SKIPE               		
            LDR     R5,[R1,#BUF_STRT]       ;reset InPointer
SKIPE   		
			STR     R5,[R1,#IN_PTR]         ;Inpointer <- R1
            MRS     R3,APSR                 ;R3 <- APSR
            MOVS    R4,#0x20                ;R4 <- #0x20, for logic
            LSLS    R4,R4,#24               ;shift to MSB
            BICS    R3,R3,R4                ;clear C
            MSR     APSR,R3                     
            B       EQQUITT                   ;quit
CARRY     	
			MRS     R3,APSR                 ;set C
            MOVS    R4,#0x20                
            LSLS    R4,R4,#24               
            ORRS    R3,R3,R4                
            MSR     APSR,R3                 
EQQUITT      	
			POP     {R3-R6}                 ;restore register values 
            BX      LR                      ;exit subroutine
			
			ENDP
				
AddIntMultiU PROC    {R0-R14},{}
;Add the n-word unsigned number in memory starting 
;at the address in R2 to the n-word unsigned number
; in memory starting at the address in R1, and store
; the result to memory starting at the address in R0,
; where the value in R3 is n.  
;If the result is a valid n-word unsigned number, 
;it returns with the APSR C bit clear as the return code for success; 
;otherwise it returns with the APSR C bit set as the return code for overflow.

;Inputs: 	R0,R1,R2,R3
;Outputs:	R0

            PUSH	{R1-R7, LR}
            PUSH	{R0-R1}
            LDR		R0, =FLAGS            	;Initalize state of APSR C Flag
            MOVS 	R1, #0
            STRB 	R1, [R0, #0]
            POP 	{R0-R1}           
            MOVS 	R5,#0            		;Initalize registers
			MOVS	R4,#0
ADD
            CMP 	R3, #0
            BEQ 	ADDEND
            LDR 	R6, [R1, R5]
            LDR 	R7, [R2, R5]
			CMP		R4,#1					;if there was overflow on last addition
			BNE		SKIP
			ADDS	R6,R6,#1				;then add it to the sum
SKIP        SUBS 	R3, R3, #1            	;decrement n      
            ADDS 	R5, R5, #4            	;increment offset           
            PUSH 	{R5}       
            SUBS 	R5, R5, #4            	;store mem address  
            BL 		GETFLAGS           		;helper sub to set the APSR state
            ADCS 	R6, R6, R7            
            BL 		SETFLAGS           		;Helper sub to set C flag
            STR 	R6, [R0,R5]            
            POP 	{R5}
            BCS 	VCHK					;check for overflow
			MOVS	R4,#0
            B 		ADD            			;loop
VCHK
			MOVS	R4,#1					;if theres overflow, set variable to 1
			CMP 	R3, #0					;if its the last operation
            BNE 	ADD						
            MOVS	R0, #1            		;set overflow variable to 1
ADDEND
            CMP 	R0, #1					;if overflow variable is set, quit
            BNE 	SUCC					;else, success! move on
            B 		QUITADDMULTIU
SUCC
			PUSH	{R2,R3}					;clear C flag and quit
			MRS 	R2, APSR
			MOVS 	R3, #0x20
			LSLS 	R2, R2, #24
			BICS 	R2, R2, R3
			MSR		APSR, R2
			POP		{R2,R3}
QUITADDMULTIU
            POP 	{R1-R7, PC}
			ENDP

GETFLAGS
;Helper subroutine for managing
;the flags on the APSR in the addition
;subroutine
;Input: R0
;Output: Carry flag
;Register modifications: none
            PUSH 	{R0-R3}                 
            LDR 	R0, =FLAGS              ;load pointer to store flags
            LDRB 	R0, [R0, #0]            
            CMP 	R0, #0                  
            BNE 	SETCFLAG                ;if flag reg is set, set C
            MRS 	R2, APSR                ;otherwise, clear C
			MOVS 	R3, #0x20               
			LSLS 	R2, R2, #24             
			BICS 	R2, R2, R3              
			MSR		APSR, R2                
            B 		ENDGF                   
SETCFLAG                                    ;Set C flag
            MRS 	R2, APSR               
			MOVS 	R3, #0x20              
			LSLS 	R3, R3, #24            
			ORRS 	R2, R2, R3             
			MSR 	APSR, R2               
ENDGF                                      
            POP 	{R0 - R3}               ;restore vals and quit
            BX 		LR	                                
SETFLAGS
;helper subroutine for setting the flags
;in the addition subroutine
;Input: 
;Output: APSR flags stored
;Register Modifications: none
            PUSH 	{R0-R2}                 
            MRS 	R0, APSR                
            LSRS 	R0, #28                 
            MOVS 	R1, #2                  
            ANDS 	R0, R0, R1              
            LSRS 	R0, R0, #2              
            LDR 	R1, =FLAGS              
            STRB 	R0, [R1, #0]            
            POP 	{R0-R2}                 
            BX 		LR    		
			
PutNumHex PROC    {R0-R14},{}
;Prints to the terminal screen the text
; hexadecimal representation of the unsigned
; word value in R0.  (For example, if R0 
;contains 0x000012FF, then 000012FF should 
;print on the terminal. 
;Calls: PutChar
;Input: R0   
;Output: print to command line
;Register Modiciations: PSR
            PUSH        {R0,R1,R7,LR}   	;preserve register values
            MOVS        R7,R0           	;save copy of R0
            MOVS        R1,#0           	;initialize shift value
LOOP     	
			MOVS        R0,R7           	
            LSLS        R0,R0,R1        	;shift R0 left 
            LSRS        R0,R0,#28       	;shift R0 right
            CMP         R0,#10          	;check if number is bigger than or equal to 10
            BHS         ISHEX          		;if yes, it's a letter
            ADDS        R0,R0,#'0'       	;if no, it's a number
            B           PRNT        		;print the number
ISHEX      	
			ADDS        R0,R0,#('A'-10)      ;convert number to hex letter
PRNT    	
			BL          PutChar         	;print the number
            ADDS        R1,R1,#4        	;shift value += 4
            CMP         R1,#32          	;if shift value is 32, no more characters 
            BEQ         QUIT          		;then quit
            B           LOOP         		;else loop
QUIT      	
			POP         {R0,R1,R7,PC}   	;restore register values
			
			ENDP
				
PutNumUB PROC    {R0-R14},{}
;Printss to the terminal screen 
;the text decimal representation
; of the unsigned byte value in R0.  
;Calls: PutNumU
;Inputs: R0
;Outputs:
;Register Modifications:

			PUSH 		{R1, LR}		;preserve register values
			MOVS 		R1, #0xFF		;Mask off everything but the last byte
			ANDS 		R0, R0, R1
			BL 			PutNumU
			POP 		{R1, PC}
			
			ENDP

GetStringSB PROC    {R0-R14},{}
;Read & store string from command line
;Calls: GetChar, PutChar
;Input: R0, R1 
;Output: Prints to command line
;Register Modifications: 	
			PUSH    {R0,R1,R2,R3,LR}		;store register vallues
			SUBS	R1,R1,#1				;R1 <- MAX_STRING - 1
            MOVS    R2,#0					;clear R2			
			MOVS	R3,R0					;store string pointer	
GSLOOP  	
			BL		GetChar					;store character from string
			CMP     R2,R1					;is the string smaller than MAX_STRING?
            BHS     OVRFLW                  ;if yes, branch     
            CMP     R0,#0x0D
            BEQ     GSQUIT                  ;quit on carriage return
			CMP		R0,#0x7F
			BEQ		ADDCHK					;go back one on backspace
            STRB    R0,[R3,R2]				;store char in M[R3+R2]
            BL		PutChar					;print the character         
			ADDS    R2,R2,#1				;increment offset          
            B       GSLOOP					;go to start of loop
OVRFLW    	
			CMP     R0,#0x0D
            BEQ     GSQUIT					;quit on carriage return
            B		GSLOOP					;go to start of loop
ADDCHK		
			CMP		R2,#0
			BEQ		GSLOOP					;go to start of loop if backspaced on nothing
			SUBS	R2,R2,#1				;else go back one byte
			MOVS	R0,#0x7F				;load backspace into R0
			BL		PutChar					;send backspace to command line
			B		GSLOOP					;go to start of loop
GSQUIT     	
			MOVS	R0,#0					;clear R0
            STRB    R0,[R3,R2]				;store 0 in M[R3+R2]
			MOVS	R0,#0x0D				;load carriage return into R0
			BL		PutChar					;print carriage return
			MOVS	R0,#0x0A				;load line feed into R0
			BL		PutChar					;print line feed
            POP     {R0,R1,R2,R3,PC}		;restore register values
			
			ENDP
PutStringSB PROC    {R0-R14},{}
;Print string to command line
;Calls: PutChar
;Input:	R0
;Output: Print to command line
;Register Modifications: 	
			PUSH    {R0,R1,R2,LR}			;preserve register values
			MOVS	R1,#0					;clear R1
			MOVS	R2,R0					;store string pointer in R2
PSLOOP    	
			LDRB    R0,[R2,R1] 				;load character into R0
            CMP     R0,#0
            BEQ     PSQUIT					;quit on Null
            ADDS    R1,R1,#1				;increment offset
			BL      PutChar					;print the character
            B       PSLOOP					;go to start of loop
PSQUIT     	
			POP     {R0,R1,R2,PC}			;restore register values
			
			ENDP
				
;UART0_ISR
;handles UART0 transmit and receive interrupts
UART0_IRQHandler	PROC  {R0-R14},{}
			CPSID I							;Mask  interrupts
			PUSH {LR, R0-R3}				;preserve reg values
			LDR R0, =UART0_BASE
			LDRB R1,[R0,#UART0_C2_OFFSET]
			MOVS R2, #0x80
			ANDS R1, R1, R2
			CMP R1, #0
			BNE TXEN
			B CHECKRX						;Icheck for rx interrupt
TXEN
			LDRB R1,[R0,#UART0_S1_OFFSET]
			MOVS R2, #0x80
			ANDS R1, R1, R2
			CMP R1, #0
			BEQ CHECKRX
			LDR R1, =TxQueueRecord 			;Dequeue character
			MOVS R2, #Q_BUF_SZ				;initialize queue
			BL Dequeue		
			BCS TXDA						;dequeue failed
			LDR R1, =UART0_BASE				;dequeue worked
			STRB R0, [R1, #UART0_D_OFFSET]
			B QUITISR
TXDA
			MOVS R1,#UART0_C2_T_RI
			STRB R1,[R0,#UART0_C2_OFFSET]
			B QUITISR
CHECKRX
			LDR R0, =UART0_BASE
			LDRB R1,[R0,#UART0_S1_OFFSET]	;check for rx interrupt
			MOVS R2, #0x10
			ANDS R1, R1, R2
			CMP R1, #0
			BEQ QUITISR
			LDR R0, =UART0_BASE
			LDRB R3, [R0, #UART0_D_OFFSET]
			LDR R1, =RxQueueRecord
			MOVS R0, R3
			BL Enqueue						;enqueue character
QUITISR
			CPSIE I
			POP {R0-R3, PC}
			ENDP

GetChar
;Dequeues a character from the receive queue, and returns it in R0.
;Input: None
;Output: R0
;Modified Registers: R0
			PUSH {R1, R2, LR} 				;preserve reg values
			LDR R1,=RxQueueRecord			;load queue record address into R1
GETCHARLOOP		
			CPSID I							;Mask interrupts
			BL Dequeue						;dequeue character from receive queue
			CPSIE I							;enable interrupts
			BCS GETCHARLOOP
			POP {R1, R2, PC}
	
PutChar
;Enqueues the character from R0 to the transmit queue.
;Input: R0
;Output: Prints to terminall
;Register modifications: None

			PUSH {R0, R1, LR}		
PUTCHARLOOP
			LDR R1,=TxQueueRecord
			CPSID I							;Mask interrupts
			BL	Enqueue						;Enqueue char from R0 to transmit queue
			CPSIE I							;enable interrupts
			BCS PUTCHARLOOP
			MOVS R1,#UART0_C2_TI_RI			;Enable UART0 Transmitter, reciever, and rx interrupt
			LDR R0, =UART0_BASE
			STRB R1,[R0,#UART0_C2_OFFSET]
			POP {R0, R1, PC}				;restore register values

NEWLINE
;Prints a carriage return and a line feed
;Calls: PutChar
;Input:
;Output: Print to command line
;Register Modifications: 
            PUSH    {R0,LR}                 ;preserve register values
            MOVS	R0,#0x0D				;load carriage return into R0
			BL		PutChar					;print carriage return
			MOVS	R0,#0x0A				;load line feed into R0
			BL		PutChar					;print line feed
            POP     {R0,PC}                 ;restore register values
			
Init_UART0_IRQ   PROC {R0-R14},{}
;Initializes UART0 to be used with interrupts
			PUSH {R0, R1, R2, LR}
			;initialize transmit queue
			LDR R0, =TxQueue
			LDR R1, =TxQueueRecord
			BL InitQueue
			;initialize receive queue
			LDR R0, =RxQueue
			LDR R1, =RxQueueRecord
			BL InitQueue
			;Select MCGPLLCLK / 2 as UART0 clock source
			LDR R0,=SIM_SOPT2
			LDR R1,=SIM_SOPT2_UART0SRC_MASK
			LDR R2,[R0,#0]
			BICS R2,R2,R1
			LDR R1,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
			ORRS R2,R2,R1
			STR R2,[R0,#0]
			;Enable external connection for UART0
			LDR R0,=SIM_SOPT5
			LDR R1,= SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
			LDR R2,[R0,#0]
			BICS R2,R2,R1
			STR R2,[R0,#0]
			;Enable clock for UART0 module
			LDR R0,=SIM_SCGC4
			LDR R1,= SIM_SCGC4_UART0_MASK
			LDR R2,[R0,#0]
			ORRS R2,R2,R1
			STR R2,[R0,#0]
			;Enable clock for Port A module
			LDR R0,=SIM_SCGC5
			LDR R1,= SIM_SCGC5_PORTA_MASK
			LDR R2,[R0,#0]
			ORRS R2,R2,R1
			STR R2,[R0,#0]
			;Connect PORT A Pin 1 (PTA1) to UART0 Rx (J1 Pin 02)
			LDR R0,=PORTA_PCR1
			LDR R1,=PORT_PCR_SET_PTA1_UART0_RX
			STR R1,[R0,#0]
			;Connect PORT A Pin 2 (PTA2) to UART0 Tx (J1 Pin 04)
			LDR R0,=PORTA_PCR2
			LDR R1,=PORT_PCR_SET_PTA2_UART0_TX
			STR R1,[R0,#0] 
			;Disable UART0 receiver and transmitter
			LDR R0,=UART0_BASE
			MOVS R1,#UART0_C2_T_R
			LDRB R2,[R0,#UART0_C2_OFFSET]
			BICS R2,R2,R1
			STRB R2,[R0,#UART0_C2_OFFSET]
			;Initialize NVIC for UART0 Interrupts
			;Set UART0 IRQ Priority
			LDR R0, =UART0_IPR
			LDR R1, =NVIC_IPR_UART0_MASK
			LDR R2, =NVIC_IPR_UART0_PRI_3
			LDR R3, [R0, #0]
			BICS R3, R3, R1
			ORRS R3, R3, R2
			STR R3, [R0, #0]
			;Clear any pending UART0 Interrupts
			LDR R0, =NVIC_ICPR
			LDR R1, =NVIC_ICPR_UART0_MASK
			STR R1, [R0, #0]
			;Unmask UART0 interrupts
			LDR R0, =NVIC_ISER
			LDR R1, =NVIC_ISER_UART0_MASK
			STR R1, [R0, #0]
			;Init UART0 for 8N1 format at 9600 Baud,
			;and enable the recieve interrupt
			LDR R0, =UART0_BASE
			MOVS R1,#UART0_BDH_9600
			STRB R1,[R0,#UART0_BDH_OFFSET]
			MOVS R1,#UART0_BDL_9600
			STRB R1,[R0,#UART0_BDL_OFFSET]
			MOVS R1,#UART0_C1_8N1
			STRB R1,[R0,#UART0_C1_OFFSET]
			MOVS R1,#UART0_C3_NO_TXINV
			STRB R1,[R0,#UART0_C3_OFFSET]
			MOVS R1,#UART0_C4_NO_MATCH_OSR_16
			STRB R1,[R0,#UART0_C4_OFFSET]
			MOVS R1,#UART0_C5_NO_DMA_SSR_SYNC
			STRB R1,[R0,#UART0_C5_OFFSET]
			MOVS R1,#UART0_S1_CLEAR_FLAGS
			STRB R1,[R0,#UART0_S1_OFFSET]
			MOVS R1, \
			#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
			STRB R1,[R0,#UART0_S2_OFFSET] 
			;Enable UART0 transmitter, transmitter interrupt,
			;receiver, and receive interrupt
			MOVS R1,#UART0_C2_T_RI
			STRB R1,[R0,#UART0_C2_OFFSET] 
			;Pop prevous R0-2 values off the stack.
			POP {R0, R1, R2, PC}
			ENDP
			 
PutNumU		PROC    {R0-R14},{}
;Prints decimal representation of the unsigned word value in R0
;Calls: DIVU, PutChar
;Input: R0
;Output: Print to command line
;Register Modifications:
			PUSH	{R0,R1,R2,LR}			;preserve register values
			CMP		R0,#0					;if number is 0
			BEQ		ISZERO					;branch
			MOVS	R2,#0					;clear R2
			MOVS	R1,R0					;set R1 to number	
			LDR		R0,=DIV1M
			BL		DIVU					;Number/1000000
			BL		PRNTHLPR				;print result
			LDR		R0,=DIV100K
			BL		DIVU					;Number/100000
			BL		PRNTHLPR				;print result
			LDR		R0,=DIV10K
			BL		DIVU					;Number/10000
			BL		PRNTHLPR				;print result
			LDR		R0,=DIV1K
			BL		DIVU					;Number/1000
			BL		PRNTHLPR				;print result
			MOVS	R0,#0x64
			BL		DIVU					;Number/100
			BL		PRNTHLPR				;print result
			MOVS	R0,#0xA
			BL		DIVU					;Number/10
			BL		PRNTHLPR				;print result
			MOVS	R0,R1					;load remainder into R0
			ADDS	R0,R0,#0x30				;convert to ascii
			BL		PutChar					;print the number
			POP		{R0,R1,R2,PC}			;restore register values
ISZERO		
			MOVS	R0,#0x30	
			BL		PutChar					;print "0"
			POP		{R0,R1,R2,PC}			;restore register values
			ENDP

DIVU        PROC    {R2-R14},{}
;Computes R1 / R0 into R0 remainder R1
;Calls: DIVU, PutChar
;Input: R0, R1
;Output: R0, R1
;Register Modifications: R0, R1
			PUSH 	{R3,R4}					;store values of R3 and R4
			CMP 	R0, #0					;compare divisor to 0
			BEQ		SET_CAR					;if divisor is 0, go to special case
			CMP 	R1, #0					;compare dividend to zero
			BEQ		ZERODIV					;if dividend is 0, 
			B 		BRK 					;go to special case
SET_CAR
			MRS		R3,APSR					;set C flag to 1
			MOVS	R4,#0x20
			LSLS	R4,R4,#24
			ORRS	R3,R3,R4
			MSR		APSR,R3
			B 		ENDDIV
BRK		
			MOVS 	R3, #0 					;put quotient in R3
			
DIVWHILE			
			CMP 	R0, R1					;compare R0 and R1
			BHI 	ENDDIVWHILE				;if R0<R1 exit the loop
			ADDS 	R3, R3, #1 				;quotient ++
			SUBS 	R1, R1, R0 				;R1 = R1 - R0
			B 		DIVWHILE
			
ZERODIV
			MOVS	R3,#0					;IF dividend is zero, remainder is always zero
ENDDIVWHILE
			MOVS 	R0, R3					;R0 <- quotient, remainder = R1
			MRS		R3,APSR					;clear C flag to 0
			MOVS	R4,#0x20
			LSLS	R4,R4,#24
			BICS	R3,R3,R4
			MSR		APSR,R3
			
ENDDIV		
			POP 	{R3,R4}					;clear changes from registers
			BX 		LR 						;quit subroutine
			ENDP

PRNTHLPR 
;Prints character if character is not a leading zero
;Calls: PutChar
;Input: R0, R2
;Output: R0, R2
;Register Modifications: R0, R2
			
			PUSH	{LR}					;preserve register values
			CMP		R2,#1					;if character isnt a leading character
			BEQ		PRINTCHAR				;print it
			CMP		R0,#0					;if character is leading zero
			BEQ		PRNTQUITT				;quit
PRINTCHAR
			ADDS	R0,R0,#0x30				;convert char to ascii
			BL		PutChar					;print character
			MOVS	R2,#1					;indicates all future numbers aren't leading
PRNTQUITT	
			POP		{PC}					;restore register values
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
			ALIGN
PWM_duty_table_0
	DCW PWM_DUTY_10											;100% Range
	DCW ((3 * (PWM_DUTY_10 - PWM_DUTY_5)/4) + PWM_DUTY_5)	;75% Range
	DCW (((PWM_DUTY_10 - PWM_DUTY_5) / 2) + PWM_DUTY_5) 	;50% Range
	DCW (((PWM_DUTY_10 - PWM_DUTY_5) / 4) + PWM_DUTY_5) 	;25% Range
	DCW PWM_DUTY_5											;0% Range
			ALIGN
DAC0_table_0
	DCW ((DAC0_STEPS - 1) / (SERVO_POSITIONS * 2))
	DCW (((DAC0_STEPS - 1) * 3) / (SERVO_POSITIONS * 2)) 
	DCW (((DAC0_STEPS - 1) * 5) / (SERVO_POSITIONS * 2)) 
	DCW (((DAC0_STEPS - 1) * 7) / (SERVO_POSITIONS * 2))
	DCW (((DAC0_STEPS - 1) * 9) / (SERVO_POSITIONS * 2))
;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
QBuffer   		SPACE  	Q_BUF_SZ  ;Queue contents 
QRecord   		SPACE  	Q_REC_SZ  ;Queue management record 
			ALIGN
RxQueue   		SPACE	Q_BUF_SZ
RxQueueRecord	SPACE	Q_REC_SZ
			ALIGN
TxQueue			SPACE	Q_BUF_SZ
TxQueueRecord	SPACE	Q_REC_SZ
			ALIGN
FLAGS           SPACE 2
	
;>>>>>   end variables here <<<<<
            ALIGN
            END