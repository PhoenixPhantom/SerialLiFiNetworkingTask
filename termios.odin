package main

//import "core:sys/linux"

IFlag :: enum {
	IGNBRK  = 0, // Ignore break condition
	BRKINT  = 1, // Signal interrupt on break
	IGNPAR  = 2, // Ignore characters with parity errors
	PARMRK  = 3, // Mark parity and framing errors
	INPCK   = 4, // Enable input parity check
	ISTRIP  = 5, // Strip 8th bit off characters
	INLCR   = 6, // Map NL to CR on input
	IGNCR   = 7, // Ignore CR
	ICRNL   = 8, // Map CR to NL on input
	IXANY   = 9, // Any character will restart after stop
	IULC    = 10,
	IXON    = 11,
	IXOFF   = 13,
	IMAXBEL = 14,
	IUTF8   = 15,
}
IFlags :: distinct bit_set[IFlag;u32]

OFlag :: enum {
	OPOST  = 0,
	OLCUC  = 1,
	ONLCR  = 2,
	OCRNL  = 3,
	ONOCR  = 4,
	ONLRET = 5,
	OFILL  = 6,
	OFDEL  = 7,
	NLDLY  = 8,
	NL1    = NLDLY,
	CR1    = 9,
	CR2    = 10,
	TAB1   = 11,
	BSDLY  = 13,
	BS1    = BSDLY,
	VTDLY  = 14,
	VT1    = VTDLY,
	FFDLY  = 15,
	FF1    = FFDLY,
}
OFlags :: distinct bit_set[OFlag;u32]

NL0 :: OFlag(0)
CR0 :: NL0
TAB0 :: NL0
BS0 :: NL0
VT0 :: NL0
FF0 :: NL0

CRDLY :: OFlag(0x0600)
CR3 :: CRDLY
TABDLY :: OFlag(0x01800)
TAB3 :: TABDLY
XTABS :: TABDLY

BRates_Base :: enum u32 {
	B0     = 0x0,
	B50    = 0x1,
	B75    = 0x2,
	B110   = 0x3,
	B134   = 0x4,
	B150   = 0x5,
	B200   = 0x6,
	B300   = 0x7,
	B600   = 0x8,
	B1200  = 0x9,
	B1800  = 0xa,
	B2400  = 0xb,
	B4800  = 0xc,
	B9600  = 0xd,
	B19200 = 0xe,
	B38400 = 0xf,
	EXTA   = B19200,
	EXTB   = B38400,
}

BRates_Extended :: enum u32 {
	B57600   = 0x1,
	B115200  = 0x2,
	B230400  = 0x3,
	B460800  = 0x4,
	B500000  = 0x5,
	B576000  = 0x6,
	B921000  = 0x7,
	B1000000 = 0x8,
	B1152000 = 0x9,
	B1500000 = 0xa,
	B2000000 = 0xb,
	B2500000 = 0xc,
	B3000000 = 0xd,
	B3500000 = 0xe,
	B4000000 = 0xf,
}

Char_Size :: enum u8 {
	Size5    = 0,
	Size6    = 0b1,
	Size7    = 0b10,
	Size8    = 0b11,
	CharSize = Size8,
}

CIBaud :: enum u16 {
	Disable = 0x0,
	Enable  = 0x100f,
}

CFlags :: bit_field u32 {
	baudrate:          u32       | 4, // interpret as BRates_Base/_Extended depending on extended_baudrate
	char_size:         Char_Size | 2,
	c_stopb:           bool      | 1,
	c_read:            bool      | 1,
	parity_enable:     bool      | 1, // PARENB
	parity_odd:        bool      | 1,
	hupcl:             bool      | 1,
	c_local:           bool      | 1,
	extended_baudrate: bool      | 1, // BOTHER or CBAUDEX
	c_ibaud:           CIBaud    | 16,
	addrb:             bool      | 1, // bit 29
	cms_parity:        bool      | 1, // bit 30
	c_rtscts:          bool      | 1, // bit 31
}

// CFlag_Values :: enum u32 {
// 	B0       = 0,
// 	B50      = 1,
// 	B75      = 2,
// 	B110     = 3,
// 	B134     = 4,
// 	B150     = 5,
// 	B200     = 6,
// 	B300     = 7,
// 	B600     = 8,
// 	B1200    = 9,
// 	B1800    = 10,
// 	B2400    = 11,
// 	B4800    = 12,
// 	B9600    = 13,
// 	B19200   = 14,
// 	B38400   = 15,
// 	B57600   = 0x01001,
// 	B115200  = 0x01002,
// 	B230400  = 0x01003,
// 	B460800  = 0x01004,
// 	B500000  = 0x01005,
// 	B576000  = 0x01006,
// 	B921000  = 0x01007,
// 	B1000000 = 0x01008,
// 	B1152000 = 0x01009,
// 	B1500000 = 0x0100a,
// 	B2000000 = 0x0100b,
// 	B2500000 = 0x0100c,
// 	B3000000 = 0x0100d,
// 	B3500000 = 0x0100e,
// 	B4000000 = 0x0100f,
// 	EXTA     = B19200,
// 	EXTB     = B38400,
// 	//BOTHER = 0o00010000,
// 	//
// 	CBAUD    = 0x0000100F,
// 	CSIZE    = 0x030,
// 	CS5      = B0,
// 	CS6      = 0x010,
// 	CS7      = 0x020,
// 	CS8      = 0x030,
// 	CSTOPB   = 0x040,
// 	CREAD    = 0x080,
// 	PARENB   = 0x0100,
// 	PARODD   = 0x0200,
// 	HUPCL    = 0x0400,
// 	CLOCAL   = 0x0800,
// 	CBAUDEX  = 0x01000,
// 	BOTHER   = 0x00001000,
// 	CIBAUD   = 0x100f0000,
// 	ADDRB    = 0x20000000,
// 	CMSPAR   = 0x40000000,
// 	CRTSCTS  = 0x80000000,
// }


LFlag :: enum {
	ISIG    = 0,
	ICANON  = 1,
	XCASE   = 2,
	ECHO    = 3,
	ECHOE   = 4,
	ECHOK   = 5,
	ECHONL  = 6,
	NOFLSH  = 7,
	TOSTOP  = 8,
	ECHOCTL = 9,
	ECHOPRT = 10,
	ECHOKE  = 11,
	FLUSHO  = 12,
	PENDIN  = 13,
	IEXTEN  = 14,
	EXTPROC = 15,
}
LFlags :: distinct bit_set[LFlag;u32]


NCCS :: 19
Control_Characters :: enum u8 {
	VINTR    = 0,
	VQUIT    = 1,
	VERASE   = 2,
	VKILL    = 3,
	VEOF     = 4,
	VTIME    = 5,
	VMIN     = 6,
	VSWTC    = 7,
	VSTART   = 8,
	VSTOP    = 9,
	VSUSP    = 10,
	VEOL     = 11,
	VREPRINT = 12,
	VDISCARD = 13,
	VWERASE  = 14,
	VLNEXT   = 15,
	VEOL2    = 16,
	PADDING  = 17,
	PADDING2 = 18,
}
#assert(len(Control_Characters) == NCCS)

TC_Attr :: enum {
	TCSANOW   = 0,
	TCSADRAIN = 1,
	TCSAFLUSH = 2,
}

Termios2 :: struct #packed {
	iflag:  IFlags, // input mode flags
	oflag:  OFlags, // ouput mode flags
	cflag:  CFlags, // control mode flags
	lflag:  LFlags, // local mode flags
	line:   u8, // Line discipline
	cc:     [Control_Characters]u8, // control characters
	ispeed: u32, // input speed
	ospeed: u32, // output speed
}

#assert(offset_of(Termios2, ispeed) / size_of(i32) == 9)
#assert(size_of(Termios2) == 44)


// "0x54 is just a magic number to make these relatively unique ('T')"
// - ioctls.h
TCGETS :: 0x5401
TCSETS :: 0x5402

@(private = "file")
IOC :: proc "contextless" ($dir, $type, $nr, $size: u32) -> u32 {
	_IOC_NRBITS :: 8
	_IOC_TYPEBITS :: 8
	_IOC_NRSHIFT :: 0
	_IOC_SIZEBITS :: 14
	_IOC_TYPESHIFT :: _IOC_NRSHIFT + _IOC_NRBITS
	_IOC_SIZESHIFT :: _IOC_TYPESHIFT + _IOC_TYPEBITS
	_IOC_DIRSHIFT :: _IOC_SIZESHIFT + _IOC_SIZEBITS

	return(
		(dir << _IOC_DIRSHIFT) |
		(type << _IOC_TYPESHIFT) |
		(nr << _IOC_NRSHIFT) |
		(size << _IOC_SIZESHIFT) \
	)
}

@(private = "file")
IOR :: proc "contextless" ($type, $nr: u32, $argtype: typeid) -> u32 {
	_IOC_READ :: 2
	return IOC(_IOC_READ, type, nr, size_of(argtype))
}

@(private = "file")
IOW :: proc "contextless" ($type, $nr: u32, $argtype: typeid) -> u32 {
	_IOC_WRITE :: 1
	return IOC(_IOC_WRITE, type, nr, size_of(argtype))
}

TCGETS2 :: proc() -> u32 {
	return IOR('T', 0x2A, Termios2)
}

TCSETS2 :: proc() -> u32 {
	return IOW('T', 0x2B, Termios2)
}
