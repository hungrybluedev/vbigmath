module main

import big
import crypto.sha1
import rand

fn main() {
	n := $env('DIGITS').int()

	rand.seed([u32(314981), 1397])

	for _ in 0 .. 10 {
		x, y := 3 * n, n
		z := 2 * n

		a1, a2 := rand.int_in_range(1, 101)?, 1

		b1 := big.integer_from_string(a1.str() + '0'.repeat(x))?
		b2 := big.integer_from_string(a2.str() + '0'.repeat(y))?

		println(b1)

		c := b1 / b2
		c_str := c.str()
		assert c_str == a1.str() + '0'.repeat(z)
		println(sha1.hexhash(c_str) + ' ' + (c.bit_len() / 32).str())
	}
}
