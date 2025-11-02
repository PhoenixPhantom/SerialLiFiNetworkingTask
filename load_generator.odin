package main

import "core:encoding/csv"
import "core:fmt"
import "core:math/rand"
import "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:time"


@(require_results)
make_random_string :: proc(length: int) -> string {
	source := make([]u8, length)
	for &c in source do c = cast(u8)rand.int31_max(255 - ' ') + ' ' // ' ' is the first non-control
	return transmute(string)source
}

prepare_test :: proc(listener: Listener) {
	send_command(listener.device, .Configure, cast(u8)0, cast(u8)1, cast(u8)20)
	response, success := wait_on_device(listener, time.Second * 10)
	info("%s", response)
	assert(success)
	delete(response)

	send_command(listener.device, .Configure, cast(u8)0, cast(u8)2, cast(u8)5)
	response, success = wait_on_device(listener, time.Second * 10)
	info("%s", response)
	assert(success)
	delete(response)
}


load_generator :: proc(listener: Listener) {
	prepare_test(listener)

	respond("Enter the address of the load receiver\n")
	prompt("Target address: ")
	file, err := os2.open("sender.csv", {.Write, .Trunc, .Create})
	assert(err == nil)
	defer os2.close(file)

	data: csv.Writer
	csv.writer_init(&data, os2.to_stream(file))
	defer csv.writer_flush(&data)

	inbuf: [3]u8
	n_read, serr := os2.read(os2.stdin, inbuf[:])
	assert(serr == nil)
	address: u8
	if n_read > 1 do address = get_byte(transmute(string)inbuf[:n_read])
	info("Using address: %2X\n", address)

	packet_sizes := [?]int{1, 100, 180, 200}

	notebuf: [1024]u8
	for {
		respond("Enter experiment notes and press enter (enter 'quit' to quit)\n")
		n_readnote := 0
		oerr: os2.Error
		for n_readnote <= 0 {
			prompt("-> ")
			n_readnote, oerr = os2.read(os2.stdin, notebuf[:])
			assert(oerr == nil)
		}
		note := strings.clone(transmute(string)notebuf[:n_readnote - 1])
		defer delete(note)
		if note == "quit" do break

		for packet_size in packet_sizes {
			respond("Testing packet size %v\n", packet_size)
			title := fmt.bprintf(notebuf[:], "%s (Packet size: %v)", note, packet_size)
			csv.write(&data, {})
			csv.write(&data, {title})
			raw_package, raw_throughput, dropped := run_experiment(listener, address, packet_size)
			info("Finished experiment.\n")
			defer {
				delete(raw_package)
				delete(raw_throughput)
			}
			delays := make([]string, len(raw_package) + 1)
			defer {
				for delay in delays[1:] do delete(delay)
				delete(delays)
			}
			times := make([]string, len(raw_package) + 1)
			defer {
				for time in times[1:] do delete(time)
				delete(times)
			}
			retrans := make([]string, len(raw_package) + 1)
			defer {
				for retran in retrans[1:] do delete(retran)
				delete(retrans)
			}

			throughputs := make([]string, len(raw_throughput) + 1)
			defer {
				for throughput in throughputs[1:] do delete(throughput)
				delete(throughputs)
			}
			delays[0] = "Packet delay [ns]"
			times[0] = "Transmission start [ns from first packet]"
			retrans[0] = "Number of retransmissions [#]"
			throughputs[0] = "Throughput [b/ms] (Average every 1s)"
			for delay, i in raw_package {
				if delay.delay == max(time.Duration) do delays[i + 1] = strings.clone("NaN")
				else do delays[i + 1] = strings.clone(strconv.itoa(notebuf[:], cast(int)delay.delay))
				retrans[i + 1] = strings.clone(strconv.itoa(notebuf[:], delay.retransmissions))
				times[i + 1] = strings.clone(
					strconv.itoa(notebuf[:], cast(int)time.diff(raw_package[0].sent, delay.sent)),
				)
			}
			for tp, i in raw_throughput do throughputs[i + 1] = strings.clone(strconv.ftoa(notebuf[:], tp, 'f', 15, 64))
			csv.write(&data, times)
			csv.write(&data, delays)
			csv.write(&data, retrans)
			csv.write(&data, throughputs)
			csv.write(
				&data,
				{"Packages dropped over serial [#]", strconv.itoa(notebuf[:], dropped)},
			)

			send_command(listener.device, .Reset)
			response, ok := wait_on_device(listener, time.Second * 10)
			info("%v\n", response)
			assert(ok)
			delete(response)
			prepare_test(listener)
		}
		csv.write(&data, {})
		respond("Experiment completed!\n")
	}
}

Packet_Properties :: struct {
	sent:            time.Time,
	delay:           time.Duration,
	retransmissions: int,
}

run_experiment :: proc(
	listener: Listener,
	address: u8,
	length: int,
) -> (
	packet: [dynamic]Packet_Properties,
	throughput: [dynamic]f64,
	dropped: int,
) {
	experiment_start := time.now()
	now := experiment_start
	last_tp := now
	bytes_sent: int
	last_received: time.Time

	for time.diff(experiment_start, now) < time.Minute {
		payload := make_random_string(length)
		info("Transmitting payload...\n")
		send_command(listener.device, .Send_Message, payload, address)
		append(&packet, Packet_Properties{time.now(), max(time.Duration), 0})
		bytes_sent += length

		do_continue := true
		start := time.now()
		last_received, now = start, start
		// limit wait time for failing transmissions
		// and wait at least 10ms to not overload the controller
		// WARN: 10 ms as claimed in the task description (and for that matter even 100ms and 200ms (both tested)) still cause
		// the controller to consistently miss every second request. 300ms
		// works but sadly already starts limiting the 1byte package case when no retransmissions are needed
		for (do_continue || time.diff(start, now) < time.Millisecond * 300) &&
		    time.diff(last_received, now) < time.Second * 5 &&
		    time.diff(experiment_start, now) < time.Minute {
			if diff := time.diff(last_tp, now); diff >= time.Second {
				append(&throughput, cast(f64)bytes_sent / cast(f64)(diff / time.Millisecond))
				bytes_sent = 0
				last_tp = now
			}

			now = time.now()
			received := wait_on_device(listener, 0) or_continue
			defer delete(received)

			do_continue &= process_response(received, address, &packet)
			now = time.now()
			last_received = now
		}
		if do_continue do dropped += 1
		info("Transmitted payload\n")
	}

	end := now
	for time.diff(end, now) < time.Second * 10 &&
	    packet[len(packet) - 1].delay != max(time.Duration) { 	// wait for late acks
		now = time.now()
		received := wait_on_device(listener, 0) or_continue
		defer delete(received)
		breaking := !process_response(received, address, &packet)
		if breaking do dropped -= 1
	}
	return

	process_response :: proc(
		received: string,
		address: u8,
		packet: ^[dynamic]Packet_Properties,
	) -> (
		do_continue: bool,
	) {
		if len(received) < 4 do return true
		else if received[:4] == "m[D]" do return false
		else if received[0] == 's' {
			eval := parse_statistical(received)
			if (eval.type & .Rts) != .Invalid {
				packet[eval.sequence_number].retransmissions += 1
			}
			if eval.type == .Data {
				//info("%v vs %v", len(delays), eval.sequence_number)
				info("Received data frame %#v", eval)
				// assert(len(packet) == eval.sequence_number)
				// append(packet, Packet_Properties{time.now(), max(time.Duration), 0})
			} else if (eval.type == .Ack || eval.type & .Ack != .Invalid) && eval.from == address {
				info("Received ack frame %#v", eval)
				packet[eval.sequence_number].delay = time.diff(packet[eval.sequence_number].sent, time.now())
			} else do info("Unknown evaluation type %v\n", eval.type)
		}
		return true
	}
}

load_receiver :: proc(listener: Listener) {
	prepare_test(listener)

	send_command(listener.device, .Address)
	addr, ok := wait_on_device(listener, time.Second + 10)
	assert(ok)
	respond("The receiver has address: %v\n", addr[2:len(addr) - 2])
	for {
		message := wait_on_device(listener, 0) or_continue
		delete(message)
	}
}
