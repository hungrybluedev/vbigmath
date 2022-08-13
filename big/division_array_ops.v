module big

import math.bits

// suppose operand_a bigger than operand_b and both not null.
// Both quotient and remaider are allocated but of length 0
[direct_array_access]
fn binary_divide_array_by_array(operand_a []u32, operand_b []u32, mut quotient []u32, mut remainder []u32) {
	for index in 0 .. operand_a.len {
		remainder << operand_a[index]
	}

	len_diff := operand_a.len - operand_b.len
	$if debug {
		assert len_diff >= 0
	}

	// we must do in place shift and operations.
	mut divisor := []u32{cap: operand_b.len}
	for _ in 0 .. len_diff {
		divisor << u32(0)
	}
	for index in 0 .. operand_b.len {
		divisor << operand_b[index]
	}
	for _ in 0 .. len_diff + 1 {
		quotient << u32(0)
	}

	lead_zer_remainder := u32(bits.leading_zeros_32(remainder.last()))
	lead_zer_divisor := u32(bits.leading_zeros_32(divisor.last()))
	bit_offset := (u32(32) * u32(len_diff)) + (lead_zer_divisor - lead_zer_remainder)

	// align
	if lead_zer_remainder < lead_zer_divisor {
		lshift_in_place(mut divisor, lead_zer_divisor - lead_zer_remainder)
	} else if lead_zer_remainder > lead_zer_divisor {
		lshift_in_place(mut remainder, lead_zer_remainder - lead_zer_divisor)
	}

	$if debug {
		assert left_align_p(divisor[divisor.len - 1], remainder[remainder.len - 1])
	}
	for bit_idx := int(bit_offset); bit_idx >= 0; bit_idx-- {
		if greater_equal_from_end(remainder, divisor) {
			bit_set(mut quotient, bit_idx)
			subtract_align_last_byte_in_place(mut remainder, divisor)
		}
		rshift_in_place(mut divisor, 1)
	}

	// adjust
	if lead_zer_remainder > lead_zer_divisor {
		// rshift_in_place(mut quotient, lead_zer_remainder - lead_zer_divisor)
		rshift_in_place(mut remainder, lead_zer_remainder - lead_zer_divisor)
	}
	shrink_tail_zeros(mut remainder)
	shrink_tail_zeros(mut quotient)
}

// help routines for cleaner code but inline for performance
// quicker than BitField.set_bit
[direct_array_access; inline]
fn bit_set(mut a []u32, n int) {
	byte_offset := n >> 5
	mask := u32(1) << u32(n % 32)
	$if debug {
		assert a.len >= byte_offset
	}
	a[byte_offset] |= mask
}

// a.len is greater or equal to b.len
// returns true if a >= b (completed with zeroes)
[direct_array_access; inline]
fn greater_equal_from_end(a []u32, b []u32) bool {
	$if debug {
		assert a.len >= b.len
	}
	offset := a.len - b.len
	for index := a.len - 1; index >= offset; index-- {
		if a[index] > b[index - offset] {
			return true
		} else if a[index] < b[index - offset] {
			return false
		}
	}
	return true
}

// a := a - b supposed a >= b
// attention the b operand is align with the a operand before the subtraction
[direct_array_access; inline]
fn subtract_align_last_byte_in_place(mut a []u32, b []u32) {
	mut carry := u32(0)
	mut new_carry := u32(0)
	offset := a.len - b.len
	for index := a.len - b.len; index < a.len; index++ {
		if a[index] < (b[index - offset] + carry) {
			new_carry = 1
		} else {
			new_carry = 0
		}
		a[index] -= (b[index - offset] + carry)
		carry = new_carry
	}
	$if debug {
		assert carry == 0
	}
}

// logical left shift
// there is no overflow. We know that the last bits are zero
// and that n <= 32
[direct_array_access; inline]
fn lshift_in_place(mut a []u32, n u32) {
	mut carry := u32(0)
	mut prec_carry := u32(0)
	mask := ((u32(1) << n) - 1) << (32 - n)
	for index in 0 .. a.len {
		prec_carry = carry >> (32 - n)
		carry = a[index] & mask
		a[index] <<= n
		a[index] |= prec_carry
	}
}

// logical right shift without control because these digits have already been
// shift left before
[direct_array_access; inline]
fn rshift_in_place(mut a []u32, n u32) {
	mut carry := u32(0)
	mut prec_carry := u32(0)
	mask := u32((1 << n) - 1)
	for index := a.len - 1; index >= 0; index-- {
		carry = a[index] & mask
		a[index] >>= n
		a[index] |= prec_carry << (32 - n)
		prec_carry = carry
	}
}

// for assert
[inline]
fn left_align_p(a u32, b u32) bool {
	return bits.leading_zeros_32(a) == bits.leading_zeros_32(b)
}

// implementation of the Burnikel-Ziegler algorithm for recursive division
fn bnzg_divide_by_array(operand_a []u32, operand_b []u32, mut quotient []u32, mut remainder []u32) {
	r := operand_a.len
	s := operand_b.len

	m := 1 << bits.len_32(u32(s / burnikel_zeigler_division_limit))

	j := (s + m - 1) / m
	n := j * m
	dump(j)
	dump(n)
	n32 := m * 32
	len_diff := n32 - array_bit_length(operand_b)
	mut sigma := if len_diff > 0 { u32(len_diff) } else { u32(0) }
	mut sigma_copy := sigma

	sdiv := int(sigma / 32)
	mut a_shifted := []u32{len: r + sdiv}
	mut b_shifted := []u32{len: s + sdiv}

	for sigma >= 32 {
		a_shifted << 0
		b_shifted << 0
		sigma -= 32
	}

	shift_digits_left(operand_b, sigma, mut b_shifted)
	shift_digits_left(operand_a, sigma, mut a_shifted)

	mut t := (array_bit_length(a_shifted) + n32) / n32
	if t < 2 {
		t = 2
	}

	dump(t)
	dump(a_shifted.len)
	mut z := get_array_block(a_shifted, t - 2, n)
	mut qi := []u32{cap: n}
	mut ri := []u32{cap: n}

	dump(z.len)
	for i := t - 2; i > 0; i-- {
		qi.clear()
		ri.clear()

		bnzg_2n_1n(z, b_shifted, mut qi, mut ri, n)

		z = ri.clone()
		z << a_shifted[i - 1..i]
		lshift_digits_in_place(mut qi, i * n)
		add_in_place(mut quotient, qi)
	}

	bnzg_2n_1n(z, b_shifted, mut qi, mut ri, n)
	add_in_place(mut quotient, qi)

	digit_offset := int(sigma_copy >> 5)
	rshift_digits_in_place(mut ri, digit_offset)
	remainder = []u32{len: ri.len}
	shift_digits_right(ri, (sigma_copy & 31), mut remainder)
}

fn get_array_block(a []u32, index int, size int) []u32 {
	start := index * size
	if start >= a.len {
		return []u32{}
	}

	end_guess := (index + 1) * size
	end := if end_guess > a.len { a.len } else { end_guess }

	return a[start..end]
}

fn bnzg_2n_1n(operand_a []u32, operand_b []u32, mut quotient []u32, mut remainder []u32, n int) {
	// When n is odd or the operands are small, use simple division algorithm
	if n & 1 == 1 || n < burnikel_zeigler_division_limit {
		binary_divide_array_by_array(operand_a, operand_b, mut quotient, mut remainder)
		return
	}

	half := n >> 1
	n2 := n * 2

	a_upper := operand_a[half..]
	a_lower := operand_a[0..half]

	mut q0 := []u32{cap: n2}
	mut r0 := []u32{cap: n2}

	bnzg_3n_2n(a_upper, operand_b, mut q0, mut r0, n)

	mut a_new := []u32{cap: a_lower.len + r0.len}
	for digit in a_lower {
		a_new << digit
	}
	for digit in r0 {
		a_new << digit
	}

	mut q1 := []u32{cap: n2}

	bnzg_3n_2n(a_new, operand_b, mut q1, mut remainder, n)
}

fn bnzg_3n_2n(operand_a []u32, operand_b []u32, mut quotient []u32, mut remainder []u32, n int) {
	n2 := n * 2
	n3 := n * 3

	a12 := operand_a[n..]
	a1 := operand_a[n2..]
	a3 := operand_a[0..n]

	b2 := operand_b[..n]
	b1 := operand_b[n..]

	cmp_result := compare_digit_array(a1, b1)

	mut r1 := []u32{cap: n}

	if cmp_result < 0 {
		bnzg_2n_1n(a12, b1, mut quotient, mut r1, n)
	} else {
		for _ in 0 .. n {
			quotient << 0xFFFFFFFF
		}
		mut sb := []u32{len: n}
		for digit in b1 {
			sb << digit
		}
		for _ in 0 .. n2 {
			r1 << 0
		}
		subtract_digit_array(a12, sb, mut r1)
		add_in_place(mut r1, b1)
	}

	mut d := []u32{len: n3}
	multiply_digit_array(quotient, b2, mut d)

	mut rhat := []u32{len: n2}
	for digit in a3 {
		rhat << digit
	}
	for digit in r1 {
		rhat << digit
	}

	for compare_digit_array(rhat, d) < 0 {
		add_in_place(mut rhat, operand_b)
		subtract_in_place(mut quotient, [u32(1)])
	}

	subtract_digit_array(rhat, d, mut remainder)
}
