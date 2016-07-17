#!/bin/bash
gcc -static hello.c -o hello
docker build -t hello-lark:1.0 .
echo "execute end" 
