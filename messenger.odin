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
	readbuf: [10]byte
	fmt.print("# ")
	eventloop: for {
		n_read, serr := os2.read(os2.stdin, readbuf[:])
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
					fmt.printfln(
						"[ERROR] Cannot call c (configure) with arguments %v. The correct format is c[group, parameter, value]",
						args,
					)
					fmt.print("# ")
					continue eventloop
				}
				send_command(listener.device, .Configure, args[0], args[1], args[2])
				continue eventloop
			case 'a':
				args := get_arguments(readbuf[1:n_read])
				defer delete(args)
				if len(args) > 1 {
					fmt.printfln(
						"[ERROR] Cannot call a (set/get address) with arguments %v. The correct format is a[addr] or simply 'a'",
						args,
					)
					fmt.print("# ")
					continue eventloop
				}

				if len(args) == 1 do send_command(listener.device, .Address, args[0])
				else do send_command(listener.device, .Address)
			case 'm':
				send_command(listener.device, .Send_Message, "helloooo :)", cast(byte)0xFF)
			case:
				fmt.printfln(
					"[WARNING] '%s' is not a valid commmand.\n(try one of 'p', 'r', 'a' or 'm' or enter 'q'/'e' to exit interactive mode)",
					readbuf[:n_read - 1],
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
					fmt.println("[MESSAGE] Received a message from device: ", received)
					any_received = true
				}
			}
			if !any_received {
				fmt.println("[ERROR] Could not receive from device. (serial connection timed out)")
			}
			fmt.print("# ")
		}
	}
}

get_arguments :: proc(word: []byte) -> (args: [dynamic]u8) {
	word := word
	word = transmute([]byte)strings.trim_space(transmute(string)word)
	if len(word) > 1 && word[0] == '[' && word[len(word) - 1] == ']' {
		val: u8 = 0
		for c in word[1:] { 	// note this does not work for non-ascii characters, but you shouldn't enter those as arguments anyways
			low_c := cast(u8)unicode.to_lower(cast(rune)c)
			if c >= '0' && c <= '9' do val = val * 16 + (c - '0')
			else if low_c >= 'a' && low_c <= 'f' do val = val * 16 + low_c - 'a' + 10
			if c == ',' do append(&args, val)
		}
		append(&args, val)
	}
	return
}
