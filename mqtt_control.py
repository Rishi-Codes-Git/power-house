"""
Firebase Realtime Database Control for Transformer Relay

This module communicates with the ESP32 relay controller via Firebase RTDB.
Commands are sent to /relay_control/relay1/command for transformer control.
"""

import firebase_admin
from firebase_admin import credentials, db
import json
import os
from pathlib import Path

# Initialize Firebase
try:
    # Try to get existing app instance
    firebase_app = firebase_admin.get_app()
except ValueError:
    # Initialize new app if not already initialized
    creds_path = Path(__file__).parent / "firebase_credentials.json"

    if creds_path.exists():
        cred = credentials.Certificate(str(creds_path))
        firebase_app = firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://demand-forecasting-288b0-default-rtdb.asia-southeast1.firebasedatabase.app'
        })
    else:
        # Fallback: use environment variable or config
        print("Warning: firebase_credentials.json not found. Using environment config.")
        firebase_app = None

def send_command(cmd):
    """
    Send transformer control command via Firebase RTDB.

    Args:
        cmd (str): "ON" or "OFF" command

    Returns:
        bool: True if command was successfully published, False otherwise
    """
    try:
        if firebase_app is None:
            print("Error: Firebase not initialized")
            return False

        # Validate command
        cmd = str(cmd).strip().upper()
        if cmd not in {"ON", "OFF"}:
            print(f"Invalid command: {cmd}")
            return False

        # Convert command to boolean state
        # ON = true, OFF = false (matching relay logic)
        state = (cmd == "ON")

        # Publish to Firebase at /relay_control/relay1/command
        # This path is monitored by the ESP32 relay controller
        db.reference('/relay_control/relay1/command').set(state)

        print(f"Firebase command sent: relay1 = {state} ({cmd})")
        return True

    except Exception as e:
        print(f"Error sending Firebase command: {e}")
        return False


def send_transformer_command(cmd, reason=""):
    """
    Send transformer command with logging.
    Wrapper around send_command for compatibility.

    Args:
        cmd (str): "ON" or "OFF" command
        reason (str): Reason for the command (logged)

    Returns:
        bool: True if successful, False otherwise
    """
    if reason:
        print(f"Transformer command: {cmd} ({reason})")
    return send_command(cmd)


def get_relay_state(relay_num=1):
    """
    Read current relay state from Firebase.

    Args:
        relay_num (int): Relay number (1 or 2)

    Returns:
        bool or None: Current state, or None if error
    """
    try:
        if firebase_app is None:
            return None

        state = db.reference(f'/relay_control/relay{relay_num}/state').get().val()
        return state

    except Exception as e:
        print(f"Error reading relay state: {e}")
        return None


def check_device_online():
    """
    Check if ESP32 relay controller is online.

    Returns:
        bool: True if device is online, False otherwise
    """
    try:
        if firebase_app is None:
            return False

        online = db.reference('/relay_control/device_online').get().val()
        return bool(online)

    except Exception as e:
        print(f"Error checking device status: {e}")
        return False
