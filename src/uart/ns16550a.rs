use tock_registers::registers::{ReadOnly, ReadWrite, WriteOnly};
use tock_registers::register_bitfields;
use tock_registers::register_structs;
use tock_registers::interfaces::*;
use crate::cells::static_ref::StaticRef;

const UART_BASE: StaticRef<Registers> = 
    unsafe { StaticRef::new(0x1000_0000 as *const Registers) };

register_structs! {
    Registers {
        // Control register: read-write
        // The 'Control' parameter constrains this register to only use fields from
        // a certain group (defined below in the bitfields section).
        (0 => iir: WriteOnly<u8, IIR::Register>),
        (1 => ier: ReadWrite<u8, IER::Register>),
        (2 => fcr: WriteOnly<u8, FCR::Register>),
        (3 => lcr: ReadWrite<u8, LCR::Register>),


        (8 => @END),
        // Status register: read-only
    }
}


register_bitfields![u8, 
    IER [
        ERBFI OFFSET(0) NUMBITS(1),
        ETBEI OFFSET(1) NUMBITS(1),
        ELSI OFFSET(2) NUMBITS(1),
        EDSSI OFFSET(3) NUMBITS(1)
    ], 
    IIR [
        PENDING OFFSET(0) NUMBITS(1),
        ID0 OFFSET(1) NUMBITS(1),
        ID1 OFFSET(2) NUMBITS(1),
        ID2 OFFSET(3) NUMBITS(1)
    ], 
    FCR [
        FIFO_ENABLE OFFSET(0) NUMBITS(1), 
        RCVR_FIFO_RESET OFFSET(1) NUMBITS(1), 
        XMIT_FIFO_RESET OFFSET(2) NUMBITS(1), 
        DMA_MODE_SELECT OFFSET(3) NUMBITS(1),
        RCVR_TRIGGER_LSB OFFSET(6) NUMBITS(1), 
        RCVR_TRIGGER_MSB OFFSET(7) NUMBITS(1)
    ], 
    LCR [
        WLS0 OFFSET(0) NUMBITS(1), 
        WLS1 OFFSET(1) NUMBITS(1), 
        NUM_STB OFFSET(2) NUMBITS(1), 
        PARITY_ENABLE OFFSET(3) NUMBITS(1),
        EVEN_PARITY_SELECT OFFSET(4) NUMBITS(1), 
        STICK_PARITY OFFSET(5) NUMBITS(1), 
        SET_BREAK OFFSET(6) NUMBITS(1), 
        DIV_LATCH_ACCESS OFFSET(7) NUMBITS(1)
    ], 
    MCR [
        DATA_TERM_READ OFFSET(0) NUMBITS(1), 
        REQUEST_TO_SEND OFFSET(1) NUMBITS(1), 
        OUT1 OFFSET(2) NUMBITS(1), 
        OUT2 OFFSET(3) NUMBITS(1)
    ],
    LSR [
        DATA_READY OFFSET(0) NUMBITS(1), 
        OVERRUN_ERROR OFFSET(1) NUMBITS(1), 
        PARITY_ERROR OFFSET(2) NUMBITS(1),
        FRAMING_ERROR OFFSET(3) NUMBITS(1), 
        BREAK_INTERRUPT OFFSET(4) NUMBITS(1), 
        TRANSMITTER_HOLDING_REGISTER OFFSET(5) NUMBITS(1), 
        TRANSMITTER_EMPTY OFFSET(6) NUMBITS(1), 
        ERROR_RCVR OFFSET(7) NUMBITS(1)
    ], 
    MSR [
        DELTA_CLEAR_TO_SEND OFFSET(0) NUMBITS(1), 
        DELTA_DATA_SET_READ OFFSET(1) NUMBITS(1), 
        TRAILING_EDGE_RING_INDICATOR OFFSET(2) NUMBITS(1),
        DELTA_DATA_CARRIER_DETECT OFFSET(3) NUMBITS(1), 
        CLEAR_TO_SEND OFFSET(4) NUMBITS(1), 
        DATA_SET_READY OFFSET(5) NUMBITS(1), 
        RING_INDICATOR OFFSET(6) NUMBITS(1), 
        DATA_CARRIER_DETECT OFFSET(7) NUMBITS(1)
    ]
];


pub fn init() {
    // enable 8 bits 
    UART_BASE.lcr.write(LCR::WLS0::SET + LCR::WLS1::SET);
    // enable FIFO (obvious isn't it?)
    UART_BASE.fcr.write(FCR::FIFO_ENABLE::SET);
    // enable receive buffer interrupts
    UART_BASE.ier.write(IER::ERBFI::SET);

    // time to set the rate
    let divisor: u16 = 592;
    let divisor_least = divisor & 0xff;
    let divisor_most = divisor >> 8;

}
