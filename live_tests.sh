fswatch -or src test | xargs -n1 -I{} sh -c "./build_bytecode.sh && forge test -vv --mp $1"

