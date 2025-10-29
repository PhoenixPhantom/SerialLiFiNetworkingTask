package main

import "core:fmt"

COLOR_OFF :: "\033[0m"

info :: proc(msg: string, args: ..any) -> int {
	COLOR :: "\033[0;90m"
	TYPE :: "[INFO] "
	buffer := make([]u8, len(msg) + len(COLOR) + len(COLOR_OFF) + len(TYPE))
	defer delete(buffer)

	message := fmt.bprintf(buffer, "%s%s%s%s", COLOR, TYPE, msg, COLOR_OFF)
	return fmt.printf(message, ..args)
}

warn :: proc(msg: string, args: ..any) -> int {
	COLOR :: "\033[0;33m"
	TYPE :: "[WARNING] "
	buffer := make([]u8, len(msg) + len(COLOR) + len(COLOR_OFF) + len(TYPE))
	defer delete(buffer)

	message := fmt.bprintf(buffer, "%s%s%s%s", COLOR, TYPE, msg, COLOR_OFF)
	return fmt.printf(message, ..args)
}

error :: proc(msg: string, args: ..any) -> int {
	COLOR :: "\033[0;31m"
	TYPE :: "[ERROR] "
	buffer := make([]u8, len(msg) + len(COLOR) + len(COLOR_OFF) + len(TYPE))
	defer delete(buffer)

	message := fmt.bprintf(buffer, "%s%s%s%s", COLOR, TYPE, msg, COLOR_OFF)
	return fmt.printf(message, ..args)
}
