
`ifndef USBFS_TYPES
`define USBFS_TYPES

typedef enum logic [3:0] {
    PID_OUT   = 'h1,
    PID_IN    = 'h9,
    PID_SOF   = 'h5,
    PID_SETUP = 'hd,

    PID_DATA0 = 'h3,
    PID_DATA1 = 'hb,
    PID_DATA2 = 'h7,
    PID_MDATA = 'hf,

    PID_ACK   = 'h2,
    PID_NAK   = 'ha,
    PID_STALL = 'he,
    PID_NYET  = 'h6,

    PID_ERR   = 'hc,
    PID_SPLIT = 'h8,
    PID_PING  = 'h4,

    PID_INVALID = 'h0
} Pid;

typedef enum logic[1:0] {
    HANDSHAKE_NONE,
    HANDSHAKE_ACK,
    HANDSHAKE_NAK,
    HANDSHAKE_STALL
} Handshake;

`endif // USBFS_TYPES
