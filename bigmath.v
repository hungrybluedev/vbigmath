module main

import big
// import crypto.sha1
// import rand

fn main() {
	// zs := 10_000

	// rand.seed([u32(123), 319])

	// for _ in 0 .. 100 {
	// 	x, y := rand.intn(zs)?, rand.intn(zs)?
	// 	z := x + y

	// 	a1, a2 := rand.int_in_range(1, 101)?, rand.int_in_range(1, 101)00)00)00)?

	// 	b1 := big.integer_from_string(a1.str() + '0'.repeat(x))?
	// 	b2 := big.integer_from_string(a2.str() + '0'.repeat(y))?

	// 	c := b1 * b2
	// 	c_str := c.str()
	// 	assert c_str == (a1 * a2).str() + '0'.repeat(z)
	// 	println(sha1.hexhash(c_str))
	// }
	a := big.integer_from_string('419837469815384138746913847513919239147698163814874618369187469817349836913198264987169487136413341398746193849187314')?
	b := big.integer_from_string('104986108736491864162545785136981734698713649138754871518869183441987469816593645941987469816354861938745193654913414')?

	print(a * b)
}
