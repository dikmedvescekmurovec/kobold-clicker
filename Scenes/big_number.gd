class_name BigNumber
## The one way a growing quantity is written down. Gold, monster HP, damage and prices all climb
## exponentially, so a late figure is twenty digits in a page three squares wide. Under a million the
## whole number is spelled out, exactly what is on screen today; above it, three significant digits as
## `1.23e6`. There is no mantissa class underneath -- the quantities are plain doubles and plain
## arithmetic, and this is the only place they are turned into text.

## Where the whole number gives up the page. Seven digits is already wider than a price box.
const PLAIN_BELOW := 1e6


## `value` as text; `signed` writes the leading `+` a stat delta needs.
##
## GDScript has no `%e`, so the mantissa and the decade are worked out by hand -- and then corrected
## rather than trusted, because `log()` in doubles is off by one either way. `log(1000) / log(10)`
## comes back as 2.999999999999999 (the `Coins.count_for` gotcha) and its floor is a decade short,
## which would print a million as `10.00e5`.
static func format(value: float, signed := false) -> String:
	if is_nan(value):
		return "nan"
	var sign_text := "-" if value < 0.0 else ("+" if signed else "")
	if is_inf(value):
		return sign_text + "inf"
	# Rounded before it is measured: 999999.6 is under a million but its whole number is not, and
	# writing "1000000" there would leak the one shape this exists to keep off the page.
	var rounded := roundf(value)
	if absf(rounded) < PLAIN_BELOW:
		# roundi carries its own minus, so `signed` is all that is left to add.
		return ("+" if signed and rounded > 0.0 else "") + str(roundi(rounded))
	var v := absf(rounded)
	var decade := floori(log(v) / log(10.0))
	var mant := v / pow(10.0, decade)
	# 9.999 is printed by "%.2f" as "10.00", which is a mantissa with two digits in it: carry it.
	if mant >= 9.995:
		mant /= 10.0
		decade += 1
	if mant < 1.0:
		mant *= 10.0
		decade -= 1
		# And the carry can be owed again: 0.9999 becomes 9.999, which is "10.00" once more.
		if mant >= 9.995:
			mant /= 10.0
			decade += 1
	return sign_text + "%.2fe%d" % [mant, decade]
