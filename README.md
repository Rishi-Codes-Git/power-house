# power house
# ⚡ Smart Energy Optimization System
### Electricity Demand Forecasting & Dynamic Pricing using AI + IoT

---

## 🚀 Overview
This project presents an intelligent energy management system that combines **IoT, AI (LSTM), and smart switching** to optimize electricity usage.

The system predicts future demand, applies dynamic pricing, and automatically switches between **grid and solar energy** to reduce cost and prevent transformer overload.

---

## 🧠 Key Features
- Real-time energy monitoring  
- AI-based demand forecasting (LSTM)  
- Dynamic Time-of-Day (TOD) pricing  
- Automatic Grid ↔ Solar switching  
- Appliance-level energy tracking  
- Mobile app control & recommendations  

---

## ⚙️ System Architecture
Grid + Solar → Smart Meter (ESP32) → AI Model → Decision System → User App


---

## 🔌 Hardware Components
- ESP32 Microcontroller  
- Voltage Sensor  
- 6 Current Sensors (Appliance-level monitoring)  
- Dual Channel Relays (for switching)  
- Solar Panel + Battery  
- DC to AC Converter  

---

## POSTER

<img src="https://github.com/user-attachments/assets/9b5b0f47-ed11-43d7-91f9-694814d8eec6" width="60%"/>

---

## LOGIN

<img width="271" height="603" alt="login" src="https://github.com/user-attachments/assets/1c7e3416-627c-4b3a-b8d1-2fdc3349a786" />

---

## USER DETAILS

<img width="271" height="734" alt="details" src="https://github.com/user-attachments/assets/2e9e1940-ae2f-44ec-bbb5-8ff323065298" />

---

## SIMULATION

<img width="271" height="1080" alt="simulation" src="https://github.com/user-attachments/assets/8d941232-8cab-45e0-a591-27401ddbea0b" />

---

## DASHBOARD

<img src="https://github.com/user-attachments/assets/444b4f9f-be2b-4bac-a6e5-037fa154d225" width="300"/>

---

## 🔍 Working Principle

### 1. Power Input
- Grid power and solar energy are connected to the system  
- Solar energy is converted from DC to AC  

### 2. Smart Meter Processing
- Measures voltage and current  
- Calculates Power Factor (PF)  
- Tracks appliance-level usage  

### 3. AI Prediction
- LSTM model forecasts:
  - Future electricity demand  
  - Peak load periods  

### 4. Dynamic Pricing
- Pricing is adjusted based on predicted transformer load:
  - High load → High tariff  
  - Low load → Low tariff  

### 5. Intelligent Switching
- Default: Grid power  
- If PF < 0.9 → Switch to Solar  
- Controlled using relay system (~1 sec delay)  

### 6. User Interaction
- Mobile app provides:
  - Real-time monitoring  
  - Usage insights  
  - Smart suggestions  
  - Manual control  

---

## 🔄 Control Logic
IF PF ≥ 0.9 → Use Grid
IF PF < 0.9 → Switch to Solar


---

## 📊 AI Model (LSTM)
- Handles time-series energy data  
- Learns usage patterns  
- Predicts demand trends  
- Enables proactive decision-making  

---

## 📱 User Application Features
- Real-time energy dashboard  
- Transformer load insights  
- Dynamic pricing display  
- Appliance usage recommendations  
- Remote switching control  

---

## 🚀 Innovation

> **Closed-loop intelligent system**
Monitor → Predict → Decide → Control → Optimize

- Reduces transformer stress  
- Improves energy efficiency  
- Encourages demand-side management  

---

## 🎯 Use Cases
- Smart homes  
- Smart grids  
- Energy-efficient buildings  
- Industrial load management  
 

---

## 🏁 Conclusion
This project demonstrates how **AI + IoT + renewable energy integration** can transform traditional energy systems into intelligent, adaptive, and efficient solutions.

---







