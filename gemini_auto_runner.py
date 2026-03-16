import os
import sys
import time
import subprocess
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("AutoRunner")

def run_task(command):
    logger.info(f"Starting task: {' '.join(command)}")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    
    output_log = []
    
    for line in iter(process.stdout.readline, ''):
        print(line, end='')
        output_log.append(line.lower())
    
    process.stdout.close()
    return_code = process.wait()
    
    return return_code, "".join(output_log)

def main():
    if len(sys.argv) < 2:
        print("Usage: python gemini_auto_runner.py <command_to_run> [args...]")
        print("Example: python gemini_auto_runner.py python my_script.py")
        sys.exit(1)
        
    command = sys.argv[1:]
    
    # Overload strings typical for Gemini and other API errors
    overload_triggers = [
        "429", "too many requests", "resource exhausted",
        "503", "service unavailable", "overloaded",
        "deadline exceeded", "quota", "gemini is overloaded"
    ]
    
    wait_time_minutes = 5
    wait_time_seconds = wait_time_minutes * 60
    
    consecutive_restarts = 0
    max_restarts = 50
    
    while consecutive_restarts < max_restarts:
        logger.info(f"--- ATTEMPT {consecutive_restarts + 1} ---")
        code, output = run_task(command)
        
        if code == 0:
            logger.info("Task completed successfully!")
            break
            
        logger.warning(f"Task exited with code {code}.")
        
        # Check if the error is due to overload
        is_overloaded = False
        for trigger in overload_triggers:
            if trigger in output:
                is_overloaded = True
                logger.error(f"Detected overload/quota error: '{trigger}'")
                break
                
        if is_overloaded:
            logger.info(f"Server overloaded. Sleeping for {wait_time_minutes} minutes before restarting...")
            time.sleep(wait_time_seconds)
            consecutive_restarts += 1
            logger.info("Waking up and retrying...")
        else:
            logger.error("Task failed due to a non-overload error. Exiting wrapper.")
            sys.exit(code)

    if consecutive_restarts >= max_restarts:
        logger.critical("Maximum number of retries reached. Exiting.")
        sys.exit(1)

if __name__ == "__main__":
    main()
