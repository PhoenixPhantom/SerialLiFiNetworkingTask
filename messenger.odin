package main

import "core:fmt"
import "core:os/os2"


main :: proc() {
	device, ok := connect_device("/dev/ttyACM0")
	assert(ok)
	listener := listen_to_device(device)
	defer disconnect_device(device, listener)

	readbuf: [2]byte
	eventloop: for {
		n_read, serr := os2.read(os2.stdin, readbuf[:])
		if serr == nil || n_read > 0 {
			switch readbuf[0] {
			case 'q':
				fmt.println("Exiting")
				break eventloop
			case 'p':
				send_command(device, .Version)
			case 'r':
				send_command(device, .Reset)
			case 'c':
				//send_command(device, .Configure, )
				fmt.println("[WARNING] Configuration is not yet implemented.")
				continue eventloop
			case 'a':
				send_command(device, .Address, cast(byte)0xF0)
			case 'm':
				send_command(device, .Send_Message, "helloooo :)", cast(byte)0xFF)
			case:
				fmt.println("[WARNING] This is not a valid commmand. (enter q to exit)")
				continue eventloop
			}
			ok = true
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
		}
	}
}
