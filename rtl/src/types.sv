
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

typedef enum logic {
    REQ_TYPE_DIR_HTD = 0,
    REQ_TYPE_DIR_DTH = 1
} SetupRequestTypeDTD;

typedef enum logic[1:0] {
    REQ_TYPE_TYPE_STANDARD = 0,
    REQ_TYPE_TYPE_CLASS = 1,
    REQ_TYPE_TYPE_VENDOR = 2,
    REQ_TYPE_TYPE_RESERVED = 3
} SetupRequestTypeType;

typedef enum logic[4:0] {
    REQ_TYPE_RECIPIENT_DEVICE = 0,
    REQ_TYPE_RECIPIENT_INTERFACE = 1,
    REQ_TYPE_RECIPIENT_ENDPOINT = 2,
    REQ_TYPE_RECIPIENT_OTHER = 3,
    REQ_TYPE_RECIPIENT_RESERVED = 4
} SetupRequestTypeRecipient;

typedef enum logic[7:0] {
    REQ_GET_STATUS = 0,
    REQ_CLEAR_FEATURE = 1,

    REQ_SET_FEATURE = 3,

    REQ_SET_ADDRESS = 5,
    REQ_GET_DESCRIPTOR = 6,
    REQ_SET_DESCRIPTOR = 7,
    REQ_GET_CONFIGURATION = 8,
    REQ_SET_CONFIGURATION = 9,
    REQ_GET_INTERFACE = 10,
    REQ_SET_INTERFACE = 11,
    REQ_SYNCH_FRAME = 12
} SetupRequest;

`endif // USBFS_TYPES
