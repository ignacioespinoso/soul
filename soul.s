    @ Setting up constants

    @ User code starting point constant
    .set USER_CODE_ADDRESS,     0x77802000

    @ GPT related constants.
    .set GPT_BASE,              0x53FA0000
    .set GPT_CR,                0x0
    .set GPT_PR,                0x4
    .set GPT_OCR1,              0x10
    .set GPT_IR,                0xC
    .set GPT_SR,                0x53FA0008
    .set GPT_SR,                0x53FA0008

    @ Time constants.
    .set TIME_SZ,               100
    .set FIFTEEN_MS,            15 @ TODO: descobrir valor da constante

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
    .set SONAR_DATA_MASK,       0b00000000000000000011111111111100
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
    .set MAX_CALLBACKS,         8
    .set MAX_SPEED,             63

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
    @ Zera o contador
    ldr r2, =TIME_COUNTER
    mov r0,#0
    str r0,[r2]

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
    stmfd sp!, {r0-r12}
    @ Salva o valor 1 em GPT_SR
    ldr r1, =GPT_SR
    mov r0, #1
    str r0, [r1]

    @ Incrementa o contador de interrupcoes
    ldr r1, =TIME_COUNTER @ coloca endereco do TIME_COUNTER em r1
    ldr r0, [r1] @ coloca valor do time counter em r0
    add r0, r0, #1 @ soma 1 no counter
    str r0, [r1] @ escreve novo valor em TIME_COUNTER

    ldmfd sp!, {r0-r12}
    @ Corrige o valor de LR
    sub lr, lr, #4
    movs pc, lr

@@@@@@@@@@@@@@@@@@@
@ Syscalls        @
@@@@@@@@@@@@@@@@@@@
SYSCALL_HANDLER:
    msr CPSR_c, 0x1F                            @ Changes to system mode

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

    msr CPSR_c, 0x13
    movs pc, lr

read_sonar:
    ldmfd sp!, {r0} @ desempilha parametro dado e coloca em r0
    stmfd sp!, {r4-r11, lr} @ salva registradores
    ldr r2, =VALIDATE_ID_MASK
    and r1, r0, r2 @ valida id do sonar
    cmp r1, #0
    bne return_minus_one

    @@@ seleciona sonar desejado para leitura
    ldr r1, =GPIO_BASE @ coloca base do GPIO em r1
    lsl r0, #2 @desloca bits para escrita em MUX
    ldr r2, [r1, #GPIO_DR] @abre conteudo de DR em r2
    ldr r3, =ZERO_MUX_MASK @abre mascara em r3
    and r2, r2, r3 @ zera bits de MUX em DR
    orr r2, r2, r0 @ coloca novos bits do MUX no lugar em DR

    @@@inicia leitura
    ldr r0, =ZERO_TRIGGER_MASK @ coloca mascara que zera trigger em r0
    and r2, r2, r0 @ zera trigger em MUX
    str r2, [r1, #GPIO_DR] @ escreve em DR

    @ delay 15ms
    ldr r0, =TIME_COUNTER
    ldr r3, [r0]   @ coloca tempo atual em r3
    ldr r2, =FIFTEEN_MS @ coloca constante de 15ms em r2
    add r3, r3, r2 @ soma tempo atual com 15ms e poe em r3

first_delay:
    ldr r2, [r0] @ coloca novo tempo em r2
    cmp r2, r3 @ verifica se ja se passaram 15 ms
    blo first_delay @ se tempo nao foi atingido, continua delay

    mov r0, #1 @ coloca mascara que seleciona 1 bit em r0
    lsl r0, #1 @ desloca mascara para settar trigger
    orr r4, r0 @ seta trigger
    str r4, [r1, #GPIO_DR] @ escreve em DR
    @ delay 15ms
    ldr r0, =TIME_COUNTER
    ldr r3, [r0]   @ coloca tempo atual em r3
    ldr r2, =FIFTEEN_MS @ coloca constante de 15ms em r2
    add r3, r3, r2 @ soma tempo atual com 15ms e poe em r3

second_delay:
    ldr r2, [r0] @ coloca novo tempo em r2
    cmp r2, r3 @ verifica se ja se passaram 15 ms
    blo second_delay @ se tempo nao foi atingido, continua delay

    ldr r0, =ZERO_TRIGGER_MASK @ coloca mascara que zera trigger em r0
    and r4, r4, r0 @ zera trigger em MUX
    str r4, [r1, #GPIO_DR] @ escreve em DR

    @ verifica flag
check_flag:
    ldr r0, [r1, #GPIO_DR] @ coloca conetudo de PSR em r0
    and r0, r0, #1
    cmp r0, #1
    bne check_flag @ continua em loop ateh flag estar setada

    @ pega dados dos sonar_datas
    ldr r0, [r1, #GPIO_DR] @ coloca conetudo de PSR em r0
    ldr r2, =SONAR_DATA_MASK @ coloca mascara de sonar data em r2
    and r0, r0, r2 @ coloca conteudo dos sonar datas em r0
    lsr r0, #6 @ ajusta a posicao dos bits

    ldmfd sp!, {r4-r11, lr} @ desempilha registradores
    msr CPSR_c, 0x13    @ muda de modo
    movs pc, lr @ retorna

register_proximity_callback:
    msr CPSR_c, 0x13
    movs pc, lr

set_motor_speed:
    ldmfd sp!, {r0, r1}

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
    ldmfd sp!, {r0, r1}

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

get_time:
    ldr r0, =TIME_COUNTER
    ldr r0, [r0]                                @ Gets time from TIME_COUNTER pointer.
    msr CPSR_c, 0x13
    movs pc, lr

set_time:
    ldmfd sp!, {r0}
    ldr r1, =TIME_COUNTER                       @ Gets TIME_COUNTER pointer.

    str r0, [r1]                                @ Sets up TIME_COUNTER.
    msr CPSR_c, 0x13
    movs pc, lr

set_alarm:
    ldmfd sp!, {r0, r1}

    ldr r2, =ALARMS_NUM                         @ Loads the current number of alarms.
    ldr r2, [r2]
    cmp r2, #MAX_ALARMS                          @ Verifies if we can put one more alarm.
    bhs return_minus_one                        @ Returns -1 if we can't.

    add r2, r2, #1                              @ Increase the number of alarms.
    ldr r3, =ALARMS_NUM
    str r2, [r3]                                @ Saves the new amount.

    ldr r3, =TIME_COUNTER                       @ Loads the current system time.
    ldr r3, [r3]
    cmp r3, r1                                  @ Compares it with the time parameter.
    bls return_minus_two                        @ Returns -2 if the parameter is invalid.

    ldr r3, =ALARMS_FUNCTIONS
    str r0, [r3, r2]                            @ Stores the alarm function pointer.
    ldr r3, =ALARMS_TIMES
    str r1, [r3, r2]                            @ Stores the alarm time.
    b return_zero

@@@@@@@@@@@@@@@@@@@@@
@ Return options    @
@@@@@@@@@@@@@@@@@@@@@
return_zero:
    mov r0, #0
    msr CPSR_c, 0x13
    movs pc, lr

return_minus_one:
    mov r0, #-1
    msr CPSR_c, 0x13
    movs pc, lr

return_minus_two:
    mov r0, #-2
    msr CPSR_c, 0x13
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

@ Information regarding the system alarms.
ALARMS_NUM:
    .word 0x0
ALARMS_FUNCTIONS:
    .space MAX_ALARMS
ALARMS_TIMES:
    .space MAX_ALARMS
