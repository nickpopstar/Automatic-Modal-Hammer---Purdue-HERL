import pigpio
import time
import subprocess
import os
import signal
import sys

class MotorClass:
    def __init__(self, dir_pin=27, pulse_pin=18, ena_pin=22):
        # Setup
        self.pi = pigpio.pi()
        if not self.pi.connected:
            raise IOError("Could not connect to pigpio daemon. Run 'sudo pigpiod'.")
        
        self.DIR_PIN = dir_pin
        self.PULSE_PIN = pulse_pin
        self.ENA_PIN = ena_pin
        
        # Fixed: Added 'self.' to access the variables defined above
        self.pi.set_mode(self.PULSE_PIN, pigpio.OUTPUT)
        self.pi.set_mode(self.DIR_PIN, pigpio.OUTPUT)
        self.pi.set_mode(self.ENA_PIN, pigpio.OUTPUT)

        # Pulse settings (Adjust based on NEMA 34 driver requirements)
        self.PULSE_WIDTH = 0.000005  # 5 microseconds
        self.DELAY = 0.02           # Delay between steps
        
        # Motor Config
        self.STEPS_PER_REV = 1600
        self.TARGET_DEGREES = 180
        # self.REPEAT_COUNT = None 
        # self.CYCLE_DELAY_SEC = 1.0 # Set a default to prevent crash
        
        self.START_RPM = 5
        self.RPM_INCREMENT = 1
        self.STEPS_PER_RAMP_LEVEL = 20
        
        # Waveform setup
        self._ramp_wave_ids = []
        self._steady_wave_id = None
        self._dir_1_wave = None # CCW
        self._dir_0_wave = None # CW
        self._delay_wave_id = None
        
        # Process handle for external file
        self.test_process = None

    def engage(self):
        self.pi.write(self.ENA_PIN, 0)
        print("Motor Engaged.")

    def disengage(self):
        self.pi.write(self.ENA_PIN, 1)
        print("Motor Disengaged.")

    def move_x_steps(self, steps, direction):
        # Set Direction (1 for CCW, 0 for CW)
        level = 1 if direction.upper() == 'CCW' else 0
        self.pi.write(self.DIR_PIN, level)
        
        # Setup time for direction pin
        time.sleep(0.0000075) #7.5us

        # Pulse the Step Pin
        for _ in range(steps):
            self.pi.write(self.PULSE_PIN, 1)
            time.sleep(self.PULSE_WIDTH)
            self.pi.write(self.PULSE_PIN, 0)
            time.sleep(self.DELAY*0.25)
        
        # Debounce/wait
        time.sleep(self.DELAY)
        print(f"Moved {steps} steps {direction}")
        
    def run_cycle(self, target_rpm, count=1, cycle_delay=1, degrees=180):
        self.engage() # engage motor
        self.pi.wave_clear() # clear old waves
        #target_rpm = self._force_to_rpm(force) # calc rpm
        
        print(f'''
        Force:  --> Target RPM: {target_rpm}
        Delay: {self._rpm_to_delay_us(target_rpm)}
        Count: {count}
        Time between cycles: {cycle_delay}
        Degrees of movement: {degrees}
        ''')
        
        full_chain = []
        
        self._generate_steady_waves(target_rpm)
        self._generate_directional_waves()
        self._generate_delay_waves(cycle_delay)
        
        if target_rpm > 7:
            self._generate_ramp_waves(target_rpm)
            full_chain.extend([self._dir_0_wave])
            full_chain.extend(self._build_forward_chain(degrees))
            full_chain.extend([self._dir_1_wave])
            full_chain.extend(self._build_backward_chain(degrees))
            full_chain.extend([self._delay_wave_id])
        else:
            full_chain.extend([self._dir_0_wave])
            full_chain.extend(self._build_steady_chain(degrees))
            full_chain.extend([self._dir_1_wave])
            full_chain.extend(self._build_steady_chain(degrees))
            full_chain.extend([self._delay_wave_id])
        
        for i in range(int(count)):
            self.pi.wave_chain(full_chain)
            while self.pi.wave_tx_busy():
                time.sleep(0.01)
        print("Test Complete.")
        
    def cleanup(self):
        self.pi.wave_clear()
        self.pi.stop()
    
    def _rpm_to_delay_us(self, rpm):
        if rpm <= 0: return 2000
        return int(60_000_000 / (self.STEPS_PER_REV * rpm))
        
    def percent_diff(self, desired_force, true_force):
        percent_diff = ((desired_force-true_force)/desired_force) + 1
        return percent_diff
        
    def lin_interp(self, desiredForce, speed1, speed2, force1, force2):
        m = (force2-force1)/(speed2-speed1)
        return speed1 + (desiredForce-force1)*(1/m) # returns target speed
        
    def _force_to_rpm(self, desired_force):
        return (desired_force+160.2) / 40.056
        
    def _generate_ramp_waves(self, target_rpm):
        """
        Generates all necessary PIGPIO waves for the specific target RPM.
        Stores IDs in self._ramp_wave_ids, self._steady_wave_id, etc.
        """
        # 1. Generate Ramp Waves (Acceleration steps)
        rpm_values = list(range(self.START_RPM, int(target_rpm-1), self.RPM_INCREMENT))
        if rpm_values[-1] != target_rpm: 
            rpm_values.append(target_rpm)

        self._ramp_wave_ids = []
        for r in rpm_values:
            delay = self._rpm_to_delay_us(r)
            # Create pulse: On for half delay, Off for half delay
            single_step = [
                pigpio.pulse(1 << self.PULSE_PIN, 0, delay // 2), 
                pigpio.pulse(0, 1 << self.PULSE_PIN, delay // 2)
            ]
            # Add generic wave for the ramp level count
            self.pi.wave_add_generic(single_step * self.STEPS_PER_RAMP_LEVEL)
            self._ramp_wave_ids.append(self.pi.wave_create())

    def _generate_steady_waves(self, target_rpm):
        # 2. Generate Steady State Wave
        steady_delay = self._rpm_to_delay_us(target_rpm)
        steady_pulse = [
            pigpio.pulse(1 << self.PULSE_PIN, 0, steady_delay // 2), 
            pigpio.pulse(0, 1 << self.PULSE_PIN, steady_delay // 2)
        ]
        self.pi.wave_add_generic(steady_pulse)
        self._steady_wave_id = self.pi.wave_create()
        
    def _generate_directional_waves(self):
        # 3. Generate Direction Waves (50us hold)
        self.pi.wave_add_generic([pigpio.pulse(1 << self.DIR_PIN, 0, 50)]) 
        self._dir_1_wave = self.pi.wave_create() # CCW (forward)
        
        self.pi.wave_add_generic([pigpio.pulse(0, 1 << self.DIR_PIN, 50)])
        self._dir_0_wave = self.pi.wave_create() # CW (backward)
        
    def _generate_delay_waves(self, cycle_delay):
        # 4. Generate Cycle Delay Wave
        self.pi.wave_add_generic([pigpio.pulse(0, 0, int(cycle_delay * 1_000_000))])
        self._delay_wave_id = self.pi.wave_create()

    def _build_forward_chain(self, degrees):
        """Internal logic: Ramp Up -> Steady -> Hard Stop"""
        total_steps = int((degrees / 360.0) * self.STEPS_PER_REV)
        ramp_steps = len(self._ramp_wave_ids) * self.STEPS_PER_RAMP_LEVEL
        
        chain = []
        chain.extend(self._ramp_wave_ids) # Ramp Up
        
        steady_steps = total_steps - ramp_steps
        if steady_steps > 0:
            # pigpio loop structure: 255, 0 (start), wave_id, 255, 1, loops_low, loops_high
            chain.extend([255, 0, self._steady_wave_id, 255, 1, steady_steps & 255, steady_steps >> 8])
            
        return chain

    def _build_backward_chain(self, degrees):
        """Internal logic: Hard Start -> Steady -> Ramp Down"""
        total_steps = int((degrees / 360.0) * self.STEPS_PER_REV)
        ramp_steps = len(self._ramp_wave_ids) * self.STEPS_PER_RAMP_LEVEL
        
        chain = []
        steady_steps = total_steps - ramp_steps
        if steady_steps > 0:
            chain.extend([255, 0, self._steady_wave_id, 255, 1, steady_steps & 255, steady_steps >> 8])
            
        chain.extend(self._ramp_wave_ids[::-1]) # Ramp Down (Reverse)
        return chain
        
    def _build_steady_chain(self, degrees):
        """Internal logic: Forward Steady -> Backward Steady"""
        total_steps = int((degrees / 360.0) * self.STEPS_PER_REV)
        chain = []
        chain.extend([255, 0, self._steady_wave_id, 255, 1, total_steps & 255, total_steps >> 8])
        return chain
            
        
