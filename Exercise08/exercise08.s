            TTL Multiprecision Arithmetic
;****************************************************************
;performs multi-word number I/O and addition
;Name:  Dean Trivisani
;Date:  10/30/2017
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
;0x38->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
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
UART0_C2_T_R  EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
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
	
DIV1K		EQU		0x3E8
DIV10K		EQU		0x2710
DIV100K		EQU		0x186A0
DIV1M		EQU		0xF4240
NVAL		EQU		3
HEXMAX		EQU		12
BUFFMAX		EQU		25
	

;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
			EXPORT 	PutChar
            IMPORT  Startup
Reset_Handler  PROC  {},{}
main
;---------------------------------------------------------------
;Mask interrupts

			CPSID   I
;KL46 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
			BL		Init_UART0_Polling      ;Initialize KL46 UART0	
NEWSTRING   PUSH	{R0-R7}
			BL		NEWLINE
			LDR     R0,=Prompt				;load prompt address into R0
			BL      PutStringSB				;print the prompt
PROMPTONE	LDR 	R0,=NumOne				;load input string address into R0
			LDR 	R1,=NVAL				;load max string size into R1
			BL		GetHexIntMulti			;get first value
			BCS		FAILURE1				;branch on failure
			LDR     R0,=Prompt2				;load promt address into R0
			BL      PutStringSB				;print the prompt			
PROMPTTWO	LDR		R0,=NumTwo
			BL		GetHexIntMulti			;get the second value
			BCS		FAILURE2					;branch on failure
			LDR		R0,=NumStore
			LDR		R2,=NumOne
			LDR		R1,=NumTwo
			MOVS	R3,#NVAL
			BL		AddIntMultiU			;add two values
			BCS		OVERFLOW				;branch on overflow
			MOVS	R1,#NVAL
			LDR     R0,=Sum					;load sum text address into R0
			BL      PutStringSB				;print the sum text
			LDR		R0,=NumStore
			BL		PutHexIntMulti			;print the sum
			POP		{R0,R1}
			BL		NEWLINE            		;print new line
			POP		{R0-R7}
			B		NEWSTRING		

FAILURE1
			LDR		R0,=Invalid
			BL		PutStringSB
			B		PROMPTONE
FAILURE2
			LDR		R0,=Invalid
			BL		PutStringSB
			B		PROMPTTWO
			
OVERFLOW
			LDR		R0,=Sum
			BL		PutStringSB
			LDR		R0,=Overflow
			BL		PutStringSB
			BL		NEWLINE
			B		NEWSTRING
			
;>>>>>   end main program code <<<<<
;Stay here
			ENDP
            B       .
;>>>>> begin subroutine code <<<<<
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

GetHexIntMulti PROC    {R0-R14},{}
;Get an n-word unsigned number from the user 
;typed in hexadecimal representation, and store
; it in binary in memory starting at the address
; in R0, where the value in R1 is n.  
;The subroutine reads characters typed by the user
; until the enter key is pressed by calling the 
;subroutine GetStringSB.  It then converts the ASCII hexadecimal 
;representation input by the user to binary, and 
;it stores the binary value to memory at the address 
;specified in R0.  If the result is a valid n-word 
;unsigned number, it returns with the APSR C bit clear; 
;otherwise, it returns with the APSR C bit set. 
;Inputs: R0,R1
;Outputs: None, stores car and sets C flag
			PUSH {R0-R7,LR}
			PUSH	{R0,R1}					;preserve reg values
			LSLS	R1,#3					;R1 <- 8n
			ADDS	R1,#1					;8n+1
			LDR		R0,=NumBuffer			;load buffer for the string
			BL		GetStringSB				;get string from user
			POP		{R0,R1}					;restore reg values
			MOVS	R3,#0					;initialize counter
			MOVS	R5,R1					
			LSLS	R5,#2					;R5 <- 4n
			MOVS	R6,R5					;R6 <- 4n
			LSLS	R5,#1					;R5 <- 8n
			SUBS	R6,R6,#1				;R6 <- 4n-1
GHIMLOOP
			LDR		R7,=NumBuffer			;load the buffer
			CMP		R3,R5
			BHS		QUITSUCC				;if the counter is 8n, we're done
			LDRB	R4,[R7,R3]
			CMP		R4,#'0'					;all "QUITFAIL" branches are checks for
			BLO		QUITFAIL				;valid characters
			CMP		R4,#'a'					;Convert char to uppercase if not already
			BLO		ISUPPERORNUM	
			SUBS	R4,R4,#' '
ISUPPERORNUM								;if char is uppercase or num 
			CMP		R4,#'F'					
			BHI		QUITFAIL
			CMP		R4,#'A'
			BLO		ISNUM					;convert to binary
			SUBS	R4,R4,#55
			B		CONT
ISNUM		CMP		R4,#'9'
			BHI		QUITFAIL
			SUBS	R4,R4,#0x30
CONT
			LSLS	R4,#4					;shift first character left
			ADDS	R3,R3,#1
			LDRB	R7,[R7,R3]				;load the second char into R7
			CMP		R7,#'0'					;then do literally the exact same thing
			BLO		QUITFAIL
			CMP		R7,#'a'
			BLO		ISUPPERORNUM2
			SUBS	R7,R7,#' '
ISUPPERORNUM2						
			CMP		R7,#'F'
			BHI		QUITFAIL
			CMP		R7,#'A'
			BLO		ISNUM2
			SUBS	R7,R7,#55
			B		STOREIT
ISNUM2		CMP		R7,#'9'
			BHI		QUITFAIL
			SUBS	R7,R7,#0x30
STOREIT
			ORRS	R4,R4,R7				;combine the two hex numbers
			STRB	R4,[R0,R6]				;store the hex value
			SUBS	R6,R6,#1				;decrement this offset
			ADDS	R3,R3,#1				;increment this offset

			B		GHIMLOOP
QUITFAIL									;set C flag to 1 and quit
			PUSH	{R3-R4}
			MRS		R3,APSR			
			MOVS	R4,#0x20
			LSLS	R4,R4,#24
			ORRS	R3,R3,R4
			MSR		APSR,R3
			POP		{R3-R4}
			POP		{R0-R7,PC}
QUITSUCC									;clear C flag and quit
			PUSH	{R1-R3}
			MRS 	R1, APSR
			MOVS 	R3, #0x20
			LSLS 	R1, R1, #24
			BICS 	R1, R1, R3
			MSR		APSR, R1
			POP		{R1-R3}
			POP		{R0-R7,PC}
			ENDP
			
PutHexIntMulti PROC    {R0-R14},{}
;Output an n-word unsigned number, 
;from memory starting at the address 
;in R0, to the terminal in hexadecimal 
;representation using 8n hex digits, 
;where the value in R1 is n. 
;Input: R0,R1
;Output: prints to terminal
;Calls: PutNumHex 
			PUSH	{R0,R2,R3,R4,LR}        ;
			MOVS	R3,R1					;store n in R3
			MOVS	R2,#3                   ;initialize offset value
			MOVS	R4,R0                   ;move address to r4
			LSLS	R3,R3,#2                ;n*4
			SUBS	R3,R3,#4                ;4n-4
			ADDS	R4,R4,R3                ;address += 4n-4

PHIMLOOP                                    ;loop for printing each byte in hex
			LDRB	R0,[R4,R2]              
			BL		PutNumHex               
			CMP		R2,#0                   
			BEQ		PHIMSKP                 ;if offset is 0 skip loop
			SUBS	R2,R2,#1                
			B		PHIMLOOP                
PHIMSKP                                     
			CMP		R3,#0                   ;if counter is 0, quit
			BEQ		PHIMQUIT                
			SUBS	R4,R4,#4                ;else decrement address 
			SUBS	R3,R3,#4                ;and counter by 4
			MOVS	R2,#3                   
			B		PHIMLOOP                ;loop
PHIMQUIT                                    
			POP		{R0,R2,R3,R4,PC}        
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
            PUSH        {R0,R1,R2,R7,LR}   	;preserve register values
            MOVS        R7,R0           	;save copy of R0
            MOVS        R1,#24           	;initialize shift value
LOOP     	
			MOVS        R0,R7           	
            LSLS        R0,R0,R1        	;shift R0 left 
            LSRS        R0,R0,#28       	;shift R0 right
            CMP         R0,#10          	;check if number is bigger than or equal to 10
            BHS         ISHEX          		;if yes, it's a letter
			ADDS        R0,R0,#'0'       	;if no, it's a number
            B           PRNT        		;print the number
ISHEX      	
			ADDS        R0,R0,#('A'-10)     ;convert number to hex letter
PRNT    	
			BL          PutChar         	;print the number
			ADDS        R1,R1,#4        	;shift value += 4
            CMP         R1,#32          	;if shift value is 32, no more characters 
            BHS         QUIT          		;then quit
            B           LOOP         		;else loop
QUIT      	
			POP         {R0,R1,R2,R7,PC}   	;restore register values
			
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
			PUSH 	{R3,R4}					; store values of R3 and R4
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
			
		
 
Init_UART0_Polling
;Store initial values of R0, R1, and R2
	PUSH {R0,R1,R2}
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
;Set UART0 for 9600 baud, 8N1 protocol
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
;Enable UART0 receiver and transmitter
        MOVS R1,#UART0_C2_T_R
        STRB R1,[R0,#UART0_C2_OFFSET] 
;Restore original register values
	POP {R0,R1,R2}
	BX LR

GetChar
;Takes a character from input and stores it in R0
;Inputs: R1, R2, R3
;Outputs: R0
;Register Modifications: R0, R1, R2, R3
			;Store initial values of R1, R1, and R2
			PUSH {R1, R2, R3} 
			;Poll RDRF until UART0 ready to receive 
			LDR R1, =UART0_BASE
			MOVS R2, #UART0_S1_RDRF_MASK
PollRx
			LDRB R3, [R1, #UART0_S1_OFFSET]
			ANDS R3, R3, R2
			BEQ PollRx
			;Receive character and store in R0
			LDRB R0, [R1, #UART0_D_OFFSET]
			POP		{R1, R2, R3}
			BX LR	                            ; return to where the branch was called from
PutChar
;Transmits the character stored in R0
;Inputs: R1, R2, R3
;Outputs: R0
;Register Modifications: R0, R1, R2, R3
			;Store initial values of R1, R2, and R3
			PUSH {R1, R2, R3} 
			;Poll TDRE Until UART0 is ready for transmit
			LDR R1, =UART0_BASE
			MOVS R2, #UART0_S1_TDRE_MASK
	
PollTx
			LDRB R3, [R1, #UART0_S1_OFFSET]
			ANDS R3, R3, R2
			BEQ PollTx
			;Transmit Character Stored in R0
			STRB R0, [R1, #UART0_D_OFFSET]
			;Restore original register values
			POP {R1, R2, R3}	
			BX LR                                 ; return to where the branch was called from

;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD    Dummy_Handler      ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    Dummy_Handler      ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
Prompt    	DCB     " Enter first 96-bit hex number:  0x", 0
Prompt2    	DCB     "Enter 96-bit hex number to add:  0x", 0
Sum			DCB		"                           Sum:  0x",0
Invalid		DCB		"Invalid number--try again:       0x", 0
Overflow	DCB		"OVERFLOW", 0

;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
STRINGIN	SPACE	8
FLAGS		SPACE	2
	ALIGN
NumOne		SPACE	HEXMAX
	ALIGN
NumTwo		SPACE	HEXMAX
	ALIGN
NumStore	SPACE	HEXMAX
	ALIGN
NumBuffer	SPACE	BUFFMAX
	ALIGN


;>>>>>   end variables here <<<<<
            ALIGN
            END