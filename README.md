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
```mermaid
flowchart LR
    A["Matrix A<br/>a_in[N][N]"]
    B["Matrix B<br/>b_in[N][N]"]
    C["Matrix C<br/>c_out[N][N]"]

    subgraph TOP["npu_top_NxN"]
        direction TB

        CTRL["sa_controller_NxN<br/><br/>FSM States:<br/>IDLE<br/>CLEAR<br/>COMPUTE<br/>WAIT_DRAIN<br/>DONE"]

        subgraph ARR["systolic_arr_NxN"]
            direction TB

            subgraph GRID["NxN PE Grid"]
                direction TB
                R0["PE  PE  PE  PE<br/>PE  PE  PE  PE<br/>PE  PE  PE  PE<br/>PE  PE  PE  PE"]
            end

            ASKEW["A horizontal propagation →"]
            BSKEW["B vertical propagation ↓"]
            VLD["valid wavefront"]
        end

        CTRL -->|"clear / valid_in"| ARR
        ARR -->|"done feedback"| CTRL
    end

    A --> ARR
    B --> ARR
    ARR --> C

    ASKEW --> GRID
    BSKEW --> GRID
    VLD --> GRID
```