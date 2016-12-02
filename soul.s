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

    @ Time constant.
    .set TIME_SZ,               100

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
    .set STACK_SIZE,             0x800 @2048 bytes

    @ Sonar constants.
    .set VALIDATE_ID_MASK,      0b11111111111111111111111111110000
    .set ZERO_TRIGGER_MASK      0b11111111111111111111111111111101

    @ Motor constants.
    .set MOTOR_0_MASK,          0b00000001111111000000000000000000
    .set MOTOR_1_MASK,          0b11111110000000000000000000000000
    .set SPEED_MASK,            0b00000000000000000000000001111111

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

    @ Salva o valor 1 em GPT_SR
    ldr r1, =GPT_SR
    mov r0, #1
    str r0, [r1]

    @ Incrementa o contador de interrupcoes
    ldr r1, =TIME_COUNTER
    ldr r1, [r1]
    mov r0, #1
    add r0, r0, r1
    str r0, [r1]

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
    bne read_sonar_error

    @@@ seleciona sonar desejado para leitura
    ldr r1, =GPIO_BASE @ coloca base do GPIO em r1
    mov r2, #1 @ colca mascara em r2

    and r3, r2, r0 @ r3 tem o lsb
    lsl r3, #2 @ posiciona primeiro bit para escrita em DR
    ldr r4, [r1, #GPIO_DR] @ carrega conteudo de DR em r4
    orr r4, r4, r3 @ altera primeiro bit do mux

    lsl r2, #1 @ mascara agora selecionara o segundo bit
    and r3, r2, r0 @ r3 agora segura o segundo bit
    lsl r3, #2 @ posiciona segundo bit para escrita em dr
    orr r4, r4, r3 @ altera segundo bit do mux

    lsl r2, #1 @ mascara agora selecionara o terceiro bit
    and r3, r2, r0 @ r3 agora segura o terceiro bit
    lsl r3, #2 @ posiciona bit para escrita em DR
    orr r4, r4, r3 @ altera terceiro bit do mux

    lsl r2, #1 @ mascara agora selecionara quarto bit
    and r3, r2, r0 @ r3 agora segurara o quarto bit do mux
    lsl r3, #2 @ posiciona bit para escrita em DR
    orr r4, r4, r3 @ altera quarto bit do mux

    @@@inicia leitura
    ldr r0, =ZERO_TRIGGER_MASK @ coloca mascara que zera trigger em r0
    and r4, r4, r0 @ zera trigger em MUX
    str r4, [r1, #GPIO_DR] @ escreve em DR
    @ delay 15ms -> TO_DO
    mov r0, #1 @ coloca mascara que seleciona 1 bit em r0
    lsl r0, #1 @ desloca mascara para settar trigger
    orr r4, r0 @ seta trigger
    str r4, [r1, #GPIO_DR] @ escreve em DR
    @ delay de 15ms -> TO_DO
    ldr r0, =ZERO_TRIGGER_MASK @ coloca mascara que zera trigger em r0
    and r4, r4, r0 @ zera trigger em MUX
    str r4, [r1, #GPIO_DR] @ escreve em DR

check_flag:
    ldr r0, [r1, #GPIO_PSR] @ coloca conetudo de PSR em r0
    and r0, r0, #1
    cmp r0, #1
    beq flag_is_set
    @ caso nao: delay 10ms -> TO DO
    b check_flag
    @ caso sim: pegar leitura dos sonar_datas
flag_is_set:
    mov r2, #1
    lsl r2, #6 @ mascara setada para pegar primeiro bit de sonar_data
    and r3, r0, r2 @ r3 tem o primeiro bit de sonar data
    lsr r3, #6 @ coloca primeiro bit em posicao correta

    lsl r2, #1 @ mascara setada para pegar segundo bit de sonar_data
    and r4, r0, r2 @ r4 tem o segundo bit de sonar data
    lsr r4, #6 @ coloca segundo bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar terceiro bit de sonar_data
    and r4, r0, r2 @ r4 tem o terceiro bit de sonar data
    lsr r4, #6 @ coloca terceiro bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar quarto bit de sonar_data
    and r4, r0, r2 @ r4 tem o quarto bit de sonar data
    lsr r4, #6 @ coloca quarto bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar quinto bit de sonar_data
    and r4, r0, r2 @ r4 tem o quinto bit de sonar data
    lsr r4, #6 @ coloca quinto bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar sexto bit de sonar_data
    and r4, r0, r2 @ r4 tem o sexto bit de sonar data
    lsr r4, #6 @ coloca sexto bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar setimo bit de sonar_data
    and r4, r0, r2 @ r4 tem o setimo bit de sonar data
    lsr r4, #6 @ coloca setimo bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar oitavo bit de sonar_data
    and r4, r0, r2 @ r4 tem o oitavo bit de sonar data
    lsr r4, #6 @ coloca oitavo bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar nono bit de sonar_data
    and r4, r0, r2 @ r4 tem o nono bit de sonar data
    lsr r4, #6 @ coloca nono bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar decimo bit de sonar_data
    and r4, r0, r2 @ r4 tem o decimo bit de sonar data
    lsr r4, #6 @ coloca decimo bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar decimo primeiro bit de sonar_data
    and r4, r0, r2 @ r4 tem o decimo primeiro bit de sonar data
    lsr r4, #6 @ coloca decimo primeiro bit em posicao correta
    orr r3, r3, r4 @ soma bits

    lsl r2, #1 @ mascara setada para pegar decimo segundo bit de sonar_data
    and r4, r0, r2 @ r4 tem o decimo segundo bit de sonar data
    lsr r4, #6 @ coloca decimo segundo bit em posicao correta
    orr r3, r3, r4 @ soma bits

    mov r0, r3

    b end_read_sonar

read_sonar_error:
    mov r0, #-1

end_read_sonar:
    ldmfd sp!, {r4-r11, lr}
    msr CPSR_c, 0x13
    movs pc, lr

set_motor_speed:
    ldmfd sp!, {r0, r1}

    @ Checks if speed is valid.
    cmp r1, #MAX_SPEED
    bhi return_minus_two
    cmp r1, #-1
    bls return_minus_two

    and r1, r1, #SPEED_MASK

    cmp r0, #1
    bne set_motor_0
    @ In case it should activate the second motor:
    lsl r1, #25                             @ Adjust speed bits position.
    ldr r2, =GPIO_BASE
    ldr r2, [r2, #GPIO_DR]
    ldr r0, =MOTOR_1_MASK
    bic r0, r2, r0                          @ Clears the 2nd motor bits.
    orr r1, r0, r1                          @ Maintains the other bits.

    str r1, [r2, #GPIO_DR]                  @ Sets the speed up.
    b return_zero

    @ In case it should activate the first motor:
    set_motor_0:
        cmp r0, #0                              @ Invalid parameter check.
        bne return_minus_one

        lsl r1, #18                             @ Adjust speed bits position.
        ldr r2, =GPIO_BASE
        ldr r2, [r2, #GPIO_DR]
        ldr r0, =MOTOR_0_MASK
        bic r0, r2, r0                          @ Clears the 1st motor bits.
        orr r1, r0, r1                          @ Maintains the other bits.

        ldr r2, =GPIO_BASE
        str r1, [r2, #GPIO_DR]                  @ Sets the speed up.

    b return_zero

set_motors_speed:
    ldmfd sp!, {r0, r1}

    @ Verifies if the speeds are valid.
    cmp r0, #MAX_SPEED
    bhi return_minus_one
    cmp r0, #-1
    bls return_minus_one

    cmp r1, #MAX_SPEED
    bhi return_minus_two
    cmp r1, #-1
    bls return_minus_two

    @ If both speeds are valid, sets up the motors.
    and r0, r0, #SPEED_MASK                     @ Sets up the speed parameters
    and r1, r1, #SPEED_MASK
    lsl r1, #25
    lsl r0, #18

    ldr r2, =GPIO_BASE
    ldr r2, [r2, #GPIO_DR]

    ldr r3, =MOTOR_0_MASK                       @ Set the 1st motor
    bic r2, r2, r3                              @ Sets up the GPIO_DR register.
    orr r0, r2, r0
    ldr r2, =GPIO_BASE
    str r0, [r2, #GPIO_DR]

    ldr r3, =MOTOR_1_MASK                       @ Set the 2nd motor
    bic r2, r2, r3                              @ Sets up the GPIO_DR register.
    orr r1, r2, r1
    ldr r2, =GPIO_BASE
    str r1, [r2, #GPIO_DR]

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
