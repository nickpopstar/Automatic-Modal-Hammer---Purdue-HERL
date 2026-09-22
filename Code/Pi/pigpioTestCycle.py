import sys
import pigpio
import time


# --- Configuration ---
PULSE_PIN = 18 
DIR_PIN = 27
ENABLE_PIN = 22

# --- NEMA 34 Tuning ---
# WARNING: Keep TARGET_RPM very low for this specific test
STEPS_PER_REV = 200
TARGET_DEGREES = 180
REPEAT_COUNT = 5 # remove var
CYCLE_DELAY_SEC = 1 # remove var

START_RPM = 1
TARGET_RPM = 15
RPM_INCREMENT = 1
STEPS_PER_RAMP_LEVEL = 20

# make function that takes desired force and outputs RPM target speed

# --- Setup ---
pi = pigpio.pi()
if not pi.connected:
    sys.exit(1)

pi.set_mode(PULSE_PIN, pigpio.OUTPUT)
pi.set_mode(DIR_PIN, pigpio.OUTPUT)
pi.set_mode(ENABLE_PIN, pigpio.OUTPUT)

# --- 1. Math Helpers ---
def rpm_to_delay_us(rpm):
    if rpm <= 0: return 2000
    return int(60_000_000 / (STEPS_PER_REV * rpm))

# --- 2. Generate Ramp Waves ---
print(f"Generating profile for {TARGET_RPM} RPM...")
rpm_values = list(range(START_RPM, TARGET_RPM, RPM_INCREMENT))
if rpm_values[-1] != TARGET_RPM: rpm_values.append(TARGET_RPM)

pi.wave_clear()
ramp_wave_ids = []

for r in rpm_values:
    delay = rpm_to_delay_us(r)
    single_step = [
        pigpio.pulse(1 << PULSE_PIN, 0, delay // 2), 
        pigpio.pulse(0, 1 << PULSE_PIN, delay // 2)
    ]
    pi.wave_add_generic(single_step * STEPS_PER_RAMP_LEVEL)
    ramp_wave_ids.append(pi.wave_create())

# Steady State Wave
steady_pulse = [
    pigpio.pulse(1 << PULSE_PIN, 0, rpm_to_delay_us(TARGET_RPM) // 2), 
    pigpio.pulse(0, 1 << PULSE_PIN, rpm_to_delay_us(TARGET_RPM) // 2)
]
pi.wave_add_generic(steady_pulse)
steady_wave_id = pi.wave_create()

# Direction Waves (50 us pause delay)
pi.wave_add_generic([pigpio.pulse(1 << DIR_PIN, 0, 50)]) 
dir_1_wave = pi.wave_create()
pi.wave_add_generic([pigpio.pulse(0, 1 << DIR_PIN, 50)])
dir_0_wave = pi.wave_create()

# Delay between cycles waves (1 sec = 10^6 us)
pi.wave_add_generic([pigpio.pulse(0,0,CYCLE_DELAY_SEC * 10**6)])
delay_wave_id = pi.wave_create()

# --- 3. Split-Logic Chain Builders ---

def get_forward_chain(degrees):
    """Ramp Up -> Steady -> STOP (No Decel)"""
    total_steps = int((degrees / 360.0) * STEPS_PER_REV)
    ramp_steps = len(ramp_wave_ids) * STEPS_PER_RAMP_LEVEL
    
    chain = []
    
    # 1. Ramp Up
    chain += ramp_wave_ids
    
    # 2. Steady State (Remaining distance)
    steady_steps = total_steps - ramp_steps
    if steady_steps > 0:
        chain += [255, 0, steady_wave_id, 255, 1, steady_steps & 255, steady_steps >> 8]
        
    return chain

def get_backward_chain(degrees):
    """START (No Accel) -> Steady -> Ramp Down"""
    total_steps = int((degrees / 360.0) * STEPS_PER_REV)
    ramp_steps = len(ramp_wave_ids) * STEPS_PER_RAMP_LEVEL
    
    chain = []
    
    # 1. Steady State (Distance minus the space needed to stop)
    steady_steps = total_steps - ramp_steps
    if steady_steps > 0:
        chain += [255, 0, steady_wave_id, 255, 1, steady_steps & 255, steady_steps >> 8]
        
    # 2. Ramp Down (Reverse)
    chain += ramp_wave_ids[::-1]
    
    return chain

# --- 4. Create Single Cycle Wave Chain ---
single_cycle_chain = []

# Forward Move
single_cycle_chain += [dir_1_wave]
single_cycle_chain += get_forward_chain(TARGET_DEGREES)

# Backward Move
single_cycle_chain += [dir_0_wave]
single_cycle_chain += get_backward_chain(TARGET_DEGREES)

# Delay between cycle
single_cycle_chain += [delay_wave_id]

print("Executing Profile...")
pi.wave_chain(single_cycle_chain * REPEAT_COUNT)

while pi.wave_tx_busy():
    time.sleep(0.1)

print("Done.")
pi.wave_clear()
pi.stop()
