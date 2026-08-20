#!/bin/bash

function greet(){
	echo "Hello, From Greet."
}

welcome(){
	echo "Hello, From Welcome"
}

fun_single_arg(){
	echo "Hello, $1 . This is single Argument"
}

fun_multi_arg(){
	echo "Hello $1 and $2 . We welcome both of you to Multiple Argument Passing"
}

greet
welcome
fun_single_arg "Francis"
fun_multi_arg "Odin" "Hades"
