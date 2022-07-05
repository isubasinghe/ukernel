# Interrupts in RISC-V

## Exception 
The triggering instruction cannot be completed. 
There are two possibilities for the return address, the instructions 
itself or the following one. 

### Example 
The address of the data during a load instruction is not aligned so this will cause a misaligned exception. 

## Interrupts
There is onyl one reasonable solution for the return address, the current first instruction 
that has not yet completed. 

### Example 
Timer interrupts

## Trap 
Synchronous transfer of control to a trap handler

### Example 
User mode making a call to the kernel to perform some duty.


## Local and Global Interrupts 

### Local Interrupt Controllers 
Both offer `mtime` and `mtimecmp` registers. Use `msip` for software interrupts.

#### Core Local Interrupter (CLINT)
The Core Local Interrupt (CLINT) offers a compact design with a fixed priority scheme with premption support only 
from higher privilege levels only. 
Simple CPU interrupter for software and timer interrupts. 

#### Core Local Interrupt Controller (CLIC)
A fully featured local interrupt controller that support programmable interrupt levels and priorities. 
Also supports nested interrupts (premption) based on interrupt level and priority config. 

### Global Interrupt Controllers 
The Global Interrupt Controller is termed the Platform Local Interrupt Controller. 
Provides flexibility for dispatching interrupts system wide or core directed. 



