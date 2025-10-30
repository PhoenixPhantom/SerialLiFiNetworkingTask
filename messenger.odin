package main

import "core:fmt"
import "core:math"
import "core:os/os2"
import "core:strings"
import "core:time"

main :: proc() {
	await_message :: proc() {
		prompt("\033[0;92m(messenger) \033[0m")
	}


	readbuf: [8192]byte
	device := connect_to_device()
	listener := listen_to_device(device)
	defer disconnect_device(device, listener)


	respond(
		`
---------------------------------------------------------------
|            Welcome to the Visual Light Messenger            |
|                                                             |
|                                                             |
| You can write messages to others by writing your message    |
| and pressing enter. To read the last (up to 100) unread     |
| received messages, simply press enter without writing       |
| anything.                                                   |
|                                                             |
| To send your messages to a specific target, enter  \to addr |
| instead of a message with addr being your peer's            |
| address and all your subsequent                             |
| messages will only be sent there.                           |
|                                                             |
| To communicate with everyone, enter                \to all  |
|                                                             |
| To find your address to share with others, enter   \addr    |
|                                                             |
| To close the Visual Light Messenger, enter         \exit    |
|                                                             |
| And finally, you can access the lower-level                 |
| settings of your VLC device by entering       \interactive  |
---------------------------------------------------------------
`,
	)

	target_address: u8 = 0xFF
	n_failures := 0
	await_message()
	for {
		received := false
		for {
			message := wait_on_device(listener, 1) or_break
			received = true
			if message[0] == 's' {
				eval := parse_statistical(message)
				info("Statistical evaluation: %#v\n", eval)
			} else if !receive_message_serial(message) {
				info("Received unknown tranmission type: %s\n", message)
			}
		}

		if received do await_message()

		n_read, serr := os2.read(os2.stdin, readbuf[:])
		if n_read == len(readbuf) {
			warn(
				"Your message exceeds the current maximum message length of the Visual Light Messenger.\nMessages exceeding %v bytes will be truncated.\n",
				len(readbuf),
			)
			os2.flush(os2.stdin)
		}
		if serr == nil || n_read > 0 {
			message := strings.trim_space(transmute(string)readbuf[:n_read])
			switch message {
			case "\\addr":
				send_command(listener.device, .Address)
				received, success := wait_on_device(listener)
				defer delete(received)

				if success {
					success =
						len(received) == 5 &&
						strings.has_prefix(received, "a[") &&
						strings.has_suffix(received, "]")
					if success {
						addr := get_byte(received[2:])
						respond("Your device has address: %2X\n", addr)
						await_message()
						continue
					} else do fmt.print(received)
				}

				warn("Cannot get device address.\n")
				await_message()
			case "\\interactive":
				interactive_mode(listener)
				await_message()
			case "\\exit":
				respond("Closing...\n")
				return
			case:
				if strings.has_prefix(message, "\\to ") {
					message = strings.trim_space(message[4:])
					if strings.contains(message, "all") {
						target_address = 0xFF
						info("Messages will now be sent to everyone\n")
					} else if len(message) == 2 {
						target_address = get_byte(message)
						info("Messages will now be sent to %2X\n", target_address)
					} else do warn("Cannot determine target address\n")
					await_message()
				} else {
					send_full_message(listener, target_address, message, &n_failures)
					await_message()
				}
			}
		}
	}
	interactive_mode(listener)
}

interactive_mode :: proc(listener: Listener) {
	readbuf: [2048]byte
	fmt.print("# ")
	eventloop: for {
		n_read, serr := os2.read(os2.stdin, readbuf[:])
		if n_read == len(readbuf) {
			warn(
				"The sequence entered was detected to have at least %v characters. Messages exceeding %v bytes will be truncated.\n",
				len(readbuf),
				len(readbuf),
			)
			os2.flush(os2.stdin)
		}
		if serr == nil || n_read > 0 {
			switch readbuf[0] {
			case 'e', 'q':
				info("Exiting interactive mode...\n")
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

connect_to_device :: proc() -> (device: Serial_Device) {
	readbuf: [1024]byte
	ok: bool
	devicename: string = "ttyACM0"
	if len(os2.args) > 1 {
		devicename = os2.args[1]
	}
	for {
		path: [1024]byte
		devicename = strings.trim_space(devicename)
		device_path := fmt.bprintf(path[:], "/dev/%s", devicename)

		info("Attempting to connect to %s\n", device_path)
		device, ok = connect_device(device_path, log_failure = false)
		if ok do break

		respond("Please enter the name of the device you want to connect to\n")
		prompt("Device name: ")
		n_read := os2.read(os2.stdin, readbuf[:]) or_continue
		devicename = transmute(string)readbuf[:n_read]
	}
	return
}

send_full_message :: proc(
	listener: Listener,
	target_address: u8,
	message: string,
	n_failures: ^int,
) {
	message := message
	message = strings.trim_space(message)
	if len(message) > 0 {
		info("Sending message...\n")
		completed := true
		MAX_MSG_SIZE :: 200
		n := cast(int)math.ceil(cast(f32)len(transmute([]u8)message) / MAX_MSG_SIZE)
		for i in 1 ..< n {
			completed &= send_single_message(
				listener,
				target_address,
				message[(i - 1) * MAX_MSG_SIZE:i * MAX_MSG_SIZE],
			)
		}
		info("%v : %v\n", len(transmute([]u8)message), n)
		completed &= send_single_message(
			listener,
			target_address,
			message[(n - 1) * MAX_MSG_SIZE:],
		)
		if completed {
			info("Message sent!\n")
			n_failures^ = 0
		} else {
			error("Could not send message.\n")
			n_failures^ += 1
			if n_failures^ > 3 {
				info("Something seems wrong with the device. Resetting...\n")
				send_command(listener.device, .Reset)
				resp := wait_on_device(listener)
				delete(resp)
				respond("The device was reset. Note that your address may have changed.\n")
				n_failures^ = 0
			}
		}
	}

}

send_single_message :: proc(listener: Listener, addr: u8, message: string) -> (completed: bool) {
	info("Sending %s\n", message)
	send_command(listener.device, .Send_Message, message, addr)
	now := time.now()
	start := now
	for time.diff(start, now) < time.Second * 15 {
		received := wait_on_device(listener, time.Second * 10) or_break
		defer delete(received)
		if len(received) < 4 do continue
		if received[:4] == "m[T]" do info("Transmitting data...\n")
		else if received[:4] == "m[D]" {
			return true
		} else if received[0] == 's' {
			eval := parse_statistical(received)
			info("Statistical evaluation: %#v\n", eval)
		} else do receive_message_serial(received)
		now = time.now()
	}
	return false
}

receive_message_serial :: proc(message: string) -> bool {
	if message[:4] == "m[R," {
		type: enum {
			Invalid,
			Data,
			Ack,
			Rts,
			Cts,
		}
		switch message[4] {
		case 'D':
			type = .Data
		case 'A':
			type = .Ack
		case 'R':
			type = .Rts
		case 'C':
			type = .Cts
		}
		sent := message[6:len(message) - 2]
		if type == .Data {
			respond("\nReceived:\n______________\n%s\n______________\n", sent)
		} else do info("Received transmission (%v): %s\n", type, sent)
		return true
	}
	return false
}
