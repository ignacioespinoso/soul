@@@@@@@@
@@@@@@@@        Mariana Teixeira Bisca - RA174094
@@@@@@@@       Ignacio Espinoso Ribeiro - RA169767
@@@@@@@@                Trabalho 02 - MC404
@@@@@@@@                       SOUL
@@@@@@@@


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Constants                                                                    @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
   @ User code starting point constant
   .set USER_CODE_ADDRESS,     0x77802000

   @ GPT related constants.
   .set GPT_BASE,              0x53FA0000
   .set GPT_CR,                0x0
   .set GPT_PR,                0x4
   .set GPT_OCR1,              0x10
   .set GPT_IR,                0xC
   .set GPT_SR,                0x53FA0008

   @ Time constants.
   .set TIME_SZ,               10000
   .set FIFTEEN_MS,            2

   @ TZIC constants.
   .set TZIC_BASE,             0x0FFFC000
   .set TZIC_INTCTRL,          0x0
   .set TZIC_INTSEC1,          0x84
   .set TZIC_ENSET1,           0x104
   .set TZIC_PRIOMASK,         0xC
   .set TZIC_PRIORITY9,        0x424

   @ GPIO constants.
   .set GPIO_BASE,             0x53F84000
   .set GPIO_DR,               0x00
   .set GPIO_GDIR,             0x04
   .set GPIO_PSR,              0x08
   .set GDIR_MASK,             0b11111111111111000000000000111110

   @ stack size constant.
   .set STACK_SIZE,            0x800 @2048 bytes

   @ Sonar constants.
   .set VALIDATE_ID_MASK,      0b11111111111111111111111111110000
   .set ZERO_TRIGGER_MASK,     0b11111111111111111111111111111101
   .set SONAR_DATA_MASK,       0b00000000000000111111111111000000
   .set ZERO_MUX_MASK,         0b11111111111111111111111111000011

   @ Motor constants.
   .set MOTOR_0_MASK,          0b00000001111111000000000000000000
   .set SET_MOTOR_0_MASK,      0b00000000000001000000000000000000
   .set MOTOR_1_MASK,          0b11111110000000000000000000000000
   .set SET_MOTOR_1_MASK,      0b00000010000000000000000000000000
   .set SPEED_MASK,            0b00000000000000000000000001111111
   .set MOTORS_MASK,           0b11111111111111000000000000000000
   .set SET_MOTORS_MASK,       0b00000010000001000000000000000000

   @ Problem limitation constants.
   .set MAX_ALARMS,            8
   .set ALARMS_ARRAY_SIZE,     32
   .set MAX_CALLBACKS,         8
   .set CALLBACK_ARRAY_SIZE,   32
   .set THRESHOLD_ARRAY_SIZE,  16
   .set MAX_SPEED,             63

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ System start                                                                 @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.org 0x0
.section .iv,"a"

_start:

interrupt_vector:
   b RESET_HANDLER
.org 0x08
   b SYSCALL_HANDLER
.org 0x18
   b IRQ_HANDLER
.org 0x100

.text
   @ Sets time counter as zero.
   ldr r2, =TIME_COUNTER
   mov r0, #0
   str r0,[r2]

   @ Sets interruption flag as zero.
   ldr r2, =INTERRUPTION_IS_ACTIVE
   mov r0, #0
   str r0, [r2]

   @ Sets alarm counter as zero.
   ldr r2, =ALARMS_NUM
   mov r0, #0
   str r0, [r2]
RESET_HANDLER:
   @Set interrupt table base address on coprocessor 15.
   ldr r0, =interrupt_vector
   mcr p15, 0, r0, c12, c0, 0

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Setters                                                                      @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SET_GPT:
   ldr r1, =GPT_BASE

   @ Habilita o GPT_CR e configura clock_src para periferico
   mov r0, #0x41
   str r0, [r1, #GPT_CR]

   @ Zera o prescaler
   mov r0, #0
   str r0, [r1, #GPT_PR]

   @ Armazena 100 (valor a ser contabilizado) em GPT_OCR1
   ldr r0, =TIME_SZ
   str r0, [r1, #GPT_OCR1]

   @ Habilita a interrupcao Output Compare channel
   mov r0, #1
   str r0, [r1, #GPT_IR]

SET_TZIC:

   @ Liga o controlador de interrupcoes
   @ R1 <= TZIC_BASE

   ldr	r1, =TZIC_BASE

   @ Configura interrupcao 39 do GPT como nao segura
   mov	r0, #(1 << 7)
   str	r0, [r1, #TZIC_INTSEC1]

   @ Habilita interrupcao 39 (GPT)
   @ reg1 bit 7 (gpt)

   mov	r0, #(1 << 7)
   str	r0, [r1, #TZIC_ENSET1]

   @ Configure interrupt39 priority as 1
   @ reg9, byte 3

   ldr r0, [r1, #TZIC_PRIORITY9]
   bic r0, r0, #0xFF000000
   mov r2, #1
   orr r0, r0, r2, lsl #24
   str r0, [r1, #TZIC_PRIORITY9]

   @ Configure PRIOMASK as 0
   eor r0, r0, r0
   str r0, [r1, #TZIC_PRIOMASK]

   @ Habilita o controlador de interrupcoes
   mov	r0, #1
   str	r0, [r1, #TZIC_INTCTRL]

   @ instrucao msr - habilita interrupcoes
   msr  CPSR_c, #0x13                      @ SUPERVISOR mode, IRQ/FIQ enabled

SET_GPIO:
   ldr r1, =GPIO_BASE
   ldr r0, =GDIR_MASK
   str r0, [r1, #GPIO_GDIR]                @ Configures in/out lines in GDIR
   mov r2, #0
   str r2, [r1, #GPIO_DR]                  @ Sets DR as zero

SET_STACK:
   @ Sets up corresponding stack in each mode
   ldr sp, =SUPERVISOR_STACK

   msr CPSR_c, 0xDF
   ldr sp, =SYSTEM_STACK

   msr CPSR_c, 0xD2
   ldr sp, =IRQ_STACK

   msr CPSR_c, 0x10
   ldr pc, =USER_CODE_ADDRESS

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Handlers                                                                     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IRQ_HANDLER:
   stmfd sp!, {r0-r12, lr}
   mrs r0, SPSR
   stmfd sp!, {r0}                              @ Saves SPSR.

   ldr r1, =GPT_SR                              @ Writes 1 into GPT_SR
   mov r0, #1
   str r0, [r1]

   @ Increases time counter
   ldr r1, =TIME_COUNTER
   ldr r0, [r1]
   add r0, r0, #1
   str r0, [r1]

   ldr r0, =INTERRUPTION_IS_ACTIVE              @ If alarms and/or callbacks are
   ldr r1, [r0]                                    @ being checked...
   cmp r1, #0
   bne end_irq                                  @ Don't check them.

   ldr r0, =INTERRUPTION_IS_ACTIVE              @ Else, sets flag as active
   mov r1, #1
   str r1, [r0]

   alarms_check:
       ldr r0, =ALARMS_NUM                      @ Does the system have any alarm?
       ldr r0, [r0]
       cmp r0, #0
       beq callbacks_check                      @ Jumps to the end if it doesnt.

       mov r1, #4
       mul r0, r1, r0                           @ r0 stores the alarm vector size.
       mov r1, #0                               @ r1 stores the position.
       alarms_loop:                             @ Checks all alarms.
           ldr r2, =ALARMS_TIMES
           ldr r2, [r2, r1]                     @ Obtain the alarm time.

           ldr r3, =TIME_COUNTER
           ldr r3, [r3]                         @ Obtain the current system time.

           cmp r3, r2                           @ Compares the system and the alarm time.
           blo next_alarm

           stmfd sp!, {r0-r3, lr}               @ Caller save registers.
           ldr r0, =ALARMS_FUNCTIONS
           ldr r0, [r0, r1]                     @ Obtains the function pointer.
           bl execute_user_function
           ldmfd sp!, {r0-r3, lr}

           @ Deletes the current alarm, since it has been used.
           mov r2, #0                           @ R2 stores verified length.
           ldr r3, =ALARMS_TIMES
           ldr r4, =ALARMS_FUNCTIONS
           str r2, [r3]                         @ Store 0 in current alarm time.
           str r2, [r4]                         @ Same for the function pointer.
           add r2, r2, #4                       @ Updates verified length
           cmp r2, r0                           @ If there's not another alarm,
           bgt callbacks_check                     @ Ends the alarm check.

           mov r3, r1
           delete_alarm_loop:
               add r3, r3, #4                   @ Sets r3 to check the next alarm.
               ldr r4, =ALARMS_TIMES
               ldr r5, =ALARMS_FUNCTIONS
               ldr r6, [r4, r3]                 @ R6 stores next alarm time.
               ldr r7, [r5, r3]                 @ R7 next alarm function.
               sub r3, r3, #4                   @ Sets R3 to current alarm.
               str r6, [r4, r3]                 @ Copies the the next alarm time to the current one.
               str r7, [r5, r3]                 @ Same for the function.

               add r2, r2, #4                   @ Updates verified length.
               add r3, r3, #4                   @ Sets R3 to check next alarm
               cmp r2, r0                           @ if it exists.
               blo delete_alarm_loop

           ldr r5, =ALARMS_NUM                  @ Obtain number of alarms.
           ldr r5, [r5]
           sub r5, r5, #1                       @ Remove 1 from that amount.
           ldr r6, =ALARMS_NUM
           str r5, [r6]                         @ Update number of alarms.

       next_alarm:
           add r1, r1, #4                       @ Sets value to check next alarm
           cmp r1, r0                              @ if it exists.
           blo alarms_loop


   callbacks_check:
       ldr r4, =ACTIVE_CALLBACKS                @ Loads number of active callbacks.
       ldr r4, [r4]
       mov r5, #0                               @ Sets up r5 as counter.

       callbacks_loop:
           cmp r4, r5                           @ Are there any registered callbacks to check?
           beq end_loop                             @ If not, jump to end.
                                                @ Else, check them.

           @ Start by loading the current sonar ID.
           ldr r6, =CALLBACK_SONARS
           ldrb r6, [r6, r5]

           @ Then get its reading.
           msr CPSR_c, 0x1F                     @ Switches to system mode.
           sub r10, sp, #4                      @ Saves element after stack and lr.
           ldr r9, [r10]
           mov r10, lr
           stmfd sp!, {r6}                      @ Pushes sonar ID onto stack.
           mov r7, #16
           svc 0x0                              @ Syscall to read_sonar.
           str r9, [sp]                         @ Places element after stack back into place.
           add sp, sp, #4                       @ Makes sure SP is right where it was before.
           msr CPSR_c, 0xD2                     @ Switches back to IRQ mode.

           @ Then compare said reading with the respective threshold
           ldr r6, =CALLBACK_THRESHOLDS
           mov r8, #2
           mul r8, r5, r8                       @ Multiplies counter by unsigned short size.
           ldrh r3, [r6, r8]                    @ Loads threshold into r3.
           cmp r0, r3
           addhi r5, r5, #1                     @ If our distance is smaller than the threshold,
           bhi callbacks_loop                   @ Increases counter and continues.

           @ We're too close, let's call the appropriate callback function
           ldr r6, =CALLBACK_FUNCTIONS
           mov r8, #4
           mul r8, r5, r8
           ldr r0, [r6, r8]                     @ Loads function pointer into r0.
           stmfd sp!, {r4-r11, lr}
           bl execute_user_function             @ Executes function in appropriate mode and returns.
           ldmfd sp!, {r4-r11, lr}
           add r5, r5, #1                       @ Increases counter and continues.
           b callbacks_loop

       end_loop:
   ldr r0, =INTERRUPTION_IS_ACTIVE
   mov r1, #0                                   @ No verification is being run
   str r1, [r0]                                     @ anymore.

end_irq:
   ldmfd sp!, {r0}                              @ Get previous SPSR value.
   msr SPSR, r0
   ldmfd sp!, {r0-r12, lr}

   sub lr, lr, #4                               @ Corrects lr
   movs pc, lr

execute_user_function:
   stmfd sp!, {r0-r12, lr}                      @ Saves current register values.

   msr CPSR_c, #0x10                            @ Changes to user mode.

   mov r11, lr                                  @ Saves current user LR.
   blx r0                                       @ Execute the assigned function.
   mov lr, r11                                  @ Return user LR to previous
                                                    @ state.
   mov r7, #12                                  @ Syscall to return to IRQ mode.
   svc 0x0

   ldmfd sp!, {r0-r12, lr}                      @ Obtain saved register values.
   mov pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ Syscalls        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

SYSCALL_HANDLER:
   stmfd sp!, {r1-r12, lr}                      @ Save SVC register values.
   mrs r0, SPSR
   stmfd sp!, {r0}                              @ Saves SPSR.

   msr CPSR_c, 0x1F                             @ Changes to system mode.

   @ Transfers control flow to corresponding syscall
   cmp r7, #16
   beq read_sonar
   cmp r7, #17
   beq register_proximity_callback
   cmp r7, #18
   beq set_motor_speed
   cmp r7, #19
   beq set_motors_speed
   cmp r7, #20
   beq get_time
   cmp r7, #21
   beq set_time
   cmp r7, #22
   beq set_alarm
   cmp r7, #12
   beq irq_function_request

   msr CPSR_c, 0x13
   movs pc, lr

@@@@@@@@@@@@@@@@@@@@@
@ Sonars            @===========================================================
@@@@@@@@@@@@@@@@@@@@@
read_sonar:
   @ Checks if given sonar ID is valid (<16)
   ldr r0, [sp]
   ldr r2, =VALIDATE_ID_MASK
   and r1, r0, r2
   cmp r1, #0
   bne return_minus_one


   stmfd sp!, {r4-r11, lr}                      @ Saves callee-save registers.

   @ Writes sonar ID into the corresponding MUX bits in DR.
   ldr r1, =GPIO_BASE
   lsl r0, #2
   ldr r2, [r1, #GPIO_DR]
   ldr r3, =ZERO_MUX_MASK
   and r2, r2, r3
   orr r2, r2, r0

   @ Begins reading by setting trigger to zero.
   ldr r0, =ZERO_TRIGGER_MASK
   and r2, r2, r0
   str r2, [r1, #GPIO_DR]

   @ Delay 15ms.
   ldr r0, =TIME_COUNTER
   ldr r3, [r0]
   ldr r4, =FIFTEEN_MS
   add r3, r3, r4

first_delay:
   ldr r4, [r0]
   cmp r4, r3
   blo first_delay

   @ Now sets trigger as 1.
   mov r0, #2
   orr r2, r0
   str r2, [r1, #GPIO_DR]

   @ Delay 15ms.
   ldr r0, =TIME_COUNTER
   ldr r3, [r0]
   ldr r4, =FIFTEEN_MS
   add r3, r3, r4

second_delay:
   ldr r4, [r0]
   cmp r4, r3
   blo second_delay

   @ And finally, sets trigger back to zero.
   ldr r0, =ZERO_TRIGGER_MASK
   and r2, r2, r0
   str r2, [r1, #GPIO_DR]

   @ Loops until flag is set.
check_flag:
   ldr r0, [r1, #GPIO_DR]
   and r2, r0, #1
   cmp r2, #1
   bne check_flag

   @ Now that flag is set, we get our reading from the sonar_data bits.
   ldr r2, =SONAR_DATA_MASK
   and r0, r0, r2
   lsr r0, #6

   ldmfd sp!, {r4-r11, lr}

   msr CPSR_c, 0x13                             @ Switches to supervisor mode.
   ldmfd sp!, {r4}                              @ Get SPSR previous value.
   msr SPSR, r4
   ldmfd sp!, {r1-r12, lr}                      @ Get previous register values.
   movs pc, lr

register_proximity_callback:

   ldr r0, [sp]                                 @ Sonar ID.
   ldr r1, [sp, #4]                             @ Threshold distance.
   ldr r2, [sp, #8]                             @ Function address.

   @ Makes sure sonar ID is valid (<16).
   ldr r3, =VALIDATE_ID_MASK
   and r3, r3, r0
   cmp r3, #0
   bne return_minus_two

   @ Makes sure we don't have too many active callbacks already.
   ldr r3, =ACTIVE_CALLBACKS
   ldr r3, [r3]
   cmp r3, #MAX_CALLBACKS
   beq return_minus_one

   stmfd sp!, {r4-r11, lr}

   @ Stores the sonar ID.
   ldr r4, =CALLBACK_SONARS
   strb r0, [r4, r3]

   @ Stores the threshold distance.
   ldr r4, =CALLBACK_THRESHOLDS
   mov r5, #2
   mul r5, r3, r5
   strh r1, [r4, r5]

   @ Stores the function address.
   ldr r4, =CALLBACK_FUNCTIONS
   mov r5, #4
   mul r5, r3, r5
   str r2, [r4, r5]

   @ Increases number of active callbacks.
   ldr r1, =ACTIVE_CALLBACKS
   add r3, r3, #1
   str r3, [r1]
   ldmfd sp!, {r4-r11, lr}
   b return_zero

@@@@@@@@@@@@@@@@@@@@@
@ Motors            @===========================================================
@@@@@@@@@@@@@@@@@@@@@

set_motor_speed:
   ldr r0, [sp]
   ldr r1, [sp, #4]
   @ Checks if speed is valid.

   cmp r1, #MAX_SPEED
   bhi return_minus_two
   cmp r1, #0
   blo return_minus_two

   and r1, r1, #SPEED_MASK

   ldr r2, =GPIO_BASE                          @ Obtain how GPIO_DR actually is.
   ldr r2, [r2, #GPIO_DR]

   cmp r0, #1
   bne set_motor_0
   @ In case it should activate the second motor:
   lsl r1, #26                                 @ Adjust speed bits position.
   ldr r0, =SET_MOTOR_1_MASK                   @ Guarantees MOTOR1_WRITE bit equals 0.
   bic r1, r1, r0

   ldr r0, =MOTOR_1_MASK
   bic r0, r2, r0                              @ Clears the 2nd motor bits.
   orr r1, r0, r1                              @ Maintains the other bits.

   ldr r2, =GPIO_BASE
   str r1, [r2, #GPIO_DR]                      @ Sets the speed up.
   b return_zero

   @ In case it should activate the first motor:
   set_motor_0:
       cmp r0, #0                              @ Invalid parameter check.
       bne return_minus_one

       lsl r1, #19                             @ Adjust speed bits position.
       ldr r0, =SET_MOTOR_0_MASK               @ Guarantees MOTOR0_WRITE bit equals 0.
       bic r1, r1, r0

       ldr r0, =MOTOR_0_MASK
       and r1, r1, r0                          @ Adjust remaining speed bits.
       bic r0, r2, r0                          @ Clears the 1st motor GPIO_DR bits.
       orr r1, r0, r1                          @ Includes the new speed on GPIO_DR.

       ldr r2, =GPIO_BASE
       str r1, [r2, #GPIO_DR]                  @ Sets the speed up.

   b return_zero

set_motors_speed:
   ldr r0, [sp]
   ldr r1, [sp, #4]

   @ Verifies if the speeds are valid.
   cmp r0, #MAX_SPEED
   bhi return_minus_one
   cmp r0, #0
   blo return_minus_one

   cmp r1, #MAX_SPEED
   bhi return_minus_two
   cmp r1, #0
   blo return_minus_two

   @ If both speeds are valid, sets up the motors.
   and r0, r0, #SPEED_MASK                     @ Sets up the speed parameters
   and r1, r1, #SPEED_MASK
   lsl r1, #26                                 @ Adjust speed parameters positions.
   lsl r0, #19

   ldr r2, =GPIO_BASE
   ldr r2, [r2, #GPIO_DR]


   ldr r3, =MOTORS_MASK
   bic r2, r2, r3                              @ Clears the 1st and 2nd motor GPIO_DR bits.
   orr r0, r2, r0                              @ Includes the 1st motor on GPIO_DR.
   orr r1, r0, r1                              @ Includes the 2nd motor on GPIO_DR.

   ldr r2, =GPIO_BASE
   str r1, [r2, #GPIO_DR]                      @ Stores the new 1st and 2nd motors speed.

   b return_zero

@@@@@@@@@@@@@@@@@@@@@@
@ Time and alarms    @==========================================================
@@@@@@@@@@@@@@@@@@@@@@
get_time:
   ldr r0, =TIME_COUNTER
   ldr r0, [r0]                                @ Gets time from TIME_COUNTER pointer.


   msr CPSR_c, 0x13
   ldmfd sp!, {r9}                             @ Get SPSR previous value.
   msr SPSR, r9                                @ Same for other registers.
   ldmfd sp!, {r1-r12, lr}
   movs pc, lr

set_time:
   ldr r0, [sp]
   ldr r1, =TIME_COUNTER                       @ Gets TIME_COUNTER pointer.

   str r0, [r1]                                @ Sets up TIME_COUNTER.
   msr CPSR_c, 0x13

   ldmfd sp!, {r9}                             @ Get SPSR previous value.
   msr SPSR, r9                                @ Same for other registers.
   ldmfd sp!, {r1-r12, lr}
   movs pc, lr

set_alarm:
   ldr r0, [sp]
   ldr r1, [sp, #4]
   stmfd sp!, {r4, r11}

   ldr r2, =ALARMS_NUM                         @ Loads the current number of alarms.
   ldr r2, [r2]
   cmp r2, #MAX_ALARMS                         @ Verifies if we can put one more alarm.
   bhs return_minus_one                        @ Returns -1 if we can't.

   add r2, r2, #1                              @ Increase the number of alarms.
   ldr r3, =ALARMS_NUM
   str r2, [r3]                                @ Saves the new amount.

   ldr r3, =TIME_COUNTER                       @ Loads the current system time.
   ldr r3, [r3]
   cmp r3, r1                                  @ Compares it with the time parameter.
   bhs return_minus_two                        @ Returns -2 if the parameter is invalid.

   ldr r3, =ALARMS_FUNCTIONS
   sub r2, r2, #1
   mov r4, #4                                  @ r2 possui o deslocamento para
   mul r2, r4, r2                                  @ o novo alarme.
   str r0, [r3, r2]                            @ Stores the alarm function pointer.
   ldr r3, =ALARMS_TIMES
   str r1, [r3, r2]                            @ Stores the alarm time.
   ldmfd sp!, {r4, r11}
   b return_zero

@@@@@@@@@@@@@@@@@@@@@@@
@ Return to irq mode  @=========================================================
@@@@@@@@@@@@@@@@@@@@@@@
irq_function_request:
   msr CPSR_c, 0x13                            @ Switches to supervisor mode.

   ldmfd sp!, {r9}                             @ Get SPSR previous value.
   msr SPSR, r9
   ldmfd sp!, {r1-r12, lr}                     @ Same for other registers.
   mov r11, lr                                 @ Obtain supervisor LR.
   msr CPSR_c, 0xD2                            @ Switches to IRQ mode.

   mov pc, r11                                 @ Return to supervisor LR

@@@@@@@@@@@@@@@@@@@@@
@ Return options    @===========================================================
@@@@@@@@@@@@@@@@@@@@@
return_zero:
   mov r0, #0
   msr CPSR_c, 0x13

   ldmfd sp!, {r0}                              @ Get SPSR previous value.
   msr SPSR, r0
   ldmfd sp!, {r1-r12, lr}
   movs pc, lr

return_minus_one:
   mov r0, #-1
   msr CPSR_c, 0x13
   ldmfd sp!, {r0}                              @ Get SPSR previous value.
   msr SPSR, r0
   ldmfd sp!, {r1-r12, lr}
   movs pc, lr

return_minus_two:
   mov r0, #-2
   msr CPSR_c, 0x13
   ldmfd sp!, {r0}                              @ Get SPSR previous value.
   msr SPSR, r0
   ldmfd sp!, {r1-r12, lr}
   movs pc, lr

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ System data                                                                  @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
.data

SYSTEM_STACK:
   .space STACK_SIZE

SUPERVISOR_STACK:
   .space STACK_SIZE

IRQ_STACK:
   .space STACK_SIZE

TIME_COUNTER:
   .word 0x0

ACTIVE_CALLBACKS:
   .word 0x0

@ Information regarding the system alarms and callbacks.
INTERRUPTION_IS_ACTIVE:
   .word 0x0

ALARMS_NUM:
   .word 0x0
ALARMS_FUNCTIONS:
   .space ALARMS_ARRAY_SIZE
ALARMS_TIMES:
   .space ALARMS_ARRAY_SIZE

CALLBACK_FUNCTIONS:
   .space CALLBACK_ARRAY_SIZE
CALLBACK_SONARS:
   .space MAX_CALLBACKS
CALLBACK_THRESHOLDS:
   .space THRESHOLD_ARRAY_SIZE
