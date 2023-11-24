fswatch -or src test | xargs -n1 -I{} forge test -vv --mp $1

