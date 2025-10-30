package main

import "core:fmt"
import "core:os/os2"
import "core:strings"
import "core:unicode"

main :: proc() {
	device, ok := connect_device("/dev/ttyACM0")
	assert(ok)
	listener := listen_to_device(device)
	defer disconnect_device(device, listener)

	interactive_mode(listener)
}

interactive_mode :: proc(listener: Listener) {
	readbuf: [2048]byte
	fmt.print("# ")
	eventloop: for {
		n_read, serr := os2.read(os2.stdin, readbuf[:])
		if n_read == len(readbuf) {
			warn(
				"The sequence entered was detected to have at least %v characters. Messages exceeding %v bytes will be truncated.",
				len(readbuf),
				len(readbuf),
			)
			os2.flush(os2.stdin)
		}
		if serr == nil || n_read > 0 {
			switch readbuf[0] {
			case 'e', 'q':
				fmt.println("Exiting")
				break eventloop
			case 'p':
				send_command(listener.device, .Version)
			case 'r':
				send_command(listener.device, .Reset)
			case 'c':
				args := get_arguments(readbuf[1:n_read])
				defer delete(args)
				if len(args) != 3 {
					error(
						"Cannot call 'c' (configure) with arguments %v. The correct format is c[group, parameter, value]\n",
						args,
					)
					fmt.print("# ")
					continue eventloop
				}
				send_command(listener.device, .Configure, args[0], args[1], args[2])
			case 'a':
				args := get_arguments(readbuf[1:n_read])
				defer delete(args)
				if len(args) > 1 {
					error(
						"Cannot call 'a' (set/get address) with arguments %v. The correct format is a[addr] or simply 'a'\n",
						args,
					)
					fmt.print("# ")
					continue eventloop
				}

				if len(args) == 1 do send_command(listener.device, .Address, args[0])
				else do send_command(listener.device, .Address)
			case 'm':
				args: [dynamic]u8
				defer delete(args)
				sep := -1
				word := transmute([]byte)strings.trim_space(transmute(string)readbuf[1:n_read])
				if len(word) > 1 && word[0] == '[' && word[len(word) - 1] == ']' {
					sep = strings.index(transmute(string)word, "\\0")
					if sep > 0 do args = get_arguments(word[3 + sep:], full = false)
				}

				if len(args) != 1 {
					error(
						"Cannot call 'm' (send message) with arguments message = '%s' and address = %v. The correct format is m[message\\0, address]\n",
						word[1:sep] if sep >= 0 else word[:0],
						args,
					)
					fmt.print("# ")
					continue eventloop
				}

				send_command(listener.device, .Send_Message, transmute(string)word[1:sep], args[0])
			case:
				warn("'%s' is not a valid commmand.\n", readbuf[:n_read - 1])
				fallthrough
			case 'h':
				respond(
					`Try one of:
         p: print version
         r: reset device
         c[group, parameter, value]: set value of parameter from group
         a: read device address
         a[addr_in_hex]: set device address (8-bits)
         m[message\0, target_addr]: send the message (without the \0 separator) to the target address (FF for brodcast)
         q/e: exit interactive mode

You can find more details described in the documentation:
   https://gitlab.ethz.ch/wireless/WirelessNetworkingAndMobileComputing/-/wikis/home/Assignment-05/VlcSerial

Use 'q' or 'e' to exit interactive mode.
`,
				)
				fmt.print("# ")
				continue eventloop
			}
			ok := true
			any_received := false
			received: string
			for ok {
				received, ok = wait_on_device(listener)
				defer delete(received)

				if ok {
					respond("Received a message from device: %v\n", received)
					any_received = true
				}
			}
			if !any_received {
				error("Could not receive from device. (serial connection timed out)\n")
			}
			fmt.print("# ")
		}
	}
}

get_arguments :: proc(word: []byte, full := true) -> (args: [dynamic]u8) {
	word := word
	if full {
		word = transmute([]byte)strings.trim_space(transmute(string)word)
		if len(word) < 2 || word[0] != '[' || word[len(word) - 1] != ']' do return
	}
	val: u8 = 0
	for c in word[1 if full else 0:] { 	// note this does not work for non-ascii characters, but you shouldn't enter those as arguments anyways
		low_c := cast(u8)unicode.to_lower(cast(rune)c)
		if c >= '0' && c <= '9' do val = val * 16 + (c - '0')
		else if low_c >= 'a' && low_c <= 'f' do val = val * 16 + low_c - 'a' + 10
		if c == ',' do append(&args, val)
	}
	append(&args, val)
	return
}
