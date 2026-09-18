// Package clock provides time sources. Domain code never reads the clock:
// use cases take the current time from one of these and pass it down as `now`.
package clock

import "time"

// System reads the wall clock. Values are UTC and truncated to microseconds,
// the precision Postgres keeps, so a time survives a database round trip unchanged.
type System struct{}

func (System) Now() time.Time { return time.Now().UTC().Truncate(time.Microsecond) }

// Fixed always returns the same instant. For tests.
type Fixed time.Time

func (f Fixed) Now() time.Time { return time.Time(f) }
