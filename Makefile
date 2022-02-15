.PHONY: test

all: snark-jwt-verify node_modules

test: snark-jwt-verify node_modules
	yarn exec mocha

snark-jwt-verify/: 
	git clone --recurse-submodules https://github.com/TheFrozenFire/snark-jwt-verify

node_modules/:
	yarn

clean:
	rm -rf snark-jwt-verify
	rm -rf node_modules