#include "bico.h"

motor_cfg_t M1, M2;

void _start(void) {
    M1.id = 0;
    M2.id = 1;
    M1.speed = 45;
    M2.speed = 0;

    set_motor_speed(&M1);
    while(1);
}
