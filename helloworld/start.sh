#!/bin/bash

gcc -static hello.c -o hello
why
docker build -t hello-lark:1.0 .
echo "execute end" 
