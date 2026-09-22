import time
import pigpio
import math
import sys
import serial
from server_Class import MatlabServer
from functions import MotorClass


def main(args):
    # Start server
    server = MatlabServer()
    server.establish_server()
    
    motor = MotorClass()
    
    stayConnected = True
    
    true_forces_list = []
    calibrated_forces_list = []
    countCalibrationHits = 0
    
    while stayConnected:
        dataFromML = server.listen_and_return()
        data = dataFromML[0]
        print(dataFromML)
        
        ''' --- View 1 --- '''
        if data == "DISCONNECT":
            stayConnected = False
        
        if data == "CW-1":
            motor.move_x_steps(1, "CW")
        
        if data == "CCW-1":
            motor.move_x_steps(1, "CCW")
            
        if data == "CCW-5":
            motor.move_x_steps(5, "CCW")
            
        if data == "CW-5":
            motor.move_x_steps(5, "CW")
            
        if data == "MOVE_180_DEG":
            motor.move_x_steps(800, "CCW")
        
        if data == "ENGAGE":
            motor.engage()
        
        if data == "DISENGAGE":
            motor.disengage()
            
        ''' --- View 2 --- '''
        if data == "SET_FORCE":
            desired_force = dataFromML[1]
            force = desired_force
            countCalibrationHits = 0
            
        if data == "SET_TOLERANCE":
            tolerance = dataFromML[1]
            
        if data == "DOUBLE_HIT_YES":
            motor.move_x_steps(1, "CW")
            
        if data == "TRUE_FORCE":
            true_force = dataFromML[1]
            true_forces_list.append(true_force)
            
        if data == "CALIBRATE_FORCE":
            countCalibrationHits += 1
            print(countCalibrationHits)
            if countCalibrationHits > 2:
                true_force_1 = true_forces_list[-2]
                true_force_2 = true_forces_list[-1]
                calibrated_force_1 = calibrated_forces_list[-2]
                calibrated_force_2 = calibrated_forces_list[-1]
                speed1 = motor._force_to_rpm(calibrated_force_1)
                speed2 = motor._force_to_rpm(calibrated_force_2)
                targetSpeed = motor.lin_interp(desired_force, speed1, speed2, true_force_1, true_force_2)
                print(targetSpeed, desired_force, speed1, speed2, true_force_1, true_force_2)
                motor.run_cycle(targetSpeed)
            else:
                calibrated_force = force * motor.percent_diff(desired_force, true_force)
                calibrated_forces_list.append(calibrated_force)
                force = calibrated_force
                motor.run_cycle(motor._force_to_rpm(force))
            
            
        if data == "RUN_TEST":
            print(f"run cycle at: force={force}, count=1, cycle_delay=1, degrees=180)")
            motor.run_cycle(motor._force_to_rpm(force))
        
        ''' --- View 3 --- '''
        if data == "SET_HITS":
            count_hits = dataFromML[1]
            
        if data == "SET_TIME":
            hit_delay = dataFromML[1]
            
        if data == "SET_NUM_TESTS":
            test_count = dataFromML[1]
            
        if data == "SET_INCREMENT":
            force_increment = dataFromML[1]
            
        if data == "START_TEST":
            
            test_cases_list = [force]
            if test_count > 1:
                for _ in range(int(test_count-1)):
                    test_cases_list.append(force+force_increment)

            for i, test_case in enumerate(test_cases_list):
                print(f"--- Starting Test {i+1} ---")
                motor.run_cycle(motor._force_to_rpm(test_case), count=count_hits, cycle_delay=hit_delay)
                time.sleep(2)
        
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
