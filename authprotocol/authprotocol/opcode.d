module authprotocol.opcode;

enum Opcode
{
    AUTH_LOGON_CHALLENGE                         = 0x00,
    AUTH_LOGON_PROOF                             = 0x01,
    AUTH_RECONNECT_CHALLENGE                     = 0x02,
    AUTH_RECONNECT_PROOF                         = 0x03,
    REALM_LIST                                   = 0x10,
    XFER_INITIATE                                = 0x30,
    XFER_DATA                                    = 0x31,
    XFER_ACCEPT                                  = 0x32,
    XFER_RESUME                                  = 0x33,
    XFER_CANCEL                                  = 0x34
}