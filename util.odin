package main

import "core:strings"
import "core:unicode"

get_arguments :: proc(word: []byte, full := true) -> (args: [dynamic]u8) {
	word := word
	if full {
		word = transmute([]byte)strings.trim_space(transmute(string)word)
		if len(word) < 2 || word[0] != '[' || word[len(word) - 1] != ']' do return
	}
	val: u8 = 0
	for c in word[1 if full else 0:] { 	// note this does not work for non-ascii characters, but you shouldn't enter those as arguments anyways
		hex, is_hex := get_hex(cast(rune)c)
		if is_hex do val = val * 16 + hex
		else if c == ',' do append(&args, val)
	}
	append(&args, val)
	return
}

get_byte :: proc(word: string) -> u8 {
	return get_hex(cast(rune)word[0]) * 16 + get_hex(cast(rune)word[1])
}

get_hex :: proc(c: rune) -> (val: u8, is_hex: bool) #optional_ok {
	c := c
	c = unicode.to_lower(c)
	if c >= '0' && c <= '9' do return u8(c - '0'), true
	else if c >= 'a' && c <= 'f' do return u8(c - 'a' + 10), true
	else do return 0, false
}
