package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:sync/chan"
import "core:sys/linux"
import "core:thread"
import "core:time"

Serial_Device :: linux.Fd

connect_device :: proc(name: string, log_failure := true) -> (device: Serial_Device, ok: bool) {
	err: linux.Errno
	device_name := strings.clone_to_cstring(name)
	defer delete(device_name)
	device, err = linux.open(device_name, {.RDWR, .NOCTTY, .NONBLOCK})
	if err != nil {
		if log_failure do error("Cannot conntect to device. Encountered: %v\n", err)
		return
	}
	assert(0x802C542A == TCGETS2())
	assert(0x402C542B == TCSETS2())

	info("Device found.\n")
	info("Setting baudrate...\n")
	settings: Termios2
	linux.ioctl(device, TCGETS2(), cast(uintptr)&settings)
	settings.lflag &~= {.ICANON, .ECHO, .ECHOE, .ECHOK, .ECHONL, .ISIG, .IEXTEN}

	settings.oflag &~= {.OPOST, .ONLCR, .OCRNL}

	settings.iflag &~= {.INLCR, .IGNCR, .ICRNL, .IGNBRK}
	settings.iflag &~= {.PARMRK, .INPCK, .ISTRIP} // setup parity
	settings.iflag &~= {.IXON, .IXOFF, .IXANY} // no xonxoff

	settings.cflag.baudrate = cast(u32)BRates_Extended.B115200
	settings.cflag.extended_baudrate = true

	settings.cflag.char_size = .Size8
	settings.cflag.c_local = true
	settings.cflag.c_read = true
	settings.cflag.c_stopb = false

	settings.cflag.parity_enable = false
	settings.cflag.parity_odd = false
	settings.cflag.cms_parity = false
	settings.cflag.c_rtscts = false

	settings.cc[.VMIN] = 0
	settings.cc[.VTIME] = 0
	linux.ioctl(device, TCSETS2(), cast(uintptr)&settings)

	info("Setting parameters... (please wait)\n")
	time.sleep(time.Second * 2)
	info("Parameters set.\n")

	return device, true
}

Listener :: struct {
	device:  Serial_Device,
	channel: chan.Chan(string),
	thread:  ^thread.Thread,
}

listen_to_device :: proc(device: Serial_Device) -> (listener: Listener) {
	listener.device = device
	err: runtime.Allocator_Error
	listener.channel, err = chan.create(chan.Chan(string), 10, context.allocator)
	assert(err == nil)
	listener.thread = thread.create_and_start_with_poly_data2(
		device,
		chan.as_send(listener.channel),
		receive_serial,
		context,
	)
	return listener
}

@(require_results)
wait_on_device :: proc(
	listener: Listener,
	timeout: time.Duration = time.Second,
) -> (
	response: string,
	success: bool,
) #optional_ok {
	now := time.now()
	start := now
	ok: bool
	assert(!chan.is_closed(listener.channel))
	for time.diff(start, now) < timeout {
		response, ok = chan.try_recv(listener.channel)
		if ok do return response, true
		now = time.now()
	}
	return {}, false
}

disconnect_device :: proc(device: Serial_Device, listener: Listener = {}) -> linux.Errno {
	if listener != {} {
		assert(device == listener.device)
		chan.close(listener.channel)
		thread.join(listener.thread)
		thread.destroy(listener.thread)
	}
	return linux.close(device)
}

Device_Command :: enum {
	Reset,
	Version,
	Address,
	Configure,
	Send_Message,
}

@(private = "file")
receive_serial :: proc(device: Serial_Device, channel: chan.Chan(string, .Send)) {
	input_buffer: [10]byte
	found: [dynamic]u8

	find_transmission_end :: proc(found: []u8, prior: u8 = 0) -> (i: int) {
		prior := prior
		for c in found {
			i += 1
			if (prior == 'r' || prior == ']') && c == '\n' do return i // \n always marks the end of a serial transmission
			prior = c
		}
		return -1
	}

	for !chan.is_closed(channel) {
		n_read, err := linux.read(device, input_buffer[:])
		if n_read > 0 {
			old_len := len(found)
			append(&found, ..input_buffer[:n_read])
			for {
				i :=
					old_len +
					find_transmission_end(
						found[old_len:],
						found[old_len - 1] if old_len != 0 else 0,
					)

				if i >= old_len {
					chan.send(channel, strings.clone_from_bytes(found[:i]))
					remove_range(&found, 0, i) // clear received
					old_len = 0
				} else do break
			}
		}

		if err != nil && err != .EAGAIN {
			fmt.print(err)
			if err != nil {
				warn("Couldn't read from serial connection: %v\n", err)
				delete(found)
			}
		}
	}
}

send_command :: proc(device: Serial_Device, command: Device_Command, args: ..any) -> bool {
	command_string: string
	command_buffer: [512]byte
	switch command {
	case .Reset:
		command_string = "r\n"
	case .Version:
		command_string = "p\n"
	case .Address:
		if len(args) == 0 do command_string = "a\n"
		else do command_string = fmt.bprintf(command_buffer[:], "a[%2X]\n", args[0].(byte))
	case .Configure:
		command_string = fmt.bprintf(
			command_buffer[:],
			"c[%v,%v,%v]\n",
			args[0].(byte),
			args[1].(byte),
			args[2].(byte),
		)
	case .Send_Message:
		command_string = fmt.bprintf(
			command_buffer[:],
			"m[%s%c,%2X]\n",
			args[0].(string),
			0,
			args[1].(byte),
		)

	}
	n_written, err := linux.write(device, transmute([]u8)command_string)
	if err != nil {
		error("Cannot send command. Encountered:  (after writing %v bytes) %v\n", err, n_written)
		return false
	}
	time.sleep(time.Millisecond * 100)
	return true
}
