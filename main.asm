; "Laggy Bird!"

; A game inspired by "Flappy Bird", a popular game from mid 2013.

; The purpose of this project was to learn how to interact with the console in
; a more complex way.  Originally I wanted to create a game modeled after the 
; Dinosaur Jumper that appears in the Chrome browser when there is no internet,
; however a jump mechanic bug that allowed infinite jumping inspired the pivot
; to a flying-style game.  Now instead of being tied to the ground, the character
; must fly through gaps in wall structures to avoid hitting the walls which would
; result in Game Over.  

; *** Important built-in Irvine functions: ***

; Gotoxy: Moves cursor to the xy coordinate in the console
; Clrscr: Clears the console
; SetTextColor: Sets text color of item to be printed (must manually change back)
; WriteString: Writes string data type to console
; WriteDec: Writes decimal value to console
; WriteChar: Writes character data type to console
; ReadChar: Blocking funtion, waits for user input and stalls program until received
; RandomRange: Chooses a random value in a defined range


; *** Important Windows API Funcitons: ***

; VK_SPACE: Defines key code for space bar
; VK_X: Defines key code for 'X' key
; GetAsyncKeyState: Non-blocking function that checks for user input
; Beep: Produces sound with ability to adjust hertz and duration



; Updated: 5/8/25
; Mike Tant


.386
.model flat, stdcall
option casemap:none

; Irvine Libraries
INCLUDE C:/Irvine/Irvine/Irvine32.inc
INCLUDELIB C:/Irvine/Irvine/Irvine32.lib

; Provides access to Windows API functions
INCLUDELIB kernel32.lib
INCLUDELIB user32.lib

; Windows API function to determine whether a key is being pressed
GetAsyncKeyState PROTO :DWORD

; Built-in sound function in Irvine
Beep PROTO, freq:DWORD, duration:DWORD




;;; DATA SECTION ;;;
.data

; Non-blocking checks for interrupts
VK_SPACE equ 20h    ; Virtual key code for space bar
VK_X     equ 58h    ; Virtual key code for 'X'

; Start Screen
showStartScreenFlag byte 1  ; 1 = show start screen, 0 = skip
startPrompt         byte "  Press any key to start...  ",0

; ASCII Art for home screen
asciiArt1  byte '      __       ',0
asciiArt2  byte '    <(o )___   ',0
asciiArt3  byte '     ( ._> /   ',0
asciiArt4  byte '      `---''   ',0
asciiArt5  byte '   LAGGY BIRD! ',0


; Credentials
version    byte '     v. 1.0    ',0
author     byte '  by: Mike Tant',0

; Ground animation
groundCounter byte 0
ground1       byte  '_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ', 0
ground2       byte  ' _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ', 0
useGround1    byte 1    ; Flag

; Score variables
strScore      byte ' Score: ', 0
score         dword 0
highScore     dword 0
strHighScore  byte "High Score: ", 0

; Game over messages
playAgainMsg   byte "Game Over! Your score: ",0
againPrompt    byte "Play again? (Y/N): ",0
dashedSpacer   byte "-------------------------------------",0
instructions1  byte "Objective: Avoid the obstacles", 0
instructions2  byte " Controls: Spacebar to fly", 0


; Player position in console
xPos byte 20
yPos byte 10

;Obstacle variables
xObstacle byte 0        ; Initializes x poition of obstacle
rightEdge byte 73       ; Defines x postion of starting point of obstacle
gapStartY byte ?        ; Initial gap position
gapWidth  byte 8        ; Controls the size of the gap in the wall
minGapY   byte 3        ; Top row for gap start
maxGapY   byte 28       ; Bottom row for play area

; Jump mechanics 
isJumping   byte 0      ; Initializes variables
jumpCounter byte 0
jumpHeight  byte 4      ; Jump height (higher the number = higher jump)

; Animation speeds
gameSpeed   dword 25    ; Millisecond delay between game loops
groundSpeed byte 7      ; Animate ground every 7 frames (slower than obstacle speed)




;;; CODE SECTION ;;;
.code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; MAIN GAME LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main PROC

mainLoop:
    cmp showStartScreenFlag, 1
    jne skipStart
    call ShowStartScreen        ; Show start screen if flag is set
    mov showStartScreenFlag, 0

skipStart:

mainGameStart:
    ; Reset all game variables for new game
    mov score, 0
    mov xPos, 20
    mov yPos, 10
    mov isJumping, 0
    mov jumpCounter, 0
    call Clrscr             ; Clear Screen

    invoke GetAsyncKeyState, VK_SPACE
    call DrawPlayer
    call CreateObstacle     ; Initialize first wall

gameLoop:
    inc score               ; Syncs the score to how many times the game loops
    ; Draw animated ground
    mov  dl, 0
    mov  dh, 29             ; Row 29, bottom of console
    call Gotoxy
    mov eax, white + (black * 16)
    call SetTextColor
    cmp useGround1, 1       ; Toggle between 2 ground patterns (oscillation gives illusion of movement)
    je drawG1
    mov edx, offset ground2
    jmp drawGround

drawG1:
    mov edx, offset ground1

drawGround:
    call WriteString

    ; Obstacle (wall) animation
    call UpdateObstacle     ; Erases old obstacle
    dec xObstacle           ; Moves obstacle to the left
    call DrawObstacle       ; Draws obstacle in new position

    ; Draw score
    mov eax, white + (black * 16)
    call SetTextColor
    mov dl, 60              ; XY position in console
    mov dh, 0
    call Gotoxy
    mov edx, offset strScore
    call WriteString
    mov eax, score
    call WriteDec

    ; Physics and input
    call ApplyGravity
    call CheckCollision
    call HandleInput

    ; Reset obstacle if journey is complete across the console                           ------------------------------

    cmp xObstacle, 0        ; Once obstacle has made it all the way to the left
    jg continueGame         ; Bypasses if obstacle is not there yet

    call UpdateObstacle     ; Erases obstacle from left side of console
    call CreateObstacle     ; Generates new obstacle at right side of console

continueGame:
    ; Animation timing
    mov eax, gameSpeed      ; Overall game speed  (lower = faster)
    call Delay              ; Takes integer and delays by milliseconds per frame
    inc groundCounter
    mov bl, groundSpeed
    cmp groundCounter, bl   ; Checks how many frames until animating ground
    jl skipGroundUpdate
    mov groundCounter, 0
    xor useGround1, 1       ; Toggle ground pattern

skipGroundUpdate:
    jmp gameLoop            ; Continues loop unitl collision event

;;; Exit Protocols Section ;;;
exitGame::
    call Clrscr

    ; Display final score
    mov eax, white + (black * 16)
    call SetTextColor
    mov dl, 30
    mov dh, 10
    call Gotoxy
    mov edx, offset playAgainMsg
    call WriteString
    mov eax, score
    call WriteDec           ; Writes decimal value to console (Irvine built-in)

    ; Update high score if needed
    mov eax, score
    cmp eax, highScore
    jbe skipHighScoreUpdate
    mov highScore, eax

skipHighScoreUpdate:
    ; Display high score in red
    mov eax, red + (black * 16)
    call SetTextColor
    mov dl, 30
    mov dh, 11
    call Gotoxy
    mov edx, offset strHighScore
    call WriteString
    mov eax, highScore
    call WriteDec

    ; Display play again prompt in white
    mov eax, white + (black * 16)
    call SetTextColor
    mov dl, 30
    mov dh, 13
    call Gotoxy
    mov edx, offset againPrompt
    call WriteString

waitInput:
    call ReadChar     ; "Yes" jumps back into game loop.
    cmp al, 'Y'
    je restartGame
    cmp al, 'y'
    je restartGame    ; "No" goes to start screen.
    cmp al, 'N'
    je showStartAgain
    cmp al, 'n'
    je showStartAgain
    jmp waitInput

restartGame:
    mov showStartScreenFlag, 0
    jmp mainGameStart

showStartAgain:
    mov showStartScreenFlag, 1
    jmp mainLoop

quitGame:
    exit
main ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; END MAIN GAME LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;;; DATA DISPLAY PROCEDURES ;;;

ShowStartScreen PROC
    call Clrscr
    ; ASCII Art of bird
    mov eax, yellow + (black * 16)
    call SetTextColor

    mov dl, 25       ; X position (adjust as needed)
    mov dh, 2        ; Y position (start row)
    call Gotoxy
    mov edx, offset asciiArt1
    call WriteString

    mov dl, 25
    mov dh, 3
    call Gotoxy
    mov edx, offset asciiArt2
    call WriteString

    mov dl, 25
    mov dh, 4
    call Gotoxy
    mov edx, offset asciiArt3
    call WriteString

    mov dl, 25
    mov dh, 5
    call Gotoxy
    mov edx, offset asciiArt4
    call WriteString

    mov dl, 25
    mov dh, 6
    call Gotoxy
    mov edx, offset asciiArt5
    call WriteString

    ; Version Text
    mov dl, 25
    mov dh, 7
    call Gotoxy
    mov edx, offset version
    call WriteString

    ; Author Text
    mov dl, 25
    mov dh, 9
    call Gotoxy
    mov edx, offset author
    call WriteString

    ; Instructions Text
    mov eax, white + (black * 16)
    call SetTextColor

    mov dl, 17
    mov dh, 11
    call Gotoxy
    mov edx, offset dashedSpacer
    call WriteString

    mov dl, 20
    mov dh, 12
    call Gotoxy
    mov edx, offset instructions1
    call WriteString

    mov dl, 20
    mov dh, 14
    call Gotoxy
    mov edx, offset instructions2
    call WriteString

    ; Prompt Text
    mov eax, white + (red * 16)
    call SetTextColor
    mov dl, 20
    mov dh, 18
    call Gotoxy
    mov edx, offset startPrompt
    call WriteString
    mov eax, white + (black * 16)
    call SetTextColor

    call ReadChar       ; Wait for any key
    ret
ShowStartScreen ENDP



;;; CHARACTER / OBSTACLE DRAWING PROCEDURES ;;;

DrawPlayer PROC
    mov eax, white + (black * 16)
    call SetTextColor
    mov dl, xPos
    mov dh, yPos
    call Gotoxy
    mov al, '>'         ; Character ASCII of a bird
    call WriteChar
    ret
DrawPlayer ENDP

;-------------------;

UpdatePlayer PROC
    mov dl, xPos
    mov dh, yPos
    call Gotoxy
    mov al, ' '         ; Overwrites character with blank space
    call WriteChar
    ret
UpdatePlayer ENDP

;-------------------;

CreateObstacle PROC
    ; Calculate the highest valid gap start
    mov al, maxGapY
    mov bl, gapWidth
    dec bl
    sub al, bl          ; al = maxGapY - (gapWidth - 1)
    mov bl, al          ; bl = highest valid gap start

    ; Calculates how many possible starting positions the gap can have
    mov al, minGapY
    mov cl, bl
    sub cl, al          ; cl = (max valid start) - minGapY
    inc cl              ; cl = number of possible positions

    ; Random number within range from previous calculations
    movzx eax, cl       ; Extends zeros to fill larger register (cl to eax)
    call RandomRange    ; result in al: 0 / (cl-1)
    add al, minGapY     ; shift to minGapY / max valid start
    mov gapStartY, al

    ; Sets obstacle X position to the right edge of console (starting point)
    mov dl, rightEdge
    mov xObstacle, dl   ; Reset to right edge 
    ret
CreateObstacle ENDP

;-------------------;

DrawObstacle PROC
    mov eax, yellow + (yellow * 16)
    call SetTextColor
    mov dl, xObstacle
    mov dh, 3            ; Start at top of screen

drawLoop:
    cmp dh, 28           ; Stop at ground (row 28)
    jg done

    ; Check if dh is within the gap (gapStartY .. gapStartY+4)
    mov al, gapStartY
    mov bl, dh
    cmp bl, al
    jb drawWall          ; If dh < gapStartY, draw wall
    add al, gapWidth     ; al = gapStartY + gapWidth
    cmp bl, al
    jb skipDraw          ; If dh < gapStartY + gapWidth, skip drawing (in gap)

drawWall:
    call Gotoxy
    mov al, 0B0h         ; Block character
    call WriteChar

skipDraw:
    inc dh               ; Next row moving downward
    jmp drawLoop
done:
    ret
DrawObstacle ENDP

;-------------------;

UpdateObstacle PROC
    ; Erase entire column
    mov eax, black + (black * 16)
    call SetTextColor
    mov dl, xObstacle
    mov dh, 3

; Loop to erase entire wall column
eraseLoop:
    cmp dh, 28
    jg doneErase
    call Gotoxy
    mov al, ' '
    call WriteChar
    inc dh
    jmp eraseLoop
doneErase:
    ret
UpdateObstacle ENDP




;;; GAME PHYSICS PROCEDURES ;;;

HandleInput PROC
    invoke GetAsyncKeyState, VK_SPACE
    test ax, 8000h
    jz checkExit
    cmp isJumping, 1
    je checkExit
    mov isJumping, 1
    mov al, jumpHeight
    mov jumpCounter, al    ; Resets jump height after jumping

checkExit:
    invoke GetAsyncKeyState, VK_X   ; Continuously check for 'X' key to exit game
    test ax, 8000h
    jnz exitGame
    ret
HandleInput ENDP

;-------------------;

ApplyGravity PROC
    cmp isJumping, 1    ; Checks for jumping flag
    jne falling         ; Moves character towards ground level if not jumping

    cmp jumpCounter, 0
    je endJump

    ; Max height for jump
    mov al, minGapY     ; Utilize minGapY to set ceiling for character
    cmp yPos, al
    jle endJump

    call UpdatePlayer
    dec yPos
    call DrawPlayer
    dec jumpCounter
    ret

endJump:
    mov isJumping, 0

falling:
    mov al, maxGapY     ; Utilize maxGapY to define ground level
    cmp yPos, al
    jge onGround        ; Only jumps to onGround when player is at ground level
    call UpdatePlayer
    inc yPos
    call DrawPlayer
onGround:               ; Character has reached ground
    ret
ApplyGravity ENDP

;-------------------;

CheckCollision PROC
    ; Check if character is in the same column as wall
    mov bl, xPos
    cmp bl, xObstacle
    jne noCollision

    ; The character is in the wall column, check if in gap.
    mov bl, yPos
    cmp bl, gapStartY
    jb collision            ; Above the gap

    sub bl, gapStartY
    cmp bl, 8
    jb noCollision          ; Inside the gap (0 - 8)

    ; Else, below the gap
    jmp collision

collision:          ; The character has collided with the wall
    push 300        ; duration: 300 ms
    push 350        ; frequency: 350 Hz
    call Beep
    add esp, 8      ; Clean up the stack
 
    jmp exitGame

noCollision:
    ret
CheckCollision ENDP



END main
