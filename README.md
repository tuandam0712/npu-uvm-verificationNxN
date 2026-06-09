NxN Systolic Array NPU Verification using UVM

Overview

This project implements and verifies a parameterizable NxN Neural Processing Unit(NPU) based on a systolic array architecture for signed INT8 matrix multiplication.

The RTL design is developed inn SystemVerilog and supports configurable array dimesions through parameterization.

A complete UVM verification environment is built to validate functionality, timing behavior, and data propagation across the systolic array.

Verification techniques used in this project include:
- Directed testing
- Constrained random testing 
- Golden model scb checking 
- SystemVerilog Assertions (SVA)
- Functional coverage
- Regression testing

Current regression status:
- 102/102 tests passed
- 0 UVM err
- 0 UVM fatals
- 100% in data coverage
- 100% matrix pattern coverage
- 100% out data coverage

Top architecture
![Top Architecture](images/dir1.png)

The design consists of 2 major RTL blocks:

Controller FSM
The controller manages the computation flow using five states:
- IDLE
- CLEAR
- COMPUTE
- WAIT_DRAIN
- DONE

NxN Systolic Array
- The systolic array is composed of NxN Processing Elements (PEs)
- Input matrix A propagates horizontally across the array
- input matrix B propagates verically across the array
- A wavefront based valid signal propagates together with the operands to guarantee timing alignment

Processing Element (PE)

Each PE is intetionally designed as a lightweight MAC cell.

Inputs:
- a_in
- b_in
- valid
- clear

Output:
- accmulated result

Operation priority:
- Reset
- Clear
- MAC operation
- Hold accmulated value

Operand forwarding is not implemented inside the PE

Data propagation and skew management are handled at the systolic array level

RTL Structure

rtl/
|-- pe.sv
|
|-- systolic_arr_NxN.sv
|
|-- sa_controller_NxN.sv
|
|-- npu_top_NxN.sv

pe.sv

Implements signed Multiply Accmulate (MAC)functionality.

systolic_arr_NxN.sv

Implements operand skewing, valid propagation, and PE interconnection.

sa_controller_NxN.sv

Controls computation sequencing and latency management.

npu_top_NxN.sv

Top level integration of controller and systolic array.