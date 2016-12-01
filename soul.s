    @ setting up constants

    @ GPT related constants
    .set GPT_BASE,              0x53FA0000
    .set GPT_CR,                0x0
    .set GPT_PR,                0x4
    .set GPT_OCR1,              0x10
    .set GPT_IR,                0xC
    .set GPT_SR,                0x53FA0008
    .set GPT_SR,                0x53FA0008

    @ Time constant
    .set TIME_SZ,               100


    @ TZIC constants
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

    @ GPIO constants
    .set GPIO_BASE,     0x53F84000
    .set GPIO_DR,       0x00
    .set GPIO_GDIR,     0x04
    .set GPIO_PSR,      0x08
    .set GDIR_MASK,     0b11111111111111000000000000111110

    @ stack size constant
    .set STACK_SIZE     0x800 @2048 bytes

    @ problem limitation constants
    .set MAX_ALARMS,    8
    .set MAX_CALLBACKS, 8

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
    ldr r2, =CONTADOR
    mov r0,#0
    str r0,[r2]

RESET_HANDLER:
    @Set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

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

    @instrucao msr - habilita interrupcoes
    msr  CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled

SET_GPIO:
    ldr r1, =GPIO_BASE
    ldr r0, =GDIR_MASK
    str r0, [r1, #GPIO_GDIR] @configures in/out lines in GDIR

SET_STACK:
    @ sets up corresponding stack in each mode
    ldr sp, =SUPERVISOR_STACK
    mcr CPSR_c, 0xDF
    ldr sp, =SYSTEM_STACK
    mcr CPSR_c, 0xD2
    ldr sp, =IRQ_STACK
    mcr CPSR_c, 0x10
    ldr sp, =USER_STACK

IRQ_HANDLER:

    @ Salva o valor 1 em GPT_SR
    ldr r1, =GPT_SR
    mov r0, #1
    str r0, [r1]

    @ Incrementa o contador de interrupcoes
    ldr r1, =CONTADOR
    ldr r1, [r1]
    mov r0, #1
    add r0, r0, r1
    str r0, [r1]

    @ Corrige o valor de LR
    sub lr, lr, #4
    movs pc, lr

SYSCALL_HANDLER:
    @transfers control flow to corresponding syscall
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

read_sonar:
    mov r1, =USER_STACK @ r1 acessara a pilha de usuario
    ldmfd r1!, {r0} @ desempilha parametro dado e coloca em r0


    movs pc, lr

.data
USER_STACK:
    .space STACK_SIZE

SYSTEM_STACK:
    .space STACK_SIZE

SUPERVISOR_STACK:
    .space STACK_SIZE

IRQ_STACK:
    .space STACK_SIZE


CONTADOR:
    .word 0x0
