# Vivado Synthesis & Implementation Report

This report provides the detailed hardware metrics, timing data, resource utilization, and power analysis for the Parameterized streaming FFT core implemented on Xilinx silicon.

## 1. Target Device Profile
* **Product Family:** Zynq-7000
* **Device Part:** xc7z010clg400-1


## 2. Design Timing Summary
The design fully meets all user-specified timing constraints with comfortable safety margins and zero failing endpoints.

!(timing.jpg)


## 3. Hardware Resource Utilization

### Slice Logic Metrics
!(slice.jpg)

### Elaborated RTL Component Info
!(rtl_component.jpg)



## 4. Power & Thermal Analysis
Power metrics extracted from the post-implementation netlist activity.
!(power_thermal.jpg)



### Sub-System Utilisation Breakdown
!(utilisation.jpg)
)
