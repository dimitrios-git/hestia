package main

import "fmt"

const Max = 10

type User struct {
	ID   int
	Name string
}

func (u *User) Greet(times int) string {
	// TODO: builtins, operators
	out := ""
	for i := 0; i < times && i < Max; i++ {
		out += fmt.Sprintf("hi %s\n", u.Name)
	}
	return out
}
