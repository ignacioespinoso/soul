/****************************************************************
 * Description: Uoli Control Application Programming Interface.
 *
 * Authors: Edson Borin (edson@ic.unicamp.br)
 *
 * Date: 2016
 ***************************************************************/
#ifndef BICO_H
#define BICO_H


/**************************************************************/
/* Motors                                                     */
/**************************************************************/

/*
 * Struct for changing motor speed
 * id: the motor id (0 for left motor, 1 for right motor)
 * speed: the motor speed (Only the last 6 bits are used)
 */
typedef struct
{
  unsigned char id;
  unsigned char speed;
} motor_cfg_t;

/*
 * Sets motor speed.
 * Parameter:
 *   motor: pointer to motor_cfg_t struct containing motor id and motor speed
 * Returns:
 *   void
 */
void set_motor_speed(motor_cfg_t* motor);

/*
 * Sets both motors speed.
 * Parameters:
 *   * m1: pointer to motor_cfg_t struct containing motor id and motor speed
 *   * m2: pointer to motor_cfg_t struct containing motor id and motor speed
 * Returns:
 *   void
 */
void set_motors_speed(motor_cfg_t* m1, motor_cfg_t* m2);


/**************************************************************/
/* Sonars                                                     */
/**************************************************************/

/*
 * Reads one of the sonars.
 * Parameter:
 *   sonar_id: the sonar id (ranges from 0 to 15).
 * Returns:
 *   distance of the selected sonar
 */
unsigned short read_sonar(unsigned char sonar_id);


/*
 * Reads all sonars at once.
 * Parameters:
 *   start: reading goes from this integer and
 *   end: reading goes until this integer (a range of sonars to be read)
 *   distances: pointer to array that must receive the distances.
 * Returns:
 *   void
 */
void read_sonars(int start, int end, unsigned int* distances);

/*
 * Register a function f to be called whenever the robot gets close to an object. The user
 * should provide the id of the sensor that must be monitored (sensor_id), a threshold
 * distance (dist_threshold) and the user function that must be called. The system will
 * register this information and monitor the sensor distance every DIST_INTERVAL cycles.
 * Whenever the sensor distance becomes smaller than the dist_threshold, the system calls
 * the user function.
 *
 * Parameters:
 *   sensor_id: id of the sensor that must be monitored.
 *   sensor_threshold: threshold distance.
 *   f: address of the function that should be called when the robot gets close to an object.
 * Returns:
 *   void
 */
void register_proximity_callback(unsigned char sensor_id, unsigned short dist_threshold, void (*f)());

/**************************************************************/
/* Timer                                                      */
/**************************************************************/

/*
 * Adds an alarm to the system.
 * Parameter:
 *   f: function to be called when the alarm triggers.
 *   time: the time to invoke the alarm function.
 * Returns:
 *   void
 */
void add_alarm(void (*f)(), unsigned int time);

/*
 * Reads the system time.
 * Parameter:
 *   * t: pointer to a variable that will receive the system time.
 * Returns:
 *   void
 */
void get_time(unsigned int* t);

/*
 * Sets the system time.
 * Parameter:
 *   t: the new system time.
 */
void set_time(unsigned int t);

#endif // API_ROBOT2_H
