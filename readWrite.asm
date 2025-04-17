; Main Console program
; Wayne Cook
; 10 March 2024
; Show how to do input and output
; Revised: WWC 14 March 2024 Added new module
; Revised: WWC 15 March 2024 Added this comment ot force a new commit.
; Revised: WWC 13 September 2024 Minor updates for Fall 2024 semester.
; Revised: WWC 23 September 2024 Split to have main, utils, & program.
; Revised: WWC 4 October 2024 Make writeNumber a recursive call.
; Revised: JB  4 November 2024 Added headers
; Revised: JB  8 November 2024 Updated headers and comments
; Revised: AG	18 November 2024 Added procedure to clear console.
; Revised: WWC  18 Novemeber 2024 Move cursor back to 0,0 on clear.
; Revised: IW  22 November 2024 Added working text color procedure.
; Revised: WWC 6 Janauary 2025 Divided into two sections, simple
;			calls to pop parameters off the stack and C++ compatible
;			calls to used built-in mechanism to remove parameters.
; Revised: WWC 27 February 2025 - added clarifying comment to calls
;;		push  addr		; like 'offset msg' - msg part of .data
; Register names are NOT case sensitive eax and EAX are the same register
; x86 uses 8 registers. EAX (Extended AX register has 32 bits while AX is
;	the right most 16 bits of EAX). AL is the right-most 8 bits.
; Writing into AX or AL effects the right most bits of EAX.
;		EAX - caller saved register - usually used for communication between
;			caller and callee.
;		EBX - Callee saved register
;		ECX - Caller saved register - Counter register 
;		EDX - Caller Saved register - data, I use it for saving and restoring
;			the return address
;		ESI - Callee Saved register - Source Index
;		EDI - Callee Saved register - Destination Index
;		ESP - Callee Saved register - stack pointer
;		EBP - Callee Saved register - base pointer.386P
;
;; The code is divided into two parts, simple and C++ compatible
;; The simple code uses pops to remove parameters from the stack.
;; The C++ compatible code uses a built-in mechanism to remove 
;; parameters from the stack. Eventually, all code should be
;; written using the C++ compatible code, but I find the simpler
;; calling sequece easier to understand. There are system calls
;; that I use that require me to specify the amount of bytes needed
;; for the parameters. For example @4 means four bytes (one
;; parameter) and @8 means eight bytes (two parameters).

; Routines:
;	initialize_console()						--	79
;	readLine()									--	106
;	charCount(addr)								--	135
;	writeLine(addr, chars)						--	173
;	writeNumber(number)							--	209
;	genNumber(number, pointer to ASCII buffer)	--	252
; 
; For Comments:
;	[--] means -4 bytes from ESP	(Add item to stack)
;		[-*#] means -(#*4) bytes from ESP
;	[++] means +4 bytes to ESP		(Remove item from stack)
;		[+*#] means +(#*4) bytes to ESP
; Comments on process end Lines:
;	[ESP+-=bytes added/taken (Net change * 4)], Whether all parameters were
;			removed from stack [+- net # item removed/added to stack]
.486P        ; States this is an x86 processor

.model flat  ; model must be specified before externals listed.

; Library calls used for input from and output to the console
extern	_GetStdHandle@4:				near  ; one param (4 bytes)
extern	_WriteConsoleA@20:				near  ; five params (20 bytes)
extern	_ReadConsoleA@20:				near
extern	_ExitProcess@4:					near
extern  _GetConsoleMode@8:				near  ; two params (8 bytes)
extern  _SetConsoleMode@8:				near
extern  _SetConsoleCursorPosition@8:	near
extern  _SetConsoleTitleA@4:			near
extern	_GetTickCount@0:				near
extern	_SetConsoleTextAttribute@8:		near
;extern  _SetTextColorA@8:				near

.data			; Where global data is defined for all procedures.

msg				byte	"Hello, World", 10, 0			; ends with Line feed (10) and NULL
prompt			byte	"Please type your name: ", 0	; ends with string terminator (NULL or 0)
results			byte	10,"You typed: ", 0
space			byte	" ",0
outputHandle	dword	?		; Output handle writing to consol. uninitslized
inputHandle		dword	?		; Input handle reading from consolee. uninitslized
written			dword	?
INPUT_FLAG		equ		-10
OUTPUT_FLAG		equ		-11

; Reading and writing requires buffers. I fill them with 00h.
readBuffer		byte	1024		DUP(00h)
writeBuffer		byte	1024		DUP(00h)
numberBuffer	byte	1024		DUP(00h)
numCharsToRead	dword	1024
numCharsRead	dword	1024
NULL			equ		0




;;Needed for clearing the console.
clear_console byte 1bh, '[', '2', 'J'
clear_scroll_back byte 1bh, '[', '3', 'J'

.code
;;******************************************************************;
;; Start of simple calls section
;;******************************************************************;
;; Call initialize_console()
;; Parameters:		None
;; Returns:			Nothing
;; Registers Used:	EAX
;; 
;; Initialize Input and Output handles so you only have to do that 
;;		once.
;; This is your first assembly routine
;; 
;; 
;; This process sets up the console by storing the handles to the 
;;		Input and the Output in inputHandle and outputHandle 
;;		respectively.
;; 
;; call initialize_console
;; 
;; Procedure has no parameters on the stack.
;;******************************************************************;
initialize_console PROC near
_initialize_console:
	; handle = GetStdHandle(-11)
	push  OUTPUT_FLAG			; [--]
	call  _GetStdHandle@4		; [--] [+*2]
	mov   outputHandle, eax
	; handle = GetStdHandle(-10)
	push  INPUT_FLAG			; [--]
	call  _GetStdHandle@4		; [--] [+*2]
	mov   inputHandle, eax
	ret							; [++]
initialize_console ENDP			; [ESP+=4], Parameters removed from stack [++]


;;******************************************************************;
;; Call readLine()
;; Parameters:		None
;; Returns:			EAX - ptr to buffer
;; Registers Used:	EAX
;; 
;; Requires initialize_console to be called first to set the
;;		read/write handles are set, read a Line
;; 
;; 
;; This process has no parameters. Instead it uses the
;;		_ReadConsoleA@20 library to get text input from the user via 
;;		the console referenced in the inputHandle. The library has 5 
;;		parameters. The first parameter pushed is the null character, 
;;		or the string terminator. The second parameter is the address 
;;		of a buffer to hold the number of chars read. The third 
;;		parameter is the max amount of chars to read from the handle. 
;;		The fourth parameter is the address of the buffer in which to
;;		store the read input. The fifth parameter holds the handle the 
;;		input is being read from. ReadConsoleA@20 stores the inputted 
;;		string in readBuffer. The address to the string is stored in 
;;		EAX which can then be used by the caller.
;; 
;; 
;; Calling Sequence:
;;		call  readLine
;; 
;; Procedure has no parameters on the stack.
;;******************************************************************;
readLine PROC near
_readLine:
	  ; ReadConsole(handle, &buffer, numCharToRead, numCharsRead, null)
	push  NULL						; Null [--]
	push  offset numCharsRead	; Number of characters read (1024) [--]
	push  numCharsToRead		; Number of characters to read (1024) [--]
	push  offset readBuffer		; Buffer to hold input in [--]
	push  inputHandle			; Handle for input [--]
	call  _ReadConsoleA@20		; Get input [--] [+*6]
	mov   eax, offset readBuffer	; Move address of readBuffer to EAX
	ret							; Return input in EAX [++]
readLine ENDP					; [ESP+=4], Parameters removed from stack [++]


;;******************************************************************;
;; Call charCount(addr)
;; Parameters:		addr - address of buffer = &addr[0]
;; Returns:			EAX - character count
;; Registers Used:	EAX, EBX, ECX, EDX
;; 
;; All strings need to end with a NULL (0). So I do not have to 
;;		manually count the number of characters in the Line, I wrote 
;;		this routine.
;; 
;; 
;; This process counts the number of character in a string. It pops 
;;		the address of buffer containing the string to be counted 
;;		into EBX. EAX is used as the counter, and ECX is used to pull 
;;		individual characters from the buffer to count them and check 
;;		for the string terminator. The process goes through a loop to 
;;		pull each character from EBX into the last 8 bits of ECX, 
;;		checks if the character is the string terminator (0), 
;;		increments EAX and increments EBX to the next character. If 
;;		the pulled character is the string terminator, the loop is 
;;		terminated and the process returns to the caller with the 
;;		character count in EAX. All parameters are removed from the 
;;		stack, so no adjustments to ESP are needed.
;; 
;; Calling Sequence:
;;		push  addr			; like 'offset msg' - msg part of .data
;;		call  charCount
;; 
;; Procedure removes all parameters from the stack.
;;******************************************************************;
charCount PROC near
_charCount:
	pop   edx					; Save return address [++]
	pop   ebx					; save offset/address of string [++]
	push  edx					; Put return address back on the stack [--]
	xor   eax,eax				; Set counter to 0
	xor   ecx,ecx				; Clear ECX register
_countLoop:
	mov   cl,[ebx]				; Look at the character in the string
	cmp   cl,NULL				; check for end of string.
	je    _endCount
	inc   eax					; Up the count by one
	inc   ebx					; go to next letter
	jmp   _countLoop
_endCount:
	ret							; Return with EAX containing character count [++]
charCount ENDP					; [ESP+=8], Parameter removed from stack [+*2]


;;******************************************************************;
;; Call writeLine(addr, chars) - push parameter in reverse order
;; Parameters:		addr - address of buffer = &addr[0]
;;					chars - character count in the buffer
;; Returns:			Nothing
;; Registers Used:	EAX, EBX, EDX
;; 
;; For all routines, the last item to be pushed on the stack is the 
;;		return address, save it to a register then save any other 
;;		expected parameters in registers, then restore the return
;;		address to the stack.
;; 
;; 
;; This routine has two parameters. The first parameter, addr, is 
;;		stored in EBX. The second parameter, chars, is stored in EAX. 
;;		addr is the address of the string to write to the console, 
;;		chars is the number of characters in the string. 
;;		_WriteConsoleA@20 is used to write to the console and it 
;;		takes 5 parameters. The first parameter pushed is the 
;;		character being used as null, or the string terminator. The 
;;		second parameter is a buffer to hold the characters written. 
;;		The third parameter is the number of chars to write, or chars. 
;;		The fourth parameter is the address of the buffer holding the 
;;		string to be written. The fifth parameter is the handle to 
;;		write to. All parameters are removed from the stack so no 
;;		adjustments to ESP are needed.
;; 
;; Calling Sequence:
;;		push  chars
;;		push  addr		; like 'offset msg' - msg part of .data
;;		call  writeLine
;; 
;; Procedure removes all parameters from the stack.
;;******************************************************************;
writeLine PROC near
_writeLine:
	pop   edx					; pop return address from the stack into EDX [++]
	pop   ebx					; Pop the buffer location of string to be printed into EBX [++]
	pop   eax					; Pop the buffer size string to be printed into EAX. [++]
	push  edx					; Restore return address to the stack [--]


	; WriteConsole(handle, &msg[NULL], numCharsToWrite, &written, NULL)
	push  NULL					; [--]
	push  offset written		; [--]
	push  eax					; return size to the stack for the call to _WriteConsoleA@20 (20 is how many bits are in the call stack) [--]
	push  ebx					; return the offset of the Line to be written [--]
	push  outputHandle			; [--]
	call  _WriteConsoleA@20		; [--] [+*6]
	ret							; [++]
writeLine ENDP					; [ESP+=12], Parameters removed from stack [+*3]


;;******************************************************************;
;; Call writeNumber(number)
;; Parameters:		number - decimal number to translate
;; Returns:			Nothing
;; Registers Used:	EAX, EBX, EDX, ESP
;; 
;; Takes a DD integer and writes it to the console as ASCII characters
;; writeNumber(number) was divided so genNumber could be a recursive 
;;		procedure
;; Uses the genNumber(number)
;; 
;; 
;; This process writes a number to the console. It has one parameter, 
;;		number, which is popped from the stack into EBX. The program 
;;		starts by using genNumber to convert the digits in number to 
;;		ASCII characters, which are then stored in the numberBuffer 
;;		that was pushed to the stack for genNumber. Since genNumber 
;;		does not remove all the parameters to the stack, 8 bytes are 
;;		added to ESP. Now that the number has been translated into a 
;;		string, the string is pushed to the stack so charCount can be 
;;		used to count the number of characters in the string. The 
;;		amount of characters is stored in EAX by charCount, so EAX is 
;;		pushed to the stack, along with the pointer to numberBuffer, 
;;		to be used by writeLine to write the number to the output 
;;		handle. Finally a space with a length of 1 is pushed to the 
;;		stack to write a space to the output handle using writeLine. 
;;		All parameters have been removed from the stack, so no 
;;		adjustment to ESP is needed.
;; 
;; 
;; Calling Sequence:
;;		push  number
;;		call  writeNumber
;; 
;; Procedure removes all parameters from the stack.
;;******************************************************************;
writeNumber PROC near
	pop   edx					; pop return address from the stack into EDX [++]
	pop   ebx					; Pop the number to be printed into EBX [++]
	push  edx					; Restore return address to the stack [--]
	push  offset numberBuffer	; Supplied buffer where number is written. [--]
	push  ebx					; and the number to be printed. [--]
	call  genNumber@8			; Generate the number [--] [++]
;	add   esp, 8				; Remove both parameters. [+*2]
	push  offset numberBuffer	; Supplied buffer where number is written. [--]
	call  charCount				; Count the number of chars in ASCII number [++]
	push  eax					; Return count in EAX [--]
	push  offset numberBuffer	; [--]
	call  writeLine				; Write the number. [--] [+*3]
	push  1						; [--]
	push  offset space			; [--]
	call  writeLine				; [--] [+*3]
	ret							; And it is time to exit. [++]
writeNumber ENDP				; [ESP+=8], Parameters removed from stack [+*2]

;;******************************************************************;
;; Call exit_console(error exit code)
;; Parameters:		error exit code - code to pass back to calling routine
;; Returns:         None, totally exits the program
;;
;; Simple exit of the program
;; Calling Sequence:
;;		push <error exit code>
;;		call exit_console
;;******************************************************************;
;; Calls ExitProcess(uExitCode)
exit_console PROC near
	pop   edx					; pop return address from the stack into EDX [++]
	pop   eax					; Pop the error exit code [++]
	push  edx					; Restore return address to the stack [--]

    push  eax					; Load the error exit coe
    call  _ExitProcess@4		; exit the program
exit_console ENDP

;;******************************************************************;
;; Start of C++ compatability calls, thus need for @ at end
;;******************************************************************;
;; Call genNumber(number, pointer to ASCII buffer)
;; Parameters:		number - decimal number to be converted to ASCII
;;					pointer to ASCII buffer - Address of buffer where 
;;						to store generated ASCII number
;; Returns:			ASCII buffer in parameters has generated ASCII 
;;						number.
;; Registers Used:	EAX (s), EBX, ECX (s), EDX (s), EBP (s), ESP (s),
;;					EDI (s), ESI (s)
;; ASM: call genNumber@8 for two parameters.
;; genNumber(number, pointer to ASCII buffer) create the ASCII value
;;	 of a number.
;; To help callers, I will save all registers, except eax, which 
;;	 will be location in number ASCII string to be written. This 
;;	 routine will show the official way to handle the stack and base 
;;	 pointers. It is less effecient, but it preserves all registers.
;; 
;; 
;; This process is used to translate a number to a string of ASCII 
;;		characters. This process is recursive, so care should be 
;;		taken to ensure there is not a stack overflow. This process 
;;		has two parameters: the number to translate, and the pointer 
;;		to a buffer to store the resulting string in. Both parameters 
;;		are accessed using EBP but are not removed from the stack. 
;;		The pointer that ESP contains at the start is stored in EBP 
;;		so that the parameters can be accessed, and so ESP can be 
;;		restored back to its inital value at the end so the return 
;;		address is not buried. Each recursive iteration, EAX is used 
;;		to hold the dividend which is the current number held in the 
;;		stack. If EAX equals 0, the recursive loop will end, EBX is 
;;		used to hold the pointer to the buffer. ECX is used to divide 
;;		the value held in EAX by 10 to remove the least significant 
;;		digit from the number to get ready to translate the next 
;;		digit. The least significant digit removed by the divide is 
;;		stored in EDX. The value in DX is then added to value of the 
;;		ASCII value for '0' to force translate the digit into ASCII. 
;;		The next recursive iteration is then called with the same 
;;		buffer address, but the number is set to the dividend stored 
;;		in EAX. Once the last iteration is reached, each iteration 
;;		will append the character they have stored in DX to the end 
;;		of the buffer, and EBX will be incremented to get ready for 
;;		the next iteration to appends its character. DX will then be
;;		set to a terminating null and appended to EBX. The working 
;;		registers are then restored and ESP is set back to the value 
;;		it had at the start of the routine. Finally the program 
;;		returns to the caller. The parameters are not removed from 
;;		the stack, so ESP needs to be adjusted by adding 8 bytes to 
;;		it. The resultant string will be stored in the buffer that 
;;		was passed to the stack as a parameter for genNumber.
;; 
;; 
;; Calling Sequence:
;;		push  <pointer to ASCII buffer>
;;		push  <number to be changed to ASCII>
;;		call  genNumber@8			; Two parameers to be removed
;;******************************************************************;
genNumber@8 PROC near			; @8 says there are 2 parameters (8 bytes)on the stack to remove on ret.
_genNumber:
	; Subroutine Prologue
	push  ebp					; Save the old base pointer value. [--]
	mov	  ebp, esp				; Set the new base pointer value to access parameters [EBP = ESP-=4]
	;sub   esp, 4				; Make room for one 4-byte local variable, if needed [--]
	push  edi					; Save the values of registers that the function [--]
	push  esi					; will modify. This function uses EDI and ESI. [--]
	; The eax, ebx, ecx, edx registers do not need to be saved,
	;		but they are for the sake of the calling routine.
	push  eax					; EAX needed as a dividend [--]
	;push  ebx					; Only save if not used as a return value [--]
	push  ecx					; Ditto [--]
	push  edx					; Ditto [--]
	; Subroutine Body
	mov   eax, [ebp+8]			; Move number value to be converted to ASCII
	mov   ebx, [ebp+12]			; The start of the generated ASCII buffer for storage
	mov   ecx, 10				; Set the divisor to ten
;; The dividend is placed in eax, then divide by ecx, the result goes into eax, with the remiander in edx
	cmp   eax, 0				; Stop when the number is 0
	jle   numExit
	mov   edx, 0				; Clear the register for the remainder
	div   ecx					; Do the divide
	add   dx,'0'				; Turn the remainder into an ASCII number
;; Do another recursive call;
	push  ebx					; Pass on the start of the number buffer. [--]
	push  eax					; And the number [--]
	call  genNumber@8			; ******Do the recursion***** [--] [++]
	;add   esp, 8				; Remove two parameters, needed on callbacks [+*2]
;; Load the number, one digit at a time.
	mov   [ebx], dl				; Add the number to the output sring
	inc   ebx					; go to the next ASCII location
	mov   dl, NULL					; cannot load a literal into an addressed location
	mov   [ebx], dl				; Add a terminating NULL to the end of the number
	
numExit:
	
	; If eax is used as a return value, make sure it is loaded by now.
	; And restore all saved registers
	; Subroutine Epilogue
	pop   edx					; [++]
	pop   ecx					; [++]
	;pop   ebx					; [++]
	pop   eax					; [++]
	pop   esi					; Recover register values [++]
	pop   edi					; [++]
	mov   esp, ebp				; Deallocate local variables [ESP-=4]
	pop   ebp					; Restore the caller's base pointer value [++]
	ret	8						; [++]
genNumber@8 ENDP					; [ESP+=4], 2 Parameters left on stack [++]

;;******************************************************************;
;; Call clearConsole@0
;; Parameters:		none
;; Returns:			nothing
;; Registers Used:	EAX (s), EBP (s), ESP (s)
;; clears console and scroll back too
;; returns console mode back to normal
;; https://learn.microsoft.com/en-us/windows/console/clearing-the-screen
;; can get much more advanced here: https://en.wikipedia.org/wiki/ANSI_escape_code
;; Calling Sequence:
;;		clearConsole@0			; no parameters, thus 0.
;; output: nothing
;;******************************************************************;
clearConsole@0 proc near
    push ebp ; save base
    mov ebp, esp ; get stack pointer

    sub esp, 4
    push esp
    push outputHandle
    ; https://learn.microsoft.com/en-us/windows/console/getconsolemode
    ; BOOL WINAPI GetConsoleMode(
    ; _In_  HANDLE  hConsoleHandle,
    ; _Out_ LPDWORD lpMode
    ; );
    call _GetConsoleMode@8

    cmp eax, 0
    je  _error

    mov eax, [ebp - 4] ; get current console mode
    or eax, 04h ; ENABLE_VIRTUAL_TERMINAL_PROCESSING ; https://learn.microsoft.com/en-us/windows/console/setconsolemode

    ; https://learn.microsoft.com/en-us/windows/console/setconsolemode
    ; BOOL WINAPI SetConsoleMode(
    ; _In_ HANDLE hConsoleHandle,
    ; _In_ DWORD  dwMode
    ; );
    push eax
    push outputHandle
    call _SetConsoleMode@8

    cmp eax, 0
    je _error
   
    ; print "\x1b[2J", clear viewable screen
    ; print "\x1b[3J", clear scroll back
    ; "\x1b" is an escape char = 1bh
    push 4
    push offset clear_console
    call writeLine

    push 4
    push offset clear_scroll_back
    call writeLine

	push 0						; Coordinates 0,0 to upper left corner.
	push  outputHandle			; [--]
	call _SetConsoleCursorPosition@8


    ; restore the mode on the way out to be nice to other command-Line applications
    ; pop eax   ; no need to pop and push
    ; push eax
    push outputHandle
    call _SetConsoleMode@8

    jmp _exit

_error:

_exit:
    mov esp, ebp ; because of the error handling, make sure no vars are forgotten
    pop ebp
    ret
clearConsole@0 endp

;;******************************************************************;
;; Call titleConsole@4
;; Parameters:		pointer to title string
;; Returns:			nothing
;; Registers Used:	EAX (s), EBP (s), ESP (s)
;; Puts the console title on the console's banner.
;; Calling Sequence:
;;		push <title buffer address>
;;		titleConsole@4			; one parameter, thus 4
;; output: title on banner
;;******************************************************************;
titleConsole@4 PROC near
	push ebp					; save base
    mov	 ebp, esp				; get stack pointer
	mov  eax, [ebp+8]			; Move the pointer to the title to EAX
	push eax					; Load the title
	call _SetConsoleTitleA@4		; Change the title
	mov  esp, ebp				; start restoration process before return
    pop  ebp
    ret
titleConsole@4 ENDP

;;******************************************************************;
;; Call setTextColor@4
;; Parameters:		value of desired background and text color
;; Returns:			nothing
;; Registers Used:	EAX (s), EBP (s), ESP (s)
;; Sets the background and text color to the desired value
;; Calling Sequence:
;;		push <background and foreground color values>
;;		setTextColor@4			; one parameter, thus 4
;; output: future ext of the desired color
;;******************************************************************;
setTextColor@4 PROC near
_setTextColor:
    push ebp					; save base
    mov	 ebp, esp				; get stack pointer
	mov  eax, [ebp+8]			; Move color value to be converted to ASCII
	push eax					; Load the color
    push outputHandle    
    call _SetConsoleTextAttribute@8  ; SetConsoleTextAttribute(lpdword outputHandle, word color)
    mov  esp, ebp
    pop  ebp
    ret 4
setTextColor@4 ENDP

;;******************************************************************;
;; Call getRandom@4
;; Parameters:		max number value for random number
;; Returns:			nothing
;; Registers Used:	EAX (s), EBP (s), ESP (s)
;; Calculate a random number between 0 and max number value - 1
;; Calling Sequence:
;;		push <max number value for random number>
;;		getRandom@4			; one parameter, thus 4
;; output: generate a random number in desired range.
;;******************************************************************;
getRandom@4 PROC near
	push ebp					; save base
    mov	 ebp, esp				; get stack pointer
	mov  ecx, [ebp+8]			; Move max number value to be converted to ASCII
	call _GetTickCount@0		; Returns tick count in EAX
	xor	 edx,edx
	idiv ecx					; Divide by max number
	mov	 eax,edx				; Move remainder into EAX
	mov  esp, ebp				; start restoration process before return
    pop  ebp
	ret  4
getRandom@4 ENDP
		
END