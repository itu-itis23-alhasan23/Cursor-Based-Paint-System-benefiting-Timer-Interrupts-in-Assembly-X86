
        AREA    myData, DATA, READONLY
arr     DCD    0xA1, 0x15, 0x32, 0x27, 0x32, 0x14, 0xA0, 0x13, 0xA2, 0x11, 0x07, 0x32, 0x14, 0xA0, 0x11, 0xA3, 0x11, 0x27, 0x14, 0x07, 0xA0, 0x11, 0xA4, 0x14, 0x33, 0x27, 0x13, 0xA0, 0x11, 0xA5, 0x14, 0x03, 0x33, 0x04 , 0x13, 0xFF ; Input commands: change color, draw strokes, then stop

        AREA    myDataRW, DATA, READWRITE
varx    DCD     0                   ; cursor's horizontal position on canvas
vary    DCD     0                   ; cursor's vertical position on canvas
varc    DCB     0                   ; the currently selected brush color
        ALIGN                       ; make sure next variable starts at word boundary
vari    DCD     0                   ; keeps track of where we are in the input array
varb    DCD     0                   ; flag that tells main loop "hey, new data is ready!"
vard    DCD     0                   ; stores the actual input value we just received

        AREA    |.text|, CODE, READONLY
        THUMB                       ; using Thumb instruction set for Cortex-M0
        PRESERVE8                   ; keep stack 8-byte aligned

        EXPORT  __main
        EXPORT  SysTick_Handler

; System timer register addresses - these control the interrupt timing
SYST_CSR    EQU     0xE000E010     ; control/status register
SYST_RVR    EQU     0xE000E014     ; reload value register (sets the countdown)
SYST_CVR    EQU     0xE000E018     ; current value register

; Canvas memory layout - our "screen" where pixels get drawn
CANVAS      EQU     0x20001000     ; starting address in RAM
CANVAS_W    EQU     32             ; 32 pixels wide
CANVAS_H    EQU     8              ; 8 pixels tall

__main
        ; First, let's set up the timer to interrupt every second
        ; We're running at 10MHz, so we need to count 10 million cycles
        LDR     R0, =SYST_RVR           ; get the reload register address
        LDR     R1, =0x0098967F         ; this is 9,999,999 (we count from 0)
        STR     R1, [R0]                ; tell the timer "count down from here"

        ; Reset the current timer value to start fresh
        LDR     R0, =SYST_CVR           ; address of current value register
        MOVS    R1, #0                  ; write zero to reset it
        STR     R1, [R0]

        ; Now turn on the timer with interrupts enabled
        LDR     R0, =SYST_CSR           ; control register address
        MOVS    R1, #7                  ; bits: enable=1, interrupt=1, clocksource=1
        STR     R1, [R0]                ; start the timer!

        ; Set cursor to top-left corner (0,0) to start drawing
        LDR     R0, =varx               ; get address of x position
        MOVS    R1, #0                  ; starting x coordinate
        STR     R1, [R0]                ; save it
        
        LDR     R0, =vary               ; get address of y position
        MOVS    R1, #0                  ; starting y coordinate
        STR     R1, [R0]                ; save it

main_loop
        ; Main loop just waits for the interrupt to give us new data
        LDR     R0, =varb               ; check the "data ready" flag
        LDR     R1, [R0]                ; load current flag value
        CMP     R1, #0                  ; is it zero? (no new data)
        BEQ     main_loop               ; keep waiting if nothing new

        ; Got new data! Clear the flag so we don't process it twice
        MOVS    R1, #0                  ; prepare zero
        STR     R1, [R0]                ; clear the flag

        ; Grab the input value and go process it
        LDR     R0, =vard               ; address where input is stored
        LDR     R1, [R0]                ; load the actual input value
        BL      processInput            ; go figure out what to do with it

        B       main_loop               ; back to waiting for next input


;============================================================

processInput
        PUSH    {R0, R1, LR}            ; save registers (might need them later)

        MOVS    R0, R1                  ; make a copy of input
        LSRS    R0, R0, #4              ; shift right 4 bits to get upper nibble (the command type)

        CMP     R0, #0x0A               ; is it 'A'? that means change color
        BEQ     cmd_changeColor

        ; Not color, must be movement. Check which direction
        CMP     R0, #0                  ; command 0 means go up
        BEQ     cmd_moveUp
        CMP     R0, #1                  ; command 1 means go right
        BEQ     cmd_moveRight
        CMP     R0, #2                  ; command 2 means go down
        BEQ     cmd_moveDown
        CMP     R0, #3                  ; command 3 means go left
        BEQ     cmd_moveLeft

        POP     {R0, R1, PC}            ; unknown command, just return

cmd_changeColor
        ; Input is 0xAC where C is the new color
        MOVS    R0, #0x0F               ; mask to get lower 4 bits
        ANDS    R1, R1, R0              ; extract the color value
        MOVS    R0, #0x11               ; we multiply by 0x11 to spread it across byte
        MULS    R1, R0, R1              ; so color 8 becomes 0x88 (looks better in memory view)
        LDR     R0, =varc               ; address of color variable
        STRB    R1, [R0]                ; save the new color
        POP     {R0, R1, PC}            ; done, go back

cmd_moveUp
        MOVS    R0, #0x0F               ; mask for lower nibble
        ANDS    R1, R1, R0              ; get the length (how many steps)
        MOVS    R0, #0                  ; direction code 0 = up
        BL      moveAndPaint            ; go do the movement
        POP     {R0, R1, PC}

cmd_moveRight
        MOVS    R0, #0x0F               ; extract length
        ANDS    R1, R1, R0
        MOVS    R0, #1                  ; direction 1 = right
        BL      moveAndPaint
        POP     {R0, R1, PC}

cmd_moveDown
        MOVS    R0, #0x0F               ; extract length
        ANDS    R1, R1, R0
        MOVS    R0, #2                  ; direction 2 = down
        BL      moveAndPaint
        POP     {R0, R1, PC}

cmd_moveLeft
        MOVS    R0, #0x0F               ; extract length
        ANDS    R1, R1, R0
        MOVS    R0, #3                  ; direction 3 = left
        BL      moveAndPaint
        POP     {R0, R1, PC}


;============================================================

moveAndPaint
        PUSH    {R0, R1, LR}            ; save our direction and counter

moveLoop
        CMP     R1, #0                  ; are we done with all steps?
        BEQ     moveDone                ; yep, exit the loop

        ; Check which direction we're going and call right function
        CMP     R0, #0
        BEQ     moveUpStep              ; direction 0 = up
        CMP     R0, #1
        BEQ     moveRightStep           ; direction 1 = right
        CMP     R0, #2
        BEQ     moveDownStep            ; direction 2 = down
        CMP     R0, #3
        BEQ     moveLeftStep            ; direction 3 = left
        B       moveDone                ; shouldn't happen, but just in case

moveUpStep
        PUSH    {R0, R1}                ; save direction and counter before calling
        BL      goUp                    ; move cursor up by one
        POP     {R0, R1}                ; restore direction and counter
        B       afterMove               ; now go paint

moveRightStep
        PUSH    {R0, R1}                ; save our loop variables
        BL      goRight                 ; move right by one
        POP     {R0, R1}                ; get them back
        B       afterMove

moveDownStep
        PUSH    {R0, R1}
        BL      goDown                  ; move down by one
        POP     {R0, R1}
        B       afterMove

moveLeftStep
        PUSH    {R0, R1}
        BL      goLeft                  ; move left by one
        POP     {R0, R1}
        B       afterMove

afterMove
        ; We moved, now paint at the new position
        PUSH    {R0, R1}                ; save loop variables again
        BL      paint                   ; put color at current cursor position
        POP     {R0, R1}                ; restore them

        SUBS    R1, R1, #1              ; one step done, decrement counter
        B       moveLoop                ; repeat until counter hits zero

moveDone
        POP     {R0, R1, PC}            ; all done, return to caller


;============================================================


goUp
        PUSH    {R0, R1, LR}            ; need to save registers
        LDR     R0, =vary               ; get y position address
        LDR     R1, [R0]                ; load current y value
        CMP     R1, #0                  ; are we already at top (y=0)?
        BEQ     goUpDone                ; yes, can't go higher
        SUBS    R1, R1, #1              ; subtract 1 from y (move up)
        STR     R1, [R0]                ; save new y position
goUpDone
        POP     {R0, R1, PC}            ; restore and return





goDown
        PUSH    {R0, R1, LR}
        LDR     R0, =vary               ; get y address
        LDR     R1, [R0]                ; current y
        CMP     R1, #(CANVAS_H-1)       ; at bottom already? (y=7)
        BGE     goDownDone              ; can't go lower
        ADDS    R1, R1, #1              ; add 1 to y (move down)
        STR     R1, [R0]                ; save it
goDownDone
        POP     {R0, R1, PC}



goRight
        PUSH    {R0, R1, LR}
        LDR     R0, =varx               ; get x address
        LDR     R1, [R0]                ; current x
        CMP     R1, #(CANVAS_W-1)       ; at right edge? (x=31)
        BGE     goRightDone             ; can't go further right
        ADDS    R1, R1, #1              ; add 1 to x (move right)
        STR     R1, [R0]                ; save new x
goRightDone
        POP     {R0, R1, PC}




goLeft
        PUSH    {R0, R1, LR}
        LDR     R0, =varx               ; x address
        LDR     R1, [R0]                ; current x
        CMP     R1, #0                  ; at left edge already?
        BEQ     goLeftDone              ; yep, can't go more left
        SUBS    R1, R1, #1              ; subtract 1 from x (move left)
        STR     R1, [R0]                ; save it
goLeftDone
        POP     {R0, R1, PC}


;============================================================
; paint - writes current color to canvas at cursor position
; Canvas memory is laid out as: address = base + (y*32) + x




paint
        PUSH    {R0, R1, LR}            ; save registers

        ; First calculate the memory offset for current position
        LDR     R0, =vary               ; get y coordinate
        LDR     R1, [R0]
        LSLS    R1, R1, #5              ; multiply y by 32 (shift left 5 = *32)

        LDR     R0, =varx               ; get x coordinate
        LDR     R0, [R0]
        ADDS    R1, R1, R0              ; add x to (y*32) to get final offset

        ; Now calculate actual memory address
        LDR     R0, =CANVAS             ; base address of canvas
        ADDS    R0, R0, R1              ; add offset to get pixel address

        ; Write the color to that address
        LDR     R1, =varc               ; get current color
        LDRB    R1, [R1]                ; load color value (it's a byte)
        STRB    R1, [R0]                ; write color to canvas memory

        POP     {R0, R1, PC}            ; restore and return



; SysTick_Handler - gets called automatically every 1 second
; This is our "interrupt service routine" that grabs the next
; input from the array and signals the main loop




SysTick_Handler
        PUSH    {R0, R1, LR}            ; save registers (always do this in interrupts!)

        ; Figure out which array element we need to read
        LDR     R0, =vari               ; get index variable address
        LDR     R1, [R0]                ; load current index

        ; Calculate address: each element is 4 bytes (DCD), so multiply index by 4
        LSLS    R1, R1, #2              ; shift left 2 = multiply by 4
        LDR     R0, =arr                ; base address of input array
        ADDS    R0, R0, R1              ; add offset to get element address

        ; Read the value from the array
        LDR     R1, [R0]                ; load arr[index]

        ; Is this the end marker?
        CMP     R1, #0xFF               ; 0xFF means "no more inputs, stop"
        BEQ     stopSysTick             ; if so, disable the timer

        ; Not done yet, store this input for main loop to process
        LDR     R0, =vard               ; address of data storage
        STR     R1, [R0]                ; save the input value

        ; Tell main loop "hey, I got new data for you!"
        LDR     R0, =varb               ; address of flag variable
        MOVS    R1, #1                  ; set flag to 1
        STR     R1, [R0]                ; flag is now set

        ; Move to next array position for next time
        LDR     R0, =vari               ; get index address again
        LDR     R1, [R0]                ; load current index
        ADDS    R1, R1, #1              ; increment to next element
        STR     R1, [R0]                ; save incremented index

        POP     {R0, R1, PC}            ; done, return from interrupt

stopSysTick
        ; We hit 0xFF, so disable the timer - no more interrupts
        LDR     R0, =SYST_CSR           ; control register address
        MOVS    R1, #0                  ; zero means "turn off"
        STR     R1, [R0]                ; disable timer

        ; Clear the flag so main loop doesn't wait forever
        LDR     R0, =varb
        MOVS    R1, #0
        STR     R1, [R0]

        POP     {R0, R1, PC}            ; return from interrupt

        END                             
