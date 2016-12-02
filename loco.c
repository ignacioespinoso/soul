#include "bico.h"

motor_cfg_t M1, M2;

void _start(void) {
    M1.id = 0;
    M2.id = 1;
    M1.speed = 0;
    M2.speed = 45;

    set_motor_speed(&M2);
    while(1);
}
