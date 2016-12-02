#include "bico.h"

motor_cfg_t M1, M2;

void _start(void) {
    int a, i;
    M1.id = 0;
    M2.id = 1;
    M1.speed = 60;
    M2.speed = 60;

    set_motors_speed(&M1, &M2);
    get_time(&a);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);
    for(i = 0; i < 1000000; i++);

    set_time(30);
    get_time(&a);

    if(a > 20) {
        M1.speed = 0;
        M2.speed = 5;

        set_motors_speed(&M1, &M2);
    }

    while(1);
}
