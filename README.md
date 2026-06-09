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
## Top Architecture

```mermaid
flowchart TB
    subgraph TOP["npu_top_NxN"]
        CTRL["sa_controller_NxN<br/>FSM: IDLE / CLEAR / COMPUTE / WAIT_DRAIN / DONE"]
        ARR["systolic_arr_NxN<br/>Parameterizable NxN PE Array"]

        CTRL -- clear --> ARR
        CTRL -- valid_in --> ARR
        CTRL -- done --> DONE["done"]
    end

    AIN["Matrix A input<br/>a_in[N][N]"] --> ARR
    BIN["Matrix B input<br/>b_in[N][N]"] --> ARR

    ARR --> COUT["Matrix C output<br/>c_out[N][N]"]

    subgraph ARR_DETAIL["Inside systolic_arr_NxN"]
        direction TB

        subgraph PEGRID["NxN Processing Element Grid"]
            direction TB

            R0["PE[0][0]  PE[0][1]  ...  PE[0][N-1]"]
            R1["PE[1][0]  PE[1][1]  ...  PE[1][N-1]"]
            RX["..."]
            RN["PE[N-1][0] PE[N-1][1] ... PE[N-1][N-1]"]
        end

        ASKEW["A skew / horizontal propagation"]
        BSKEW["B skew / vertical propagation"]
        VPROP["pe_valid wavefront propagation"]

        ASKEW --> PEGRID
        BSKEW --> PEGRID
        VPROP --> PEGRID
    end
