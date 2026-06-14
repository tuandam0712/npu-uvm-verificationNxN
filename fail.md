# PE hold SVA false failure

## Issue
PE hold assertion reported `acc_reg changed while clear=0 valid=0`.

## Root cause
The original assertion checked hold behavior too aggressively across cycle boundaries. In the systolic array, valid/clear can change across wavefront cycles, so the assertion produced false failures.

## Fix
Updated the hold assertion to check only when the PE remains invalid across consecutive cycles.

## Result
N=8 UVM regression passed: 106/106 tests, 0 UVM errors, 100% functional coverage.