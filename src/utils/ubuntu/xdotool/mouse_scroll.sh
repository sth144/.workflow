#!/bin/bash

up() {
  xdotool click 4
}

up_fast() {
  for i in {1..6}; do up; done
}

down() {
  xdotool click 5
}

down_fast() {
  for i in {1..6}; do down; done
}

$1 "${@:2}"
