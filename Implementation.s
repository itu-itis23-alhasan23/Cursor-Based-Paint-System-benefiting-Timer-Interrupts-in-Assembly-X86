AREA    myData, DATA, READONLY
arr     DCD    0xA1, 0x15, 0x32, 0x27, 0x32, 0x14, 0xA0, 0x13, 0xA2, 0x11, 0x07, 0x32, 0x14, 0xA0, 0x11, 0xA3, 0x11, 0x27, 0x14, 0x07, 0xA0, 0x11, 0xA4, 0x14, 0x33, 0x27, 0x13, 0xA0, 0x11, 0xA5, 0x14, 0x03, 0x33, 0x04 , 0x13, 0xFF

AREA    myDataRW, DATA, READWRITE
varx    DCD     0                   
vary    DCD     0                   
varc    DCB     0                   
        ALIGN                       
vari    DCD     0                   
varb    DCD     0                   
vard    DCD     0                   

AREA    |.text|, CODE, READONLY
        THUMB                       
        PRESERVE8                  

        EXPORT  __main
        EXPORT  SysTick_Handler


SYST_CSR    EQU     0xE000E010    
SYST_RVR    EQU     0xE000E014    
SYST_CVR    EQU     0xE000E018     

CANVAS      EQU     0x20001000     
CANVAS_W    EQU     32             
CANVAS_H    EQU     8              

__main
       
        LDR     R0, =SYST_RVR           
        LDR     R1, =0x0098967F         
        STR     R1, [R0]               

        LDR     R0, =SYST_CVR           
        MOVS    R1, #0               
        STR     R1, [R0]

        LDR     R0, =SYST_CSR          
        MOVS    R1, #7                
        STR     R1, [R0]               

        LDR     R0, =varx            
        MOVS    R1, #0                 
        STR     R1, [R0]               
        
        LDR     R0, =vary              
        MOVS    R1, #0                 
        STR     R1, [R0]              

main_loop
        LDR     R0, =varb               
        LDR     R1, [R0]              
        CMP     R1, #0                  
        BEQ     main_loop             

        MOVS    R1, #0               
        STR     R1, [R0]              

        LDR     R0, =vard              
        LDR     R1, [R0]                
        BL      processInput          

        B       main_loop               

processInput
        PUSH    {R0, R1, LR}           

        MOVS    R0, R1                 
        LSRS    R0, R0, #4              

        CMP     R0, #0x0A               
        BEQ     cmd_changeColor

        CMP     R0, #0                  
        BEQ     cmd_moveUp
        CMP     R0, #1                  
        BEQ     cmd_moveRight
        CMP     R0, #2                  
        BEQ     cmd_moveDown
        CMP     R0, #3                  
        BEQ     cmd_moveLeft

        POP     {R0, R1, PC}            

cmd_changeColor
        MOVS    R0, #0x0F               
        ANDS    R1, R1, R0              
        MOVS    R0, #0x11               
        MULS    R1, R0, R1              
        LDR     R0, =varc               
        STRB    R1, [R0]                
        POP     {R0, R1, PC}            

cmd_moveUp
        MOVS    R0, #0x0F               
        ANDS    R1, R1, R0              
        MOVS    R0, #0                  
        BL      moveAndPaint            
        POP     {R0, R1, PC}

cmd_moveRight
        MOVS    R0, #0x0F               
        ANDS    R1, R1, R0
        MOVS    R0, #1                  
        BL      moveAndPaint
        POP     {R0, R1, PC}

cmd_moveDown
        MOVS    R0, #0x0F               
        ANDS    R1, R1, R0
        MOVS    R0, #2                  
        BL      moveAndPaint
        POP     {R0, R1, PC}

cmd_moveLeft
        MOVS    R0, #0x0F               
        ANDS    R1, R1, R0
        MOVS    R0, #3                  
        BL      moveAndPaint
        POP     {R0, R1, PC}


moveAndPaint
        PUSH    {R0, R1, LR}            

moveLoop
        CMP     R1, #0                  
        BEQ     moveDone                

        CMP     R0, #0
        BEQ     moveUpStep              
        CMP     R0, #1
        BEQ     moveRightStep           
        CMP     R0, #2
        BEQ     moveDownStep            
        CMP     R0, #3
        BEQ     moveLeftStep            
        B       moveDone                

moveUpStep
        PUSH    {R0, R1}                
        BL      goUp                    
        POP     {R0, R1}                
        B       afterMove               

moveRightStep
        PUSH    {R0, R1}                
        BL      goRight                 
        POP     {R0, R1}                
        B       afterMove

moveDownStep
        PUSH    {R0, R1}
        BL      goDown                  
        POP     {R0, R1}
        B       afterMove

moveLeftStep
        PUSH    {R0, R1}
        BL      goLeft                  
        POP     {R0, R1}
        B       afterMove

afterMove
        PUSH    {R0, R1}                
        BL      paint                   
        POP     {R0, R1}                

        SUBS    R1, R1, #1              
        B       moveLoop                

moveDone
        POP     {R0, R1, PC}            

goUp
        PUSH    {R0, R1, LR}            
        LDR     R0, =vary               
        LDR     R1, [R0]                
        CMP     R1, #0                  
        BEQ     goUpDone                
        SUBS    R1, R1, #1              
        STR     R1, [R0]                
goUpDone
        POP     {R0, R1, PC}            

goDown
        PUSH    {R0, R1, LR}
        LDR     R0, =vary               
        LDR     R1, [R0]                
        CMP     R1, #(CANVAS_H-1)       
        BGE     goDownDone              
        ADDS    R1, R1, #1              
        STR     R1, [R0]                
goDownDone
        POP     {R0, R1, PC}

goRight
        PUSH    {R0, R1, LR}
        LDR     R0, =varx               
        LDR     R1, [R0]                
        CMP     R1, #(CANVAS_W-1)       
        BGE     goRightDone             
        ADDS    R1, R1, #1              
        STR     R1, [R0]                
goRightDone
        POP     {R0, R1, PC}

goLeft
        PUSH    {R0, R1, LR}
        LDR     R0, =varx               
        LDR     R1, [R0]                
        CMP     R1, #0                  
        BEQ     goLeftDone              
        SUBS    R1, R1, #1              
        STR     R1, [R0]                
goLeftDone
        POP     {R0, R1, PC}


paint
        PUSH    {R0, R1, LR}            

        LDR     R0, =vary               
        LDR     R1, [R0]
        LSLS    R1, R1, #5              
        LDR     R0, =varx               
        LDR     R0, [R0]
        ADDS    R1, R1, R0              

        LDR     R0, =CANVAS             
        ADDS    R0, R0, R1              

        LDR     R1, =varc               
        LDRB    R1, [R1]                
        STRB    R1, [R0]                

        POP     {R0, R1, PC}            

SysTick_Handler
        PUSH    {R0, R1, LR}            

        LDR     R0, =vari               
        LDR     R1, [R0]                

        LSLS    R1, R1, #2              
        LDR     R0, =arr                
        ADDS    R0, R0, R1              

        LDR     R1, [R0]                

        CMP     R1, #0xFF               
        BEQ     stopSysTick             

        LDR     R0, =vard               
        STR     R1, [R0]                

        LDR     R0, =varb               
        MOVS    R1, #1                  
        STR     R1, [R0]                

        LDR     R0, =vari               
        LDR     R1, [R0]                
        ADDS    R1, R1, #1              
        STR     R1, [R0]                

        POP     {R0, R1, PC}            

stopSysTick
        LDR     R0, =SYST_CSR           
        MOVS    R1, #0                  
        STR     R1, [R0]                

        LDR     R0, =varb
        MOVS    R1, #0
        STR     R1, [R0]

        POP     {R0, R1, PC}            

        END
