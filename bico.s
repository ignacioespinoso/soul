.global set_motor_speed
.global set_motors_speed
.global read_sonar
.global read_sonars
.global register_proximity_callback
.global add_alarm
.global get_time
.global set_time

.align 4

@******************************************************************************@
@* Motors                                                                     *@
@******************************************************************************@
set_motor_speed:
    stmfd sp!, {r4-r11,lr}

    ldrb r2, [r0]                   @ Obtem id.
    ldrb r1, [r0, #1]               @ Obtem velocidade.
    mov r0, r2                      @ Ajusta os valores obtidos para a syscall.

    stmfd sp!, {r1}
    stmfd sp!, {r0}
    mov r7, #18                     @ Identifica a syscall 18 (set_motor_speed).
    svc 0x0
    ldmfd sp!, {r4-r11, pc}

set_motors_speed:
    stmfd sp!, {r4-r11, lr}

    ldrb r2, [r0]                   @ Obtem as velocidades e id e dos parametros
    ldrb r0, [r0, #1]

    ldrb r3, [r1]
    ldrb r1, [r1, #1]

    cmp r2, #0                      @ Troca a posicao dos parametros caso o
    movne r2, r0                      @ primeiro nao corresponda ao primeiro
    movne r0, r1                      @ motor.
    movne r1, r2

    stmfd sp!, {r1}
    stmfd sp!, {r0}
    mov r7, #19                     @ Identifica a syscall 19 (set_motors_speed).
    svc 0x0

    ldmfd sp!, {r4-r11, pc}

@******************************************************************************@
@* Sonars                                                                     *@
@******************************************************************************@
read_sonar:
    stmfd sp!, {r4-r11, lr}

    stmfd sp!, {r0}
    mov r7, #16                     @ Identifica a syscall 16 (read_sonar).
    svc 0x0

    ldmfd sp!, {r4-r11, pc}

read_sonars:
    stmfd sp!, {r4-r11, lr}
    mov r3, r0
    mov r4, r1
    mov r5, #1
loop:
    stmfd sp!, {r0}
    mov r7, #16                     @ Identifica a syscall 16 (read_sonar).
    svc 0x0
    strb r0, [r2, r5]               @ Salva o valor de retorno no vetor.

    add r5, r5, #1                  @ Atualiza a posicao de salvar o retorno.
    add r3, r3, #1                  @ Atualiza o valor do sonar a ser lido.
    mov r0, r3

    cmp r3, r4
    bls loop

    ldmfd sp!, {r4-r11, pc}

register_proximity_callback:
    stmfd sp!, {r4-r11, lr}

    stmfd sp!, {r2}
    stmfd sp!, {r1}
    stmfd sp!, {r0}
    mov r7, #17                      @ Identifica a syscall 17 (register_proximity_callback).
    svc 0x0

    ldmfd sp!, {r4-r11, pc}

@******************************************************************************@
@* Timer                                                                      *@
@******************************************************************************@
add_alarm:
    stmfd sp!, {r4-r11, lr}

    stmfd sp!, {r1}
    stmfd sp!, {r0}
    mov r7, #22                     @ Identifica a syscall 22 (set_alarm)
    svc 0x0
    ldmfd sp!, {r1}
    ldmfd sp!, {r0}

    ldmfd sp!, {r4-r11, pc}

get_time:
    stmfd sp!, {r4-r11, lr}

    mov r1, r0                      @ Salva o endereco da variavel que
                                      @ recebe o tempo.

    mov r7, #20                     @ Identifica a syscall 20 (get_time)
    svc 0x0
    strb r0, [r1]

    ldmfd sp!, {r4-r11, pc}

set_time:
    stmfd sp!, {r4-r11, lr}

    stmfd sp!, {r0}
    mov r7, #21                     @ Identifica a syscall 20 (set_time)
    svc 0x0
    ldmfd sp!, {r0}

    ldmfd sp!, {r4-r11, pc}
