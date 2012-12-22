package bonsai

import "fmt"

type Value interface {
	Type() string
	ToString() string
}

type IntegerValue int64
func (IntegerValue) Type() string { return "integer" }
func (i IntegerValue) ToString() string { return fmt.Sprintf("%d", i) }

type DecimalValue float64
func (DecimalValue) Type() string { return "decimal" }
func (d DecimalValue) ToString() string { return fmt.Sprintf("%g", d) }

type StringValue string
func (StringValue) Type() string { return "string" }
func (s StringValue) ToString() string { return fmt.Sprintf("%q", s) }
